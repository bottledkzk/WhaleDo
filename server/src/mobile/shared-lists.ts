import { randomBytes, randomUUID } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { digest, MobileError } from './snapshot.ts';

type ListRow = { id: string; ownerId: string; title: string; revision: number };
type InviteRow = { listId: string; expires: number; usedBy: string | null };
const LIMIT_LISTS = 10;
const LIMIT_MEMBERS = 10;
const LIMIT_ITEMS = 100;

function title(value: unknown): string {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 120) {
    throw new MobileError(400, 'INVALID_SHARED_TITLE', '请输入 1 至 120 字的名称');
  }
  return value.trim();
}

export class MobileSharedLists {
  private readonly db: DatabaseSync;
  private readonly now: () => number;

  constructor(file: string, now: () => number = Date.now) {
    this.now = now;
    this.db = new DatabaseSync(file);
    this.db.exec(`
      PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS mobile_shared_lists(
        id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES mobile_users(id) ON DELETE CASCADE,
        title TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 0, creation_key TEXT NOT NULL,
        UNIQUE(owner_id,creation_key)
      );
      CREATE TABLE IF NOT EXISTS mobile_shared_members(
        list_id TEXT NOT NULL REFERENCES mobile_shared_lists(id) ON DELETE CASCADE,
        user_id TEXT NOT NULL REFERENCES mobile_users(id) ON DELETE CASCADE,
        PRIMARY KEY(list_id,user_id)
      );
      CREATE INDEX IF NOT EXISTS mobile_shared_members_by_user ON mobile_shared_members(user_id,list_id);
      CREATE TABLE IF NOT EXISTS mobile_shared_invites(
        list_id TEXT PRIMARY KEY REFERENCES mobile_shared_lists(id) ON DELETE CASCADE,
        hash TEXT NOT NULL UNIQUE, expires INTEGER NOT NULL,
        used_by TEXT REFERENCES mobile_users(id) ON DELETE CASCADE
      );
      CREATE TABLE IF NOT EXISTS mobile_shared_items(
        list_id TEXT NOT NULL REFERENCES mobile_shared_lists(id) ON DELETE CASCADE,
        id TEXT NOT NULL, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL, PRIMARY KEY(list_id,id)
      );
    `);
  }

  close(): void {
    this.db.close();
  }

  private transaction<T>(work: () => T): T {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const result = work();
      this.db.exec('COMMIT');
      return result;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  private member(listId: string, userId: string): ListRow {
    const list = this.db.prepare(`
      SELECT l.id, l.owner_id AS ownerId, l.title, l.revision
      FROM mobile_shared_lists l JOIN mobile_shared_members m ON l.id=m.list_id
      WHERE l.id=? AND m.user_id=?
    `).get(listId, userId) as ListRow | undefined;
    if (!list) {
      throw new MobileError(404, 'SHARED_LIST_NOT_FOUND', '清单不存在或您没有访问权限');
    }
    return list;
  }

  private owner(listId: string, userId: string): void {
    if (this.member(listId, userId).ownerId !== userId) {
      throw new MobileError(403, 'SHARED_OWNER_REQUIRED', '只有清单创建者可以管理成员');
    }
  }

  list(userId: string) {
    return this.db.prepare(`
      SELECT l.id, l.title, l.revision, l.owner_id AS ownerId
      FROM mobile_shared_lists l JOIN mobile_shared_members m ON l.id=m.list_id
      WHERE m.user_id=? ORDER BY l.title,l.id
    `).all(userId);
  }

  create(userId: string, name: unknown, requestId: unknown) {
    const label = title(name);
    if (typeof requestId !== 'string' || !/^[A-Za-z0-9_-]{8,100}$/.test(requestId)) {
      throw new MobileError(400, 'INVALID_SHARED_REQUEST', '创建请求格式无效');
    }
    return this.transaction(() => {
      const prior = this.db.prepare('SELECT id,title FROM mobile_shared_lists WHERE owner_id=? AND creation_key=?')
        .get(userId, requestId) as { id: string; title: string } | undefined;
      if (prior) {
        if (prior.title !== label) {
          throw new MobileError(409, 'SHARED_REQUEST_CONFLICT', '该请求已用于创建其他清单');
        }
        return this.member(prior.id, userId);
      }
      const count = this.db.prepare('SELECT count(*) AS n FROM mobile_shared_members WHERE user_id=?')
        .get(userId) as { n: number };
      if (count.n >= LIMIT_LISTS) {
        throw new MobileError(409, 'SHARED_LIST_LIMIT', '已达到参与清单的上限');
      }
      const id = randomUUID();
      this.db.prepare('INSERT INTO mobile_shared_lists(id,owner_id,title,creation_key) VALUES(?,?,?,?)')
        .run(id, userId, label, requestId);
      this.db.prepare('INSERT INTO mobile_shared_members VALUES(?,?)').run(id, userId);
      return this.member(id, userId);
    });
  }

  get(userId: string, listId: string) {
    const list = this.member(listId, userId);
    const members = this.db.prepare(`
      SELECT u.id,u.username FROM mobile_users u JOIN mobile_shared_members m ON u.id=m.user_id
      WHERE m.list_id=? ORDER BY u.username
    `).all(listId);
    const rows = this.db.prepare('SELECT id,title,done FROM mobile_shared_items WHERE list_id=? ORDER BY created_at,id')
      .all(listId) as { id: string; title: string; done: number }[];
    return { ...list, members, items: rows.map(row => ({ ...row, done: row.done === 1 })) };
  }

  invite(userId: string, listId: string) {
    return this.transaction(() => {
      this.owner(listId, userId);
      const code = randomBytes(18).toString('base64url');
      const expires = this.now() + 24 * 60 * 60 * 1000;
      this.db.prepare(`
        INSERT INTO mobile_shared_invites(list_id,hash,expires,used_by) VALUES(?,?,?,NULL)
        ON CONFLICT(list_id) DO UPDATE SET hash=excluded.hash,expires=excluded.expires,used_by=NULL
      `).run(listId, digest(code), expires);
      return { code, expires };
    });
  }

  join(userId: string, raw: unknown) {
    if (typeof raw !== 'string' || !/^[A-Za-z0-9_-]{24}$/.test(raw)) {
      throw new MobileError(400, 'INVALID_SHARED_INVITE', '邀请码格式无效');
    }
    return this.transaction(() => {
      const invite = this.db.prepare(`
        SELECT list_id AS listId,expires,used_by AS usedBy FROM mobile_shared_invites WHERE hash=?
      `).get(digest(raw)) as InviteRow | undefined;
      if (!invite || invite.expires <= this.now() || (invite.usedBy && invite.usedBy !== userId)) {
        throw new MobileError(404, 'SHARED_INVITE_EXPIRED', '邀请码已使用或失效');
      }
      const existing = this.db.prepare('SELECT 1 FROM mobile_shared_members WHERE list_id=? AND user_id=?')
        .get(invite.listId, userId);
      if (existing) {
        return this.member(invite.listId, userId);
      }
      const listCount = this.db.prepare('SELECT count(*) AS n FROM mobile_shared_members WHERE user_id=?')
        .get(userId) as { n: number };
      const memberCount = this.db.prepare('SELECT count(*) AS n FROM mobile_shared_members WHERE list_id=?')
        .get(invite.listId) as { n: number };
      if (listCount.n >= LIMIT_LISTS || memberCount.n >= LIMIT_MEMBERS) {
        throw new MobileError(409, 'SHARED_MEMBER_LIMIT', '已达到清单或成员数量上限');
      }
      this.db.prepare('INSERT INTO mobile_shared_members VALUES(?,?)').run(invite.listId, userId);
      this.db.prepare('UPDATE mobile_shared_invites SET used_by=? WHERE list_id=?').run(userId, invite.listId);
      return this.member(invite.listId, userId);
    });
  }

  remove(userId: string, listId: string, memberId: string) {
    return this.transaction(() => {
      this.owner(listId, userId);
      if (memberId === userId) {
        throw new MobileError(400, 'SHARED_OWNER_CANNOT_REMOVE', '不能从清单中移除创建者');
      }
      this.db.prepare('DELETE FROM mobile_shared_invites WHERE list_id=? AND used_by=?').run(listId, memberId);
      this.db.prepare('DELETE FROM mobile_shared_members WHERE list_id=? AND user_id=?').run(listId, memberId);
      return { ok: true };
    });
  }

  write(userId: string, listId: string, itemId: string, revision: unknown, name: unknown, done: unknown) {
    if (!/^[A-Za-z0-9_-]{8,100}$/.test(itemId) || typeof revision !== 'number' ||
      !Number.isSafeInteger(revision) || revision < 0 || typeof done !== 'boolean') {
      throw new MobileError(400, 'INVALID_SHARED_ITEM', '事项内容或版本无效');
    }
    const label = title(name);
    return this.transaction(() => {
      const list = this.member(listId, userId);
      const current = this.db.prepare('SELECT title,done FROM mobile_shared_items WHERE list_id=? AND id=?')
        .get(listId, itemId) as { title: string; done: number } | undefined;
      if (current && current.title === label && current.done === Number(done)) {
        return list;
      }
      if (list.revision !== revision) {
        throw new MobileError(409, 'SHARED_LIST_CONFLICT', '清单已有更新，请刷新后重试');
      }
      if (!current) {
        const count = this.db.prepare('SELECT count(*) AS n FROM mobile_shared_items WHERE list_id=?')
          .get(listId) as { n: number };
        if (count.n >= LIMIT_ITEMS) {
          throw new MobileError(409, 'SHARED_ITEM_LIMIT', '该清单已达到事项上限');
        }
      }
      this.db.prepare(`
        INSERT INTO mobile_shared_items(list_id,id,title,done,created_at) VALUES(?,?,?,?,?)
        ON CONFLICT(list_id,id) DO UPDATE SET title=excluded.title,done=excluded.done
      `).run(listId, itemId, label, Number(done), this.now());
      this.db.prepare('UPDATE mobile_shared_lists SET revision=revision+1 WHERE id=?').run(listId);
      return this.member(listId, userId);
    });
  }
}
