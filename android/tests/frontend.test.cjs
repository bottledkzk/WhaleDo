const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const {JSDOM}=require('jsdom');const base=path.resolve(__dirname,'../app/src/main/assets');
const USER='11111111-1111-4111-8111-111111111111';
const copy=value=>value===undefined?undefined:JSON.parse(JSON.stringify(value));
async function until(fn){for(let i=0;i<200;i++){if(fn())return;await new Promise(r=>setTimeout(r,5));}throw Error('Test state did not settle');}
async function environment(auth=true){
 const dom=new JSDOM('<main id="app"></main><div id="modal"></div><div id="toast"></div>',{url:'https://appassets.androidplatform.net/assets/index.html',runScripts:'outside-only',pretendToBeVisual:true});
 const window=dom.window,context=dom.getInternalVMContext(),records=new Map(),calls=[];let apiHandler=()=>({}),readHandler=null,writeHandler=null;
 window.ResizeObserver=class{observe(){}disconnect(){}};window.matchMedia=()=>({matches:false});
 const owner=auth?USER:'guest';
 window.WhaleNative={postMessage(raw){const request=JSON.parse(raw);calls.push(copy(request));Promise.resolve().then(async()=>{
  const p=request.params;
  if(request.command==='bootstrap')return {owner,user:{id:auth?USER:'',username:auth?'course_test':''},systemZone:'UTC',systemDark:false};
  if(request.command==='read'){if(readHandler){const value=await readHandler(p);if(value!==undefined)return value;}return copy(records.get(p.owner+':'+p.name)||null);}
  if(request.command==='write'){if(writeHandler)await writeHandler(p);records.set(p.owner+':'+p.name,copy(p.value));return true;}
  if(request.command==='api')return apiHandler(p);
  return true;
 }).then(data=>window.WhaleNative.onmessage({data:JSON.stringify({id:request.id,ok:true,data})}),error=>window.WhaleNative.onmessage({data:JSON.stringify({id:request.id,ok:false,error:error.message,status:error.status||0})}));}};
 for(const name of ['core','app','screens','assistant','sharing','cloud'])vm.runInContext(fs.readFileSync(path.join(base,name+'.js'),'utf8'),context,{filename:name+'.js'});
 const run=code=>vm.runInContext(code,context);await until(()=>run('S.ready'));
 return {dom,window,calls,records,run,setApi:handler=>apiHandler=handler,setRead:handler=>readHandler=handler,setWrite:handler=>writeHandler=handler,close:()=>dom.window.close(),owner};
}
test('packaged scheduling, sync, zone and consent rules match canonical course source',()=>{
 const manifest=JSON.parse(fs.readFileSync(path.join(base,'core-sources.json'),'utf8'));const canonical=path.resolve(__dirname,'../../harmony/entry/src/main/ets');
 for(const [name,expected] of Object.entries(manifest)){const bytes=fs.readFileSync(path.join(canonical,name+'.ets'));assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),expected,name);}
 assert.equal(Object.keys(manifest).length,14);
});
test('editing local data never starts cloud sync',async t=>{
 const e=await environment();t.after(e.close);await e.run('save({...M.clone(S.data),nickname:"Course"},"")');assert.equal(e.calls.filter(c=>c.command==='api').length,0);assert.equal(e.records.get(USER+':data').nickname,'Course');
});
test('empty assistant shows four composer actions without null text or a second image entry',async t=>{
 const e=await environment();t.after(e.close);e.run('S.tab=3;render(true)');const doc=e.window.document;
 assert(!doc.getElementById('assistant-thread').textContent.includes('null'));
 assert.deepEqual(Array.from(doc.querySelectorAll('#assistant-tools>button')).map(n=>n.textContent),['添加图片','语音输入','音频转写','发送']);
 assert.equal(doc.getElementById('capture-ocr'),null);
 const input=doc.getElementById('assistant-input');e.run('conversation().messages.push({role:"assistant",content:"A longer answer"});refreshAssistant()');assert.equal(doc.getElementById('assistant-input'),input);
});
test('late native replies are rejected after account generation changes',async t=>{
 const e=await environment();t.after(e.close);let release;e.setRead(p=>p.name==='data'?new Promise(resolve=>release=resolve):undefined);
 const result=e.run('native("read",{name:"data"}).then(()=>"accepted",error=>error.message)');await until(()=>release);e.run('S.epoch++');release({version:1});assert.match(await result,/账户已切换/);
});
test('AI request is stored before network, and unknown acceptance retries exact payload',async t=>{
 const e=await environment();t.after(e.close);let submissions=0;
 e.setApi(p=>{if(p.path==='/ai/status')return {enabled:true};if(p.path==='/ai/jobs'){
  const record=e.records.get(USER+':library');assert(record.items.find(c=>c.id===record.current).pending.body.requestId);submissions++;
  if(submissions===1)throw Error('Connection result unknown');
  return {id:'job_one',status:'completed',result:{text:'已收到',tasks:[],warnings:[]}};
 }return {};});
 e.run('S.tab=3;render(true);conversation().draft="Plan my day"');await e.run('sendAi()');assert(e.run('!!conversation().pending'));
 e.run('conversation().draft="Changed text after unknown result"');await e.run('sendAi()');
 const sent=e.calls.filter(c=>c.command==='api'&&c.params.path==='/ai/jobs');assert.equal(sent.length,2);assert.deepEqual(sent[0].params.body,sent[1].params.body);assert.equal(e.run('conversation().messages.length'),2);assert.equal(e.run('conversation().pending'),null);
});
test('model edits require consent, and stale proposals cannot change local data',async t=>{
 const e=await environment();t.after(e.close);e.run('var task=new M.MobileTask();task.id="existing";task.title="Original";task.createdAt=Date.now();S.data=M.upsertTask(S.data,task);S.tab=3;render(true);conversation().draft="Edit existing"');
 e.setApi(p=>p.path==='/ai/status'?{enabled:true}:{id:'job_edit',status:'completed',result:{text:'请确认',tasks:[],edits:[{taskId:'existing',title:'Edited',note:'',category:'生活',minutes:30,deadline:0,priority:3}],warnings:[]}});
 await e.run('sendAi()');assert.equal(e.run('S.data.tasks[0].title'),'Original');e.run('openAiProposal(conversation().result)');e.run('S.data.revision++');e.window.document.getElementById('ai-proposal-confirm').click();await new Promise(r=>setTimeout(r,10));assert.equal(e.run('S.data.tasks[0].title'),'Original');
 e.run('S.aiProposal.baseSignature=JSON.stringify(S.data)');e.window.document.getElementById('ai-proposal-confirm').click();await until(()=>e.run('S.data.tasks[0].title')==='Edited');assert.equal(e.run('S.data.tasks.length'),1);assert(e.run('!!S.aiUndo'));
});
test('failed durable storage prevents sending an AI job',async t=>{
 const e=await environment();t.after(e.close);e.setWrite(p=>{if(p.name==='library')throw Error('Disk full');});e.run('S.tab=3;render(true);conversation().draft="Hello"');await assert.rejects(e.run('sendAi()'),/Disk full/);assert.equal(e.calls.filter(c=>c.command==='api'&&c.params.path==='/ai/jobs').length,0);
});
test('unknown publication preserves the approved card and id across edits',async t=>{
 const e=await environment();t.after(e.close);let count=0;
 e.setApi(p=>{if(p.path==='/feed/posts'&&p.method==='POST'){assert(e.records.get(USER+':pending-feed'));count++;if(count===1)throw Error('Network result unknown');return {id:'post_one'};}return {items:[],nextBefore:0};});
 e.run('openShare();S.share.title="Approved card";previewPublication()');await e.run('publishFeed()');assert(e.run('!!S.pendingFeed'));e.run('S.share.title="Unapproved changed card"');await e.run('publishFeed()');const posts=e.calls.filter(c=>c.command==='api'&&c.params.path==='/feed/posts'&&c.params.method==='POST');assert.deepEqual(posts[0].params.body,posts[1].params.body);assert.equal(posts[1].params.body.card.title,'Approved card');assert.equal(e.records.get(USER+':pending-feed'),null);
});
test('manual backup stores exact CAS request and reuses it after uncertain result',async t=>{
 const e=await environment();t.after(e.close);let posts=0;e.setApi(p=>{if(p.path==='/cloud/head')return {revision:0};if(p.path==='/cloud/history')return {items:[]};if(p.path==='/cloud/snapshot'&&p.method==='PUT'){assert(e.records.get(USER+':pending-sync'));if(++posts===1)throw Error('Network result unknown');return {revision:1};}return {};});
 await e.run('openCloud()');await e.run('beginSync("push")');await e.run('confirmSync()');assert(e.run('!!S.sync.journal'));await e.run('resumeSync()');const sent=e.calls.filter(c=>c.command==='api'&&c.params.method==='PUT');assert.equal(sent.length,2);assert.deepEqual(sent[0].params.body,sent[1].params.body);assert.equal(e.records.get(USER+':pending-sync'),null);
});
test('email retry reuses the saved request id even after reopening its form',async t=>{
 const e=await environment(false);t.after(e.close);let sent=0;e.setApi(p=>{assert.equal(p.path,'/auth/email/send-code');assert(e.records.get('guest:pending-email'));if(++sent===1)throw Error('Unknown SMTP submission');return {id:'receipt_one',status:'queued',retryAfterSeconds:60};});
 await e.run('emailOpen("register")');e.run('S.email.email="test@example.com"');await e.run('emailSend()');await e.run('emailOpen("register")');assert.equal(e.run('S.email.email'),'test@example.com');await e.run('emailSend()');const calls=e.calls.filter(c=>c.command==='api');assert.equal(calls.length,2);assert.deepEqual(calls[0].params.body,calls[1].params.body);assert.equal(e.records.get('guest:pending-email'),null);
});
