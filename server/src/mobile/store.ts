import { DatabaseSync } from 'node:sqlite';
import { randomBytes, randomUUID } from 'node:crypto';
import { MobileError, digest, validateSnapshot } from './snapshot.ts';

export interface User { id: string; username: string; }
export interface Session { user: User; accessToken: string; refreshToken: string; accessExpiresAt: number; }
type UserRow = User & { password_hash: string };
type SessionRow = { id: string; user_id: string; refresh_hash: string; refresh_expires: number; revoked: number };
type Head = { revision: number; updatedAt: number; hash: string };
type SnapshotRow = { revision: number; updated_at: number; payload: string; hash: string };
export class MobileStore {
  private db: DatabaseSync;
  private now:()=>number;
  maxAccounts:number;
  constructor(file: string, now: () => number = Date.now, maxAccounts: number = 50) {
    this.now=now;this.maxAccounts=maxAccounts;
    if(!Number.isSafeInteger(maxAccounts)||maxAccounts<1)throw new Error('Invalid configured account capacity');
    this.db = new DatabaseSync(file);
    this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS mobile_users(id TEXT PRIMARY KEY,username TEXT NOT NULL COLLATE NOCASE UNIQUE,password_hash TEXT NOT NULL,created_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS mobile_sessions(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES mobile_users(id),access_hash TEXT NOT NULL UNIQUE,refresh_hash TEXT NOT NULL UNIQUE,access_expires INTEGER NOT NULL,refresh_expires INTEGER NOT NULL,revoked INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS mobile_consumed_refresh(hash TEXT PRIMARY KEY,session_id TEXT NOT NULL REFERENCES mobile_sessions(id));
      CREATE TABLE IF NOT EXISTS mobile_snapshots(user_id TEXT NOT NULL REFERENCES mobile_users(id),revision INTEGER NOT NULL,payload TEXT NOT NULL,hash TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(user_id,revision));
      CREATE TABLE IF NOT EXISTS mobile_snapshot_requests(user_id TEXT NOT NULL REFERENCES mobile_users(id),request_id TEXT NOT NULL,fingerprint TEXT NOT NULL,revision INTEGER NOT NULL,PRIMARY KEY(user_id,request_id));`);
  }
  close() { this.db.close(); }
  private tx<T>(fn: () => T): T {
    this.db.exec('BEGIN IMMEDIATE');
    try { const result=fn();this.db.exec('COMMIT');return result; }
    catch(error) {this.db.exec('ROLLBACK');throw error;}
  }
  userByName(username: string) { return this.db.prepare('SELECT id,username,password_hash FROM mobile_users WHERE username=? COLLATE NOCASE').get(username) as UserRow|undefined; }
  assertRegistrationAvailable(username:string) {
    if(this.userByName(username))throw new MobileError(409,'USERNAME_TAKEN','用户名已被使用');
    const count=this.db.prepare('SELECT COUNT(*) AS count FROM mobile_users').get() as {count:number};
    if(count.count>=this.maxAccounts)throw new MobileError(409,'ACCOUNT_LIMIT','当前账户容量已满，请联系管理员调整容量');
  }
  createUser(username: string, passwordHash: string): User {
    return this.tx(()=>{
      this.assertRegistrationAvailable(username);
      const user={id:randomUUID(),username};
      this.db.prepare('INSERT INTO mobile_users VALUES(?,?,?,?)').run(user.id,username,passwordHash,this.now());return user;
    });
  }
  private sessionValues() {return {access:randomBytes(32).toString('base64url'),refresh:randomBytes(32).toString('base64url'),expires:this.now()+15*60*1000,refreshExpires:this.now()+30*86400000};}
  createSession(user: User): Session {
    const s=this.sessionValues();
    this.db.prepare('INSERT INTO mobile_sessions VALUES(?,?,?,?,?,?,0)').run(randomUUID(),user.id,digest(s.access),digest(s.refresh),s.expires,s.refreshExpires);
    return {user,accessToken:s.access,refreshToken:s.refresh,accessExpiresAt:s.expires};
  }
  authenticate(access: string): User {
    const user=this.db.prepare('SELECT u.id,u.username FROM mobile_sessions s JOIN mobile_users u ON u.id=s.user_id WHERE s.access_hash=? AND s.revoked=0 AND s.access_expires>?').get(digest(access),this.now()) as User|undefined;
    if(!user)throw new MobileError(401,'UNAUTHENTICATED','登录已失效，请重新登录');return user;
  }
  refresh(raw: string): Session {
    // Replayed refresh credentials revoke their family in a committed write.
    const consumed=this.db.prepare('SELECT session_id FROM mobile_consumed_refresh WHERE hash=?').get(digest(raw)) as {session_id:string}|undefined;
    if(consumed){this.db.prepare('UPDATE mobile_sessions SET revoked=1 WHERE id=?').run(consumed.session_id);throw new MobileError(401,'REFRESH_REPLAY','登录已失效，请重新登录');}
    return this.tx(()=>{
      const row=this.db.prepare('SELECT id,user_id,refresh_hash,refresh_expires,revoked FROM mobile_sessions WHERE refresh_hash=?').get(digest(raw)) as SessionRow|undefined;
      if(!row||row.revoked||row.refresh_expires<=this.now())throw new MobileError(401,'UNAUTHENTICATED','登录已失效，请重新登录');
      const user=this.db.prepare('SELECT id,username FROM mobile_users WHERE id=?').get(row.user_id) as unknown as User;
      const s=this.sessionValues();this.db.prepare('INSERT INTO mobile_consumed_refresh VALUES(?,?)').run(row.refresh_hash,row.id);
      this.db.prepare('UPDATE mobile_sessions SET access_hash=?,refresh_hash=?,access_expires=?,refresh_expires=? WHERE id=? AND revoked=0').run(digest(s.access),digest(s.refresh),s.expires,s.refreshExpires,row.id);
      return {user,accessToken:s.access,refreshToken:s.refresh,accessExpiresAt:s.expires};
    });
  }
  logout(access: string) {this.db.prepare('UPDATE mobile_sessions SET revoked=1 WHERE access_hash=?').run(digest(access));}
  head(user: string): Head {
    const row=this.db.prepare('SELECT revision,updated_at,hash FROM mobile_snapshots WHERE user_id=? ORDER BY revision DESC LIMIT 1').get(user) as {revision:number;updated_at:number;hash:string}|undefined;
    return row?{revision:row.revision,updatedAt:row.updated_at,hash:row.hash}:{revision:0,updatedAt:0,hash:''};
  }
  put(user: string, expected: number, requestId: string, input: unknown): Head {
    if(!Number.isSafeInteger(expected)||expected<0||typeof requestId!=='string'||!/^[A-Za-z0-9_-]{8,120}$/.test(requestId))throw new MobileError(400,'VALIDATION_ERROR','备份请求格式无效');
    const payload=validateSnapshot(input),hash=digest(payload),fingerprint=digest(expected+'\n'+payload);
    return this.tx(()=>{
      const receipt=this.db.prepare('SELECT fingerprint,revision FROM mobile_snapshot_requests WHERE user_id=? AND request_id=?').get(user,requestId) as {fingerprint:string;revision:number}|undefined;
      if(receipt){if(receipt.fingerprint!==fingerprint)throw new MobileError(409,'IDEMPOTENCY_CONFLICT','请刷新云端状态后重试');const row=this.snapshot(user,receipt.revision);return {revision:row.revision,updatedAt:row.updatedAt,hash:row.hash};}
      const head=this.head(user);
      if(head.revision!==expected)throw new MobileError(409,'CLOUD_CONFLICT','云端已被其它设备更新，请先刷新并选择保留版本');
      const revision=head.revision+1,updatedAt=this.now();
      this.db.prepare('INSERT INTO mobile_snapshots VALUES(?,?,?,?,?)').run(user,revision,payload,hash,updatedAt);
      this.db.prepare('INSERT INTO mobile_snapshot_requests VALUES(?,?,?,?)').run(user,requestId,fingerprint,revision);
      return {revision,updatedAt,hash};
    });
  }
  snapshot(user: string, revision?: number) {
    const row=(revision===undefined?this.db.prepare('SELECT * FROM mobile_snapshots WHERE user_id=? ORDER BY revision DESC LIMIT 1').get(user):this.db.prepare('SELECT * FROM mobile_snapshots WHERE user_id=? AND revision=?').get(user,revision)) as SnapshotRow|undefined;
    if(!row)throw new MobileError(404,'NO_BACKUP','还没有可恢复的云端备份');
    return {revision:row.revision,updatedAt:row.updated_at,hash:row.hash,snapshot:JSON.parse(row.payload) as unknown};
  }
  history(user: string,before:number=Number.MAX_SAFE_INTEGER) {return this.db.prepare('SELECT revision,updated_at AS updatedAt,hash FROM mobile_snapshots WHERE user_id=? AND revision<? ORDER BY revision DESC LIMIT 20').all(user,before);}
}
