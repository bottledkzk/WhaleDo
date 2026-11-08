const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),Module=require('node:module');
const ts=require('./toolchain.cjs');
const test=require('node:test');let app;const requests=[],vault=new Map();
const original=Module._load;
Module._load=function(name,parent,isMain){
 if(name==='@kit.NetworkKit')return {http:{RequestMethod:{GET:'GET',POST:'POST',PUT:'PUT',DELETE:'DELETE'},HttpDataType:{STRING:0},createHttp:()=>({destroy(){},async request(url,options){requests.push({path:new URL(url).pathname,body:options.extraData});const response=await app.inject({method:options.method,url:new URL(url).pathname+new URL(url).search,headers:options.header,payload:options.extraData||undefined});return {responseCode:response.statusCode,result:response.body};}})}};
 if(name==='@kit.ArkTS')return {util:{TextEncoder:class{encodeInto(v){return new TextEncoder().encode(v);}},TextDecoder:class{decodeToString(v){return new TextDecoder().decode(v);}}}};
 if(name==='@kit.AssetStoreKit')return {asset:{Tag:{ALIAS:'alias',SECRET:'secret',RETURN_TYPE:'return'},ReturnType:{ALL:1},async query(){return vault.size?[new Map(vault)]:[];},async update(_q,a){vault.set('secret',a.get('secret'));},async add(a){vault.set('secret',a.get('secret'));},async remove(){vault.clear();}}};
 return original.apply(this,arguments);
};
require.extensions['.ets']=(module,file)=>module._compile(ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS},fileName:file.replace(/\.ets$/,'.ts')}).outputText,file);
test('native client serializes authenticated logout correctly and revokes the server session',async()=>{
 const {buildMobileApp}=await import('../../server/src/mobile/app.ts');const {MobileStore}=await import('../../server/src/mobile/store.ts');
 const store=new MobileStore(':memory:');app=buildMobileApp(store);
 try{
  const {CourseCloud,courseEndpoint}=require('../entry/src/main/ets/services/CourseCloud.ets');
  assert.throws(()=>courseEndpoint('https://api.whaletodo.top/api/v1'));
  const client=new CourseCloud();const session=await client.login('http://127.0.0.1:18080/api/v1','client_bridge','SyntheticOnly2026',true);
  const restarted=new CourseCloud();await restarted.load();assert.equal(restarted.session.user.id,session.user.id);
  assert.equal((await restarted.head()).revision,0);assert.equal(await restarted.logout(),true);
  assert.equal(requests.find(x=>x.path==='/api/v1/auth/logout').body,'{}');
  const result=await app.inject({url:'/api/v1/me',headers:{Authorization:'Bearer '+session.accessToken}});assert.equal(result.statusCode,401);
  const empty=new CourseCloud();await empty.load();assert.equal(empty.session.user.id,'');
 }finally{await app.close();store.close();}
});
test('parallel expired requests perform one refresh and preserve the rotated session',async()=>{
 const {buildMobileApp}=await import('../../server/src/mobile/app.ts');const {MobileStore}=await import('../../server/src/mobile/store.ts');
 let now=Date.now();const store=new MobileStore(':memory:',()=>now);app=buildMobileApp(store);vault.clear();requests.length=0;
 try{
  const {CourseCloud}=require('../entry/src/main/ets/services/CourseCloud.ets');const client=new CourseCloud();await client.login('http://127.0.0.1:18080/api/v1','parallel_client','SyntheticOnly2026',true);
  now+=16*60000;const values=await Promise.all([client.head(),client.head(),client.history(),client.head()]);assert.equal(values.length,4);assert.equal(requests.filter(x=>x.path==='/api/v1/auth/refresh').length,1);
  assert.equal((await client.head()).revision,0);const restarted=new CourseCloud();await restarted.load();assert.equal(restarted.session.refreshToken,client.session.refreshToken);assert.equal(await restarted.logout(),true);
 }finally{await app.close();store.close();}
});
test('AI retries reuse persisted clock fields across client recreation and normalize pending receipts',async()=>{
 const {CourseCloud,AiClock}=require('../entry/src/main/ets/services/CourseCloud.ets');const payloads=[];
 app={async inject(request){payloads.push(JSON.parse(request.payload));return {statusCode:202,body:JSON.stringify({data:{id:'pending-job',status:'queued',kind:'tasks'}})};}};
 const clock=new AiClock();clock.now=1793692800000;clock.timezoneOffsetMinutes=-480;
 function client(){const value=new CourseCloud();value.session={user:{id:'12345678-1234-1234-1234-123456789abc'},endpoint:'http://127.0.0.1:18080/api/v1',accessToken:'synthetic',refreshToken:'synthetic',accessExpiresAt:0};return value;}
 const first=await client().aiCreate('tasks','明天读书','persistent-clock-request',undefined,undefined,clock);await client().aiCreate('tasks','明天读书','persistent-clock-request',undefined,undefined,clock);
 assert.deepEqual(payloads[0],payloads[1]);assert.equal(payloads[0].now,clock.now);assert.equal(payloads[0].timezoneOffsetMinutes,-480);assert.equal(first.result.text,'');assert.deepEqual(first.result.tasks,[]);assert.equal(first.error.message,'');
 await assert.rejects(client().aiCreate('tasks','hi','invalid-clock-request',undefined,undefined,{now:1,timezoneOffsetMinutes:1000}),/时间记录无效/);
});

test('native feed client sends JSON for DELETE and round trips explicit likes and publication',async()=>{
 const os=require('node:os');const dir=fs.mkdtempSync(path.join(os.tmpdir(),'whaledo-client-feed-'));const {MobileStore}=await import('../../server/src/mobile/store.ts'),{MobileFeed}=await import('../../server/src/mobile/feed.ts'),{buildMobileApp}=await import('../../server/src/mobile/app.ts');const store=new MobileStore(path.join(dir,'test.sqlite')),feed=new MobileFeed(path.join(dir,'test.sqlite'));app=buildMobileApp(store,undefined,undefined,undefined,feed);
 try{const {CourseCloud,FeedDraft}=require('../entry/src/main/ets/services/CourseCloud.ets'),client=new CourseCloud();await client.login('http://127.0.0.1:18080/api/v1','feed_bridge','SyntheticOnly2026',true);const draft=new FeedDraft();draft.requestId='feed_bridge_1';draft.author='鲸友';draft.card.title='小进步';draft.card.date='2026-11-08';const post=await client.feedPublish(draft);assert.equal((await client.feedLike(post.id,true)).likes,1);assert.equal((await client.feedPage()).items.length,1);await client.feedDelete(post.id);assert.equal((await client.feedPage()).items.length,0);assert.equal(requests.find(r=>r.path.endsWith('/feed/posts/'+post.id)).body,'{}');await client.logout();}finally{await app.close();feed.close();store.close();fs.rmSync(dir,{recursive:true,force:true});}
});
