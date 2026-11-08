const fs = require('node:fs');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const ts = require('./toolchain.cjs');
require.extensions['.ets'] = (module, file) => module._compile(ts.transpileModule(fs.readFileSync(file, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  fileName: file.replace(/\.ets$/, '.ts')
}).outputText, file);
const M = require('../entry/src/main/ets/model/MobileModel.ets');
const C = require('../entry/src/main/ets/model/CalendarImport.ets');
const S = require('../entry/src/main/ets/model/SharingModel.ets');
const now = Date.UTC(2026, 9, 30, 0);

function imported(start, end, allDay = true, id = 203) {
  const data = new M.MobileData();
  const record = C.calendarRecord(id, '全天鲸🐋;假期', start, end, allDay, 'Room, A');
  return C.calendarImport(data, [record], JSON.stringify(data), now);
}
function exported(data) {
  return { ics: S.tasksIcs(data, '', now), text: S.taskText(data) };
}
function worker(timezone, input) {
  return JSON.parse(execFileSync(process.execPath, [__filename, 'worker'], {
    env: { ...process.env, TZ: timezone }, input: JSON.stringify(input), encoding: 'utf8'
  }));
}
function assertDateEvent(ics, start, exclusiveEnd) {
  assert.match(ics, /BEGIN:VEVENT\r\n/);
  assert(ics.includes(`DTSTART;VALUE=DATE:${start}\r\n`));
  assert(ics.includes(`DTEND;VALUE=DATE:${exclusiveEnd}\r\n`));
  assert(!ics.includes('DTSTART:'));
  assert(!ics.includes('DTEND:'));
  assert(!ics.includes('TZID='));
  assert.equal((ics.match(/BEGIN:VEVENT/g) || []).length, 1);
  for (const line of ics.split('\r\n')) assert(Buffer.byteLength(line) <= 75);
}

if (process.argv[2] === 'worker') {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const output = input.mode === 'import' ? [
    imported(Date.UTC(2026, 10, 7), Date.UTC(2026, 10, 8)),
    imported(Date.UTC(2026, 10, 1), Date.UTC(2026, 10, 4), true, 204)
  ] : input.data.map(exported);
  process.stdout.write(JSON.stringify(output));
} else {
  const test = require('node:test');
  test('imported single-day and DST-spanning all-day events retain dates across all import/export timezone pairs', () => {
    const zones = ['UTC', 'Asia/Shanghai', 'America/Los_Angeles'];
    const snapshots = zones.map(zone => worker(zone, { mode: 'import' }));
    // A timezone switch genuinely changes how these stored instants are displayed.
    assert.notEqual(snapshots[1][0].blocks[0].start, snapshots[2][0].blocks[0].start);
    assert.equal(snapshots[2][1].blocks[0].end - snapshots[2][1].blocks[0].start, 73 * 3600000);
    for (const data of snapshots) for (const zone of zones) {
      const output = worker(zone, { mode: 'export', data });
      assertDateEvent(output[0].ics, '20261107', '20261108');
      assertDateEvent(output[1].ics, '20261101', '20261104');
      assert(output[0].text.includes('全天日程：2026-11-07'));
      assert(output[1].text.includes('全天日程：2026-11-01 — 2026-11-03'));
      for (const result of output) {
        assert(!result.text.includes('截止'));
        assert(!result.text.includes('预计'));
      }
    }
  });
  test('exclusive end advances by calendar date across leap day and year boundary', () => {
    for (const [start, end, firstDate, lastDate] of [
      [Date.UTC(2028, 1, 29), Date.UTC(2028, 2, 1), '20280229', '20280301'],
      [Date.UTC(2026, 11, 31), Date.UTC(2027, 0, 1), '20261231', '20270101']
    ]) assertDateEvent(S.tasksIcs(imported(start, end), '', now), firstDate, lastDate);
  });
  test('ordinary timed and midnight-to-midnight events keep exact UTC instants', () => {
    for (const offset of [0, 9 * 3600000]) {
      const start = Date.UTC(2026, 10, 7) + offset, end = start + 86400000;
      const ics = S.tasksIcs(imported(start, end, false), '', now);
      assert(!ics.includes(';VALUE=DATE:'));
      assert(ics.includes('DTSTART:' + new Date(start).toISOString().replace(/[-:]/g, '').replace('.000Z', 'Z')));
      assert(ics.includes('DTEND:' + new Date(end).toISOString().replace(/[-:]/g, '').replace('.000Z', 'Z')));
    }
  });
  test('malformed or unrelated notes do not silently turn a timed reservation into an all-day event', () => {
    const source = imported(Date.UTC(2026, 10, 7), Date.UTC(2026, 10, 8));
    for (const note of ['全天日程：2026-02-30', '全天日程：2026-11-08 — 2026-11-07', '全天日程：2026-11-07junk']) {
      const data = M.clone(source); data.tasks[0].note = note;
      assert(!S.tasksIcs(data, '', now).includes(';VALUE=DATE:'));
    }
    const manual = M.clone(source); manual.blocks[0].id = 'manual-replacement';
    assert(!S.tasksIcs(manual, '', now).includes(';VALUE=DATE:'));
    assert(S.taskText(manual).includes('截止'));
    const unrelated = M.clone(source); unrelated.tasks[0].category = '生活';
    assert(!S.tasksIcs(unrelated, '', now).includes(';VALUE=DATE:'));
  });
  test('completed and restored all-day tasks without reservations retain date-only due semantics', () => {
    const source = imported(Date.UTC(2026, 10, 1), Date.UTC(2026, 10, 4));
    const completed = M.finishTask(source, source.tasks[0].id, 4, now);
    const restored = M.restoreTask(M.deleteTask(source, source.tasks[0].id, now), source.tasks[0].id);
    for (const data of [completed, restored]) {
      const ics = S.tasksIcs(data, '', now);
      assert(ics.includes('BEGIN:VTODO'));
      assert(ics.includes('DUE;VALUE=DATE:20261103\r\n'));
      assert(!ics.includes('DUE:'));
      assert(!ics.includes('BEGIN:VEVENT'));
    }
    assert(S.tasksIcs(completed, '', now).includes('STATUS:COMPLETED'));
  });
  test('all-day export preserves stable identity, escaped content and the input snapshot', () => {
    const data = imported(Date.UTC(2026, 10, 7), Date.UTC(2026, 10, 8));
    const before = JSON.stringify(data), first = S.tasksIcs(data, '', now);
    const second = S.tasksIcs(data, data.tasks[0].id, now + 60000);
    const uid = first.match(/UID:([^\r\n]+)/)[1];
    assert(second.includes(`UID:${uid}\r\n`));
    assert(first.includes('SUMMARY:全天鲸🐋\\;假期'));
    assert(first.replace(/\r\n /g, '').includes('地点：Room\\, A'));
    assert.equal(JSON.stringify(data), before);
  });
}
