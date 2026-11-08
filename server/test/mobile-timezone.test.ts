import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MobileStore } from '../src/mobile/store.ts';
import { validateSnapshot } from '../src/mobile/snapshot.ts';

test('timezone metadata survives SQLite snapshot backup and old snapshots remain accepted',()=>{
  const store=new MobileStore(':memory:'),user=store.createUser('zonefixture','synthetic-hash');
  const task={id:'task',title:'课程验证',note:'',category:'学习',minutes:30,deadline:1800000000000,priority:3,done:false,createdAt:1700000000000,completedAt:0,rating:0,timeZone:'Asia/Shanghai'};
  const block={id:'slot',taskId:'task',start:1799996400000,end:1799998200000,locked:true,done:false,completedAt:0,rating:0,reflection:'',timeZone:'Asia/Shanghai'};
  const snapshot={version:1,revision:0,tasks:[task],blocks:[block],diaries:[{day:'2026-11-08',text:'课程日记',timeZone:'Asia/Shanghai'}],workStart:540,workEnd:1320,theme:'light',timeZone:'America/Los_Angeles'};
  try{
    store.put(user.id,0,'zone_request_0001',snapshot);
    assert.deepEqual(store.snapshot(user.id).snapshot,snapshot);
    const old=structuredClone(snapshot) as Record<string,unknown>;delete old.timeZone;
    for(const list of [old.tasks,old.blocks,old.diaries] as Array<Array<Record<string,unknown>>>)for(const row of list)delete row.timeZone;
    assert.doesNotThrow(()=>validateSnapshot(old));
    assert.throws(()=>validateSnapshot({...snapshot,timeZone:'not/a/real/zone'}));
  }finally{store.close();}
});
