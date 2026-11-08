import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { buildMobileApp } from '../src/mobile/app.ts';
import { MobileSharedLists } from '../src/mobile/shared-lists.ts';
import { MobileStore } from '../src/mobile/store.ts';

test('shared lists isolate accounts, allow one-use invitations and reject overwriting a newer revision', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'whale-shared-'));
  const file = join(directory, 'course.sqlite');
  const store = new MobileStore(file);
  let now = Date.now();
  const shared = new MobileSharedLists(file, () => now);
  const app = buildMobileApp(store, undefined, undefined, shared);
  const creator = store.createSession(store.createUser('shared_creator', 'unused'));
  const member = store.createSession(store.createUser('shared_member', 'unused'));
  const other = store.createSession(store.createUser('shared_other', 'unused'));
  const headers = (access: string) => ({ authorization: 'Bearer ' + access });
  const create = { title: 'Course checklist', requestId: 'create-checklist-01' };
  const root = '/api/v1/shared';

  try {
    assert.equal((await app.inject(root + '/lists')).statusCode, 401);
    const made = await app.inject({ method: 'POST', url: root + '/lists', headers: headers(creator.accessToken), payload: create });
    assert.equal(made.statusCode, 200);
    const listId = made.json().data.id as string;
    const route = root + '/lists/' + listId;
    const repeat = await app.inject({ method: 'POST', url: root + '/lists', headers: headers(creator.accessToken), payload: create });
    assert.equal(repeat.json().data.id, listId);
    assert.equal((await app.inject({ url: route, headers: headers(member.accessToken) })).statusCode, 404);

    const invite = async () => (await app.inject({
      method: 'POST', url: route + '/invite', headers: headers(creator.accessToken)
    })).json().data.code as string;
    const accept = (access: string, code: string) => app.inject({
      method: 'POST', url: root + '/join', headers: headers(access), payload: { code }
    });
    const expired = await invite();
    now += 24 * 60 * 60 * 1000 + 1;
    assert.equal((await accept(member.accessToken, expired)).statusCode, 404);
    const code = await invite();
    assert.equal((await accept(member.accessToken, code)).statusCode, 200);
    assert.equal((await accept(member.accessToken, code)).statusCode, 200);
    assert.equal((await accept(other.accessToken, code)).statusCode, 404);
    assert.equal((await app.inject({ method: 'POST', url: route + '/invite', headers: headers(member.accessToken) })).statusCode, 403);

    const task = (access: string, expectedRevision: number, done: boolean) => app.inject({
      method: 'PUT', url: route + '/items/course-task-01', headers: headers(access),
      payload: { expectedRevision, title: 'Check project handoff', done }
    });
    assert.equal((await task(creator.accessToken, 0, false)).json().data.revision, 1);
    assert.equal((await task(member.accessToken, 0, true)).statusCode, 409);
    assert.equal((await task(member.accessToken, 1, true)).json().data.revision, 2);
    assert.equal((await task(member.accessToken, 1, true)).json().data.revision, 2);
    const list = await app.inject({ url: route, headers: headers(creator.accessToken) });
    assert.deepEqual(list.json().data.items, [{ id: 'course-task-01', title: 'Check project handoff', done: true }]);
    assert.equal(store.head(creator.user.id).revision, 0);
    assert.equal(store.head(member.user.id).revision, 0);

    const removed = await app.inject({
      method: 'DELETE', url: route + '/members/' + member.user.id, headers: headers(creator.accessToken)
    });
    assert.equal(removed.statusCode, 200);
    assert.equal((await task(member.accessToken, 2, false)).statusCode, 404);
    assert.equal((await accept(member.accessToken, code)).statusCode, 404);
  } finally {
    await app.close();
    store.close();
    rmSync(directory, { recursive: true, force: true });
  }
});
