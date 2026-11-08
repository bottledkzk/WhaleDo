import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync,readFileSync,writeFileSync,rmSync,existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createServer,type Socket } from 'node:net';
import { buildMobileApp } from '../src/mobile/app.ts';
import { MobileStore } from '../src/mobile/store.ts';
import { MobileMail } from '../src/mobile/mail.ts';
import { loadMailConfig,createMailRuntime,SmtpCodeProvider,MailDeliveryError,normalizeMailbox,type CodeMail,type MailRuntime,type MailConfig } from '../src/mobile/mail-provider.ts';
import { hashPasswordAsync } from '../src/lib/security.ts';

const PASSWORD='Synthetic-mail-test-only!',OTHER_PASSWORD='Synthetic-mail-updated!';
const CONFIG:MailConfig={host:'smtp.example.test',port:465,secure:true,user:'synthetic-user',pass:'synthetic-private-password',from:'sender@example.test',perEmailHour:10,perIpHour:120,perHour:600,maxQueued:200};
function fixture(options:{disabled?:boolean;autoStart?:boolean;runtime?:Partial<MailRuntime>;send?:(mail:CodeMail,signal:AbortSignal)=>Promise<void>}={}){
  const dir=mkdtempSync(join(tmpdir(),'course-mail-')),file=join(dir,'course.sqlite');let clock=1800000000000;
  const store=new MobileStore(file,()=>clock),messages:CodeMail[]=[];
  const runtime:MailRuntime={secret:'synthetic-course-secret-with-32-bytes',provider:{async send(mail,signal){messages.push({...mail});if(options.send)await options.send(mail,signal);}},...options.runtime};
  const mail=new MobileMail(file,options.disabled?undefined:runtime,{now:()=>clock,autoStart:options.autoStart}),app=buildMobileApp(store,undefined,mail);
  return {dir,file,store,mail,app,messages,runtime,advance(ms:number){clock+=ms;},now:()=>clock,async close(){await app.close();store.close();rmSync(dir,{recursive:true,force:true});}};
}
type Fixture=ReturnType<typeof fixture>;
async function settle(f:Fixture,id:string){for(let i=0;i<100;i++){const value=f.mail.get(id);if(!['queued','sending'].includes(value.status))return value;await new Promise<void>(resolve=>setImmediate(resolve));}throw new Error('Fake mail did not settle');}
async function proof(f:Fixture,email:string,purpose:'register'|'bind'|'reset',owner?:string){const receipt=f.mail.send({email,purpose,requestId:'request_'+Math.random().toString(36).slice(2)},'192.0.2.1',owner);await settle(f,receipt.id);const code=f.messages.findLast(v=>v.email===email&&v.purpose===purpose)!.code;return {code,receipt,ticket:f.mail.verify({email,purpose,code},owner).ticket};}
async function user(f:Fixture,name='alice'){const hash=await hashPasswordAsync(PASSWORD),u=f.store.createUser(name,hash);return {...f.store.createSession(u),hash};}
const auth=(accessToken:string)=>({authorization:'Bearer '+accessToken});

test('mail configuration has no old environment fallback and disabled mail preserves username accounts',async()=>{
  assert.equal(loadMailConfig({SMTP_HOST:'old.example.test',SMTP_USER:'old@example.test',SMTP_PASS:'must-not-use'}),undefined);
  const f=fixture({disabled:true});try{
    assert.equal((await f.app.inject('/api/v1/auth/email/status')).json().data.enabled,false);
    const result=await f.app.inject({method:'POST',url:'/api/v1/auth/email/send-code',payload:{email:'a@example.test',purpose:'register',requestId:'disabled-001'}});
    assert.equal(result.statusCode,503);assert.equal(result.json().error.code,'MAIL_NOT_CONFIGURED');
    assert.equal((await f.app.inject({method:'POST',url:'/api/v1/auth/register',payload:{username:'ordinary',password:PASSWORD}})).statusCode,201);
  }finally{await f.close();}
});

test('private configuration errors hide paths and credentials; runtime secret survives restart',()=>{
  const dir=mkdtempSync(join(tmpdir(),'course-mail-config-')),path=join(dir,'private.json');try{
    writeFileSync(path,JSON.stringify({...CONFIG,from:'sender@example.test\r\nBcc: other@example.test'}));
    assert.throws(()=>loadMailConfig({MOBILE_MAIL_CONFIG_FILE:path}),error=>error instanceof Error&&error.message==='Invalid course mail configuration file');
    writeFileSync(path,JSON.stringify({...CONFIG,enabled:false}));assert.equal(createMailRuntime(join(dir,'db'),{MOBILE_MAIL_CONFIG_FILE:path}),undefined);assert(!existsSync(join(dir,'db.mail-secret')));
    const {pass,...publicConfig}=CONFIG;writeFileSync(path,JSON.stringify({...publicConfig,password:pass}));assert.equal(loadMailConfig({MOBILE_MAIL_CONFIG_FILE:path})!.pass,pass);
    writeFileSync(path,JSON.stringify({...CONFIG,password:'different'}));assert.throws(()=>loadMailConfig({MOBILE_MAIL_CONFIG_FILE:path}),/Invalid course mail configuration file/);
    writeFileSync(path,JSON.stringify(CONFIG));const one=createMailRuntime(join(dir,'db'),{MOBILE_MAIL_CONFIG_FILE:path})!,two=createMailRuntime(join(dir,'db'),{MOBILE_MAIL_CONFIG_FILE:path})!;
    assert.match(one.secret,/^[a-f0-9]{64}$/);assert.equal(two.secret,one.secret);assert.notEqual(one.secret,CONFIG.pass);
    for(const invalid of ['x@example.test\r\nCc:evil@example.test','a@example.test,b@example.test','Name <a@example.test>','a..b@example.test'])assert.throws(()=>normalizeMailbox(invalid));
    assert.equal(normalizeMailbox(' Alice@Example.Test '),'alice@example.test');
  }finally{rmSync(dir,{recursive:true,force:true});}
});

test('SMTP adapter distinguishes accepted, rejected, uncertain and aborted delivery without leaking provider errors',async()=>{
  const message:CodeMail={email:'recipient@example.test',purpose:'reset',code:'123456'};let text='',closed=0;
  const accepted=new SmtpCodeProvider(CONFIG,()=>({async sendMail(input){text=input.text;assert.equal(input.to,message.email);return {accepted:[message.email]};},close(){closed++;}}));
  await accepted.send(message,new AbortController().signal);assert(text.includes(message.code));assert(!text.includes(CONFIG.pass));assert.equal(closed,1);
  for(const [response,uncertain] of [[{code:'EAUTH',message:'private provider credential'},false],[{code:'ETIMEDOUT',message:'private smtp address'},true]] as const){
    const provider=new SmtpCodeProvider(CONFIG,()=>({async sendMail(){throw response;},close(){}}));
    await assert.rejects(provider.send(message,new AbortController().signal),e=>e instanceof MailDeliveryError&&e.uncertain===uncertain&&!e.message.includes('private'));
  }
  const rejected=new SmtpCodeProvider(CONFIG,()=>({async sendMail(){return {accepted:[],rejected:[message.email]};},close(){}}));
  await assert.rejects(rejected.send(message,new AbortController().signal),e=>e instanceof MailDeliveryError&&!e.uncertain);
  const controller=new AbortController(),pending=new SmtpCodeProvider(CONFIG,()=>({sendMail(){return new Promise(()=>{});},close(){}})).send(message,controller.signal);controller.abort();
  await assert.rejects(pending,e=>e instanceof MailDeliveryError&&e.uncertain);
});

test('real Nodemailer abort destroys its TCP socket and sends no credentials or DATA to an unencrypted peer',async()=>{
  const peers=new Set<Socket>();let bytes='',connected:()=>void=()=>{},disconnected:()=>void=()=>{};
  const arrived=new Promise<void>(resolve=>{connected=resolve;}),gone=new Promise<void>(resolve=>{disconnected=resolve;});
  const server=createServer(peer=>{peers.add(peer);peer.on('error',()=>{});peer.on('data',chunk=>{bytes+=chunk.toString();});peer.on('close',()=>{peers.delete(peer);disconnected();});connected();});
  await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));const address=server.address();assert(address&&typeof address!=='string');
  const controller=new AbortController(),provider=new SmtpCodeProvider({...CONFIG,host:'127.0.0.1',port:address.port,secure:false});
  const result=provider.send({email:'recipient@example.test',purpose:'reset',code:'123456'},controller.signal);
  try{
    await Promise.race([arrived,result.then(()=>{throw new Error('SMTP unexpectedly completed before peer connection');})]);controller.abort();await assert.rejects(result,e=>e instanceof MailDeliveryError&&e.uncertain);
    await Promise.race([gone,new Promise<never>((_resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('SMTP socket was not destroyed after abort')),1500);timer.unref();})]);
    assert(!bytes.includes('AUTH'));assert(!bytes.includes('DATA'));assert(!bytes.includes(CONFIG.pass));assert.equal(peers.size,0);
  }finally{controller.abort();for(const peer of peers)peer.destroy();await new Promise<void>(resolve=>server.close(()=>resolve()));}
});

test('202 is a queued receipt, delivery is outside DB transactions, and public receipts contain no address or code',async()=>{
  let release:()=>void=()=>{},writing=false;
  const f=fixture({autoStart:false,send:async()=>{f.store.createUser('concurrent_write','unused-hash');writing=true;await new Promise<void>(resolve=>{release=resolve;});}});
  try{
    const r=await f.app.inject({method:'POST',url:'/api/v1/auth/email/send-code',payload:{email:'new@example.test',purpose:'register',requestId:'queue-test-001'}});
    assert.equal(r.statusCode,202);assert.equal(r.json().data.status,'queued');const id=r.json().data.id;
    f.mail.start();assert(writing);assert.equal(f.mail.get(id).status,'sending');
    const receipt=await f.app.inject('/api/v1/auth/email/requests/'+id);assert.equal(receipt.statusCode,200);assert(!receipt.body.includes('new@example.test'));assert(!receipt.body.includes(f.messages[0]!.code));
    release();assert.equal((await settle(f,id)).status,'accepted');assert(!f.mail.get(id).message.includes('已送达'));
  }finally{release();await f.close();}
});

test('send is idempotent, cooldown spans purposes, and a classroom NAT can request more than five emails',async()=>{
  const f=fixture();try{
    const input={email:'same@example.test',purpose:'register',requestId:'same-send-id'};
    const a=f.mail.send(input,'192.0.2.1'),b=f.mail.send(input,'192.0.2.1');assert.equal(a.id,b.id);await settle(f,a.id);assert.equal(f.messages.length,1);
    assert.throws(()=>f.mail.send({...input,purpose:'reset'},'192.0.2.1'),/内容已变化/);
    assert.throws(()=>f.mail.send({...input,purpose:'reset',requestId:'other-send-id'},'192.0.2.1'),/一分钟/);
    const all=Array.from({length:6},(_,i)=>f.mail.send({email:'nat'+i+'@example.test',purpose:'reset',requestId:'nat-send-'+i},'192.0.2.1'));await settle(f,all.at(-1)!.id);assert.equal(f.messages.length,7);
  }finally{await f.close();}
});

test('wrong codes are counted persistently, expire, and cannot cross purpose, email or owner',async()=>{
  const f=fixture();try{
    const alice=await user(f),bob=await user(f,'bobby'),email='private@example.test';
    const request=f.mail.send({email,purpose:'bind',requestId:'binding-proof-001'},'192.0.2.1',alice.user.id);await settle(f,request.id);const code=f.messages.at(-1)!.code;
    for(const input of [{email,purpose:'reset',code},{email:'other@example.test',purpose:'bind',code}])assert.throws(()=>f.mail.verify(input,alice.user.id));
    assert.throws(()=>f.mail.verify({email,purpose:'bind',code},bob.user.id));
    const wrong=code==='000000'?'111111':'000000';for(let i=0;i<5;i++)assert.throws(()=>f.mail.verify({email,purpose:'bind',code:wrong},alice.user.id));
    assert.throws(()=>f.mail.verify({email,purpose:'bind',code},alice.user.id));
    f.advance(60001);const second=f.mail.send({email,purpose:'bind',requestId:'binding-proof-002'},'192.0.2.1',alice.user.id);await settle(f,second.id);f.advance(300000);
    assert.throws(()=>f.mail.verify({email,purpose:'bind',code:f.messages.at(-1)!.code},alice.user.id));
  }finally{await f.close();}
});

test('registration proof is atomic, one-use and unexpired; username conflicts do not burn proof',async()=>{
  const f=fixture();try{
    f.store.createUser('taken','unused');const email='signup@example.test',p=await proof(f,email,'register');
    assert.throws(()=>f.mail.register(email,'taken','hashed',p.ticket,50),/用户名/);f.mail.assertProof(email,'register',p.ticket);
    const registered=await f.app.inject({method:'POST',url:'/api/v1/auth/register/email',payload:{email,username:'new_user',password:PASSWORD,ticket:p.ticket}});assert.equal(registered.statusCode,201);assert.equal(f.mail.accountEmail(registered.json().data.user.id),email);
    assert.throws(()=>f.mail.assertProof(email,'register',p.ticket));assert.throws(()=>f.mail.verify({email,purpose:'register',code:p.code}));
    const expired=await proof(f,'expired@example.test','register');f.advance(300000);assert.throws(()=>f.mail.register('expired@example.test','expired_user','hash',expired.ticket,50));
    const disk=readFileSync(f.file),wal=existsSync(f.file+'-wal')?readFileSync(f.file+'-wal'):Buffer.alloc(0);
    for(const value of [p.ticket,PASSWORD,CONFIG.pass]){assert(!disk.includes(Buffer.from(value)));assert(!wal.includes(Buffer.from(value)));}
    const db=new DatabaseSync(f.file);try{const row=db.prepare('SELECT code_hash FROM mobile_email_codes WHERE request_id=?').get(p.receipt.id) as {code_hash:string};assert.match(row.code_hash,/^[a-f0-9]{64}$/);assert.notEqual(row.code_hash,p.code);}finally{db.close();}
  }finally{await f.close();}
});

test('binding requires current password and owner-bound proof, and failed-password protection covers the bind route',async()=>{
  const f=fixture();try{
    const a=await user(f),b=await user(f,'bobby'),email='bound@example.test',p=await proof(f,email,'bind',a.user.id);
    const bind=(token:string,password:string)=>f.app.inject({method:'POST',url:'/api/v1/me/email/bind',headers:auth(token),payload:{email,ticket:p.ticket,currentPassword:password}});
    assert.equal((await bind(b.accessToken,PASSWORD)).statusCode,400);assert.equal((await bind(a.accessToken,'wrong')).statusCode,401);assert.equal(f.mail.accountEmail(a.user.id),'');
    assert.equal((await bind(a.accessToken,PASSWORD)).statusCode,200);assert.equal(f.mail.accountEmail(a.user.id),email);
    f.advance(60001);const next=await proof(f,'changed@example.test','bind',a.user.id);
    for(let i=0;i<31;i++)await f.app.inject({method:'POST',url:'/api/v1/me/email/bind',headers:auth(a.accessToken),payload:{email:'changed@example.test',ticket:next.ticket,currentPassword:'wrong'}});
    assert.equal((await f.app.inject({method:'POST',url:'/api/v1/me/email/bind',headers:auth(a.accessToken),payload:{email:'changed@example.test',ticket:next.ticket,currentPassword:PASSWORD}})).statusCode,429);
    assert.equal(f.mail.accountEmail(a.user.id),email);
  }finally{await f.close();}
});

test('reset revokes every session, consumes older proofs, rejects old password and preserves unknown-address privacy',async()=>{
  const f=fixture();try{
    const a=await user(f),extra=f.store.createSession(a.user),email='recover@example.test',binding=await proof(f,email,'bind',a.user.id);f.mail.bind(a.user.id,email,binding.ticket,a.hash);
    f.advance(60001);const first=await proof(f,email,'reset');f.advance(60001);const second=await proof(f,email,'reset');
    const reset=await f.app.inject({method:'POST',url:'/api/v1/auth/password/reset',payload:{email,ticket:second.ticket,password:OTHER_PASSWORD}});assert.equal(reset.statusCode,200);
    for(const session of [a,extra]){assert.throws(()=>f.store.authenticate(session.accessToken));assert.throws(()=>f.store.refresh(session.refreshToken));}
    assert.throws(()=>f.mail.assertProof(email,'reset',first.ticket));
    const login=(password:string)=>f.app.inject({method:'POST',url:'/api/v1/auth/login',payload:{username:a.user.username,password}});
    assert.equal((await login(PASSWORD)).statusCode,401);assert.equal((await login(OTHER_PASSWORD)).statusCode,200);
    const absent=await proof(f,'absent@example.test','reset');const invisible=await f.app.inject({method:'POST',url:'/api/v1/auth/password/reset',payload:{email:'absent@example.test',ticket:absent.ticket,password:OTHER_PASSWORD}});
    assert.equal(invisible.statusCode,reset.statusCode);assert.deepEqual(invisible.json(),reset.json());assert.equal(f.messages.find(v=>v.email==='absent@example.test')?.purpose,'reset');
  }finally{await f.close();}
});

test('an in-flight old-password login cannot create a new session after reset',async()=>{
  const f=fixture();try{
    const a=await user(f),email='race@example.test',binding=await proof(f,email,'bind',a.user.id);f.mail.bind(a.user.id,email,binding.ticket,a.hash);f.advance(60001);const p=await proof(f,email,'reset');
    const response=f.app.inject({method:'POST',url:'/api/v1/auth/login',payload:{username:a.user.username,password:PASSWORD}});
    await new Promise<void>(resolve=>setImmediate(resolve));f.mail.reset(email,p.ticket,'changed-while-scrypt-was-running');
    assert.equal((await response).statusCode,401);assert.throws(()=>f.store.authenticate(a.accessToken));
  }finally{await f.close();}
});

test('unknown SMTP outcome keeps code usable, definitive rejection invalidates it',async()=>{
  for(const uncertain of [true,false]){
    const f=fixture({send:async()=>{throw new MailDeliveryError(uncertain);}});try{
      const email='delivery@example.test',r=f.mail.send({email,purpose:'reset',requestId:'delivery-001'},'192.0.2.1'),final=await settle(f,r.id);assert.equal(final.status,uncertain?'unknown':'failed');
      const verify=()=>f.mail.verify({email,purpose:'reset',code:f.messages[0]!.code});if(uncertain)assert(verify().ticket);else assert.throws(verify);
    }finally{await f.close();}
  }
});

test('restart resumes queued mail once, preserves quota and marks interrupted sends unknown without replay',async()=>{
  const f=fixture({autoStart:false,runtime:{perEmailHour:1}});let reopened:MobileMail|undefined;
  try{
    const a=f.mail.send({email:'queued@example.test',purpose:'reset',requestId:'restart-queued'},'192.0.2.1');
    const b=f.mail.send({email:'interrupted@example.test',purpose:'reset',requestId:'restart-sending'},'192.0.2.1');
    const db=new DatabaseSync(f.file);db.prepare("UPDATE mobile_email_requests SET status='sending' WHERE id=?").run(b.id);db.close();
    await f.app.close();reopened=new MobileMail(f.file,f.runtime,{now:f.now});
    for(let i=0;i<100&&reopened.get(a.id).status!=='accepted';i++)await new Promise<void>(resolve=>setImmediate(resolve));
    assert.equal(reopened.get(a.id).status,'accepted');assert.equal(reopened.get(b.id).status,'unknown');assert.deepEqual(f.messages.map(v=>v.email),['queued@example.test']);
    f.advance(60001);assert.throws(()=>reopened!.send({email:'queued@example.test',purpose:'reset',requestId:'quota-persists'},'192.0.2.1'),/频繁/);
  }finally{if(reopened)await reopened.close();f.store.close();rmSync(f.dir,{recursive:true,force:true});}
});

test('invalid tickets are rejected before the password queue and capacity failure preserves a valid ticket',async()=>{
  const f=fixture();try{
    const invalid=await Promise.all(Array.from({length:12},(_,i)=>f.app.inject({method:'POST',url:'/api/v1/auth/password/reset',payload:{email:'invalid@example.test',ticket:'invalid-'+i,password:PASSWORD}})));assert(invalid.every(v=>v.statusCode===400));
    f.store.createUser('existing','unused');const p=await proof(f,'capacity@example.test','register');assert.throws(()=>f.mail.register('capacity@example.test','overflow','hash',p.ticket,1),/容量/);f.mail.assertProof('capacity@example.test','register',p.ticket);assert(f.mail.register('capacity@example.test','allowed','hash',p.ticket,50));
  }finally{await f.close();}
});

test('authentication bodies and pending password work have explicit memory bounds',async()=>{
  const f=fixture();try{
    const a=await user(f);
    const oversized=await f.app.inject({method:'POST',url:'/api/v1/auth/email/send-code',payload:{email:'body@example.test',purpose:'reset',requestId:'body-limit-001',padding:'x'.repeat(17000)}});assert.equal(oversized.statusCode,413);
    const replies=await Promise.all(Array.from({length:145},()=>f.app.inject({method:'POST',url:'/api/v1/auth/login',payload:{username:a.user.username,password:'wrong-password'}})));
    assert(replies.some(v=>v.statusCode===503&&v.json().error.code==='AUTH_BUSY'));
    assert(replies.some(v=>v.statusCode===429));assert(replies.every(v=>[401,429,503].includes(v.statusCode)));
  }finally{await f.close();}
});
