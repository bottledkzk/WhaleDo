import Fastify, { type FastifyRequest } from 'fastify';
import { hashPasswordAsync, verifyPasswordAsync } from '../lib/security.ts';
import { MobileError } from './snapshot.ts';
import { MobileStore } from './store.ts';
import { MobileAi } from './ai-queue.ts';
import { AI_MODES } from './ai-types.ts';
import { MobileMail } from './mail.ts';
import type { MobileSharedLists } from './shared-lists.ts';
import type { MobileFeed } from './feed.ts';
const bodyObject=(value:unknown):Record<string,unknown>=>{if(!value||typeof value!=='object'||Array.isArray(value))throw new MobileError(400,'VALIDATION_ERROR','请求格式无效');return value as Record<string,unknown>;};
export function buildMobileApp(store: MobileStore, ai?:MobileAi, mail?:MobileMail, shared?:MobileSharedLists, feed?:MobileFeed) {
  const app=Fastify({logger:false,bodyLimit:33*1024*1024,trustProxy:['127.0.0.1','::1']});
  // Serialize memory-intensive password hashing on the small course VPS.
  let tail=Promise.resolve(),queued=0;
  async function passwordJob<T>(work:()=>Promise<T>,ip:string):Promise<T>{
    const before=attempts.get(ip);if(before&&before.until>Date.now()&&before.count>30)throw new MobileError(429,'RATE_LIMITED','失败尝试过多，请稍后再试');
    if(queued>=128)throw new MobileError(503,'AUTH_BUSY','账户请求较多，请稍后重试');
    queued++;const previous=tail;let release:()=>void=()=>{};tail=new Promise<void>(resolve=>{release=resolve;});await previous;
    try{const bucket=attempts.get(ip);if(bucket&&bucket.until>Date.now()&&bucket.count>30)throw new MobileError(429,'RATE_LIMITED','失败尝试过多，请稍后再试');return await work();}finally{queued--;release();}
  }
  const attempts=new Map<string,{until:number;count:number}>();
  const token=(r:FastifyRequest)=>{const auth=r.headers.authorization;if(!auth?.startsWith('Bearer ')||auth.length>300)throw new MobileError(401,'UNAUTHENTICATED','请先登录账户');return auth.slice(7);};
  const owner=(r:FastifyRequest)=>store.authenticate(token(r));
  const response=(data:unknown)=>({data});
  if(feed){
    app.get<{Querystring:{before?:string}}>('/api/v1/feed/posts',async request=>response(feed.list(request.headers.authorization?owner(request).id:'',request.query.before===undefined?undefined:Number(request.query.before))));
    app.post('/api/v1/feed/posts',{bodyLimit:16*1024},async(request,reply)=>reply.code(201).send(response(feed.publish(owner(request).id,request.body))));
    app.put<{Params:{id:string}}>('/api/v1/feed/posts/:id/like',{bodyLimit:1024},async request=>response(feed.like(owner(request).id,request.params.id,bodyObject(request.body).liked)));
    app.delete<{Params:{id:string}}>('/api/v1/feed/posts/:id',async request=>response(feed.remove(owner(request).id,request.params.id)));
  }
  const guardedAuth=(url:string)=>url.startsWith('/api/v1/auth/')||url.split('?')[0]==='/api/v1/me/email/bind';
  app.addHook('onRoute',options=>{if(guardedAuth(options.url))options.bodyLimit=16*1024;});
  app.addHook('onRequest',async(request,reply)=>{reply.header('Cache-Control','no-store');reply.header('X-Content-Type-Options','nosniff');
    if(!guardedAuth(request.url))return;
    const now=Date.now();for(const [key,bucket] of attempts)if(bucket.until<=now)attempts.delete(key);
    if(attempts.size>5000)throw new MobileError(429,'RATE_LIMITED','请求过于频繁，请稍后再试');
    const key=request.ip;let bucket=attempts.get(key);if(!bucket){bucket={until:now+60000,count:0};attempts.set(key,bucket);}if(bucket.count>30)throw new MobileError(429,'RATE_LIMITED','失败尝试过多，请稍后再试');
  });
  app.addHook('onResponse',async(request,reply)=>{if(guardedAuth(request.url)&&reply.statusCode===401){const bucket=attempts.get(request.ip);if(bucket)bucket.count++;}});
  app.setErrorHandler((error,_request,reply)=>{
    if(error instanceof MobileError)return reply.code(error.status).send({error:{code:error.code,message:error.message}});
    const status=(error as {statusCode?:number}).statusCode;
    if(status===413)return reply.code(413).send({error:{code:'SNAPSHOT_TOO_LARGE',message:'请求内容过大'}});
    if(status&&status<500)return reply.code(status).send({error:{code:'VALIDATION_ERROR',message:'请求格式无效'}});
    return reply.code(500).send({error:{code:'INTERNAL',message:'服务暂时不可用，请稍后重试'}});
  });
  app.get('/api/v1/health',async()=>response({service:'whaletodo-mobile-course',contract:'harmony-mobile-v1',storage:'sqlite',version:'0.3.0',maxAccounts:store.maxAccounts}));
  app.post('/api/v1/auth/register',async(request,reply)=>{
    const body=bodyObject(request.body);const username=body.username,password=body.password;
    if(typeof username!=='string'||!/^[A-Za-z0-9_]{3,32}$/.test(username)||typeof password!=='string'||password.length<8||password.length>200)throw new MobileError(400,'VALIDATION_ERROR','用户名为3—32位字母数字或下划线，密码至少8位');
    store.assertRegistrationAvailable(username);
    const hash=await passwordJob(()=>{store.assertRegistrationAvailable(username);return hashPasswordAsync(password);},request.ip);const user=store.createUser(username,hash);return reply.code(201).send(response(store.createSession(user)));
  });
  app.post('/api/v1/auth/login',async request=>{
    const b=bodyObject(request.body);if(typeof b.username!=='string'||typeof b.password!=='string'||b.username.length>32||b.password.length>200)throw new MobileError(400,'VALIDATION_ERROR','请检查用户名和密码');
    const user=store.userByName(b.username);const password=b.password;if(!user||!await passwordJob(()=>verifyPasswordAsync(password,user.password_hash),request.ip))throw new MobileError(401,'INVALID_CREDENTIALS','用户名或密码错误');
    // A reset may finish while this login is waiting for the password queue.
    if(store.userByName(user.username)?.password_hash!==user.password_hash)throw new MobileError(401,'INVALID_CREDENTIALS','用户名或密码错误');
    return response(store.createSession({id:user.id,username:user.username}));
  });
  app.post('/api/v1/auth/refresh',async request=>{const b=bodyObject(request.body);if(typeof b.refreshToken!=='string'||b.refreshToken.length>200)throw new MobileError(400,'VALIDATION_ERROR','请求格式无效');return response(store.refresh(b.refreshToken));});
  app.post('/api/v1/auth/logout',async request=>{store.logout(token(request));return response({ok:true});});
  const mailService=()=>{if(!mail)throw new MobileError(503,'MAIL_NOT_CONFIGURED','邮箱服务待配置，用户名账户仍可正常使用');return mail;};
  app.get('/api/v1/auth/email/status',async()=>response(mail?mail.status():{enabled:false,purposes:['register','reset','bind'],codeExpiresSeconds:300,resendAfterSeconds:60}));
  app.post('/api/v1/auth/email/send-code',async(request,reply)=>{const b=bodyObject(request.body);const user=b.purpose==='bind'?owner(request):undefined;return reply.code(202).send(response(mailService().send(b,request.ip,user?.id)));});
  app.get<{Params:{id:string}}>('/api/v1/auth/email/requests/:id',async request=>response(mailService().get(request.params.id)));
  app.post('/api/v1/auth/email/verify',async request=>{const b=bodyObject(request.body),user=b.purpose==='bind'?owner(request):undefined;return response(mailService().verify(b,user?.id));});
  app.post('/api/v1/auth/register/email',async(request,reply)=>{
    const b=bodyObject(request.body);if(Object.keys(b).some(k=>!['username','email','password','ticket'].includes(k))||typeof b.username!=='string'||!/^[A-Za-z0-9_]{3,32}$/.test(b.username)||typeof b.password!=='string'||b.password.length<8||b.password.length>200||typeof b.ticket!=='string'||b.ticket.length>200)throw new MobileError(400,'VALIDATION_ERROR','请检查用户名、密码和邮箱验证码');
    const service=mailService();if(!service.status().enabled)throw new MobileError(503,'MAIL_NOT_CONFIGURED','邮箱服务待配置，用户名账户仍可正常使用');
    const password=b.password,ticket=b.ticket,username=b.username;service.assertProof(b.email,'register',ticket);store.assertRegistrationAvailable(username);
    const hash=await passwordJob(()=>{service.assertProof(b.email,'register',ticket);store.assertRegistrationAvailable(username);return hashPasswordAsync(password);},request.ip),user=service.register(b.email,username,hash,ticket,store.maxAccounts);
    return reply.code(201).send(response(store.createSession(user)));
  });
  app.post('/api/v1/auth/password/reset',async request=>{
    const b=bodyObject(request.body);if(Object.keys(b).some(k=>!['email','ticket','password'].includes(k))||typeof b.password!=='string'||b.password.length<8||b.password.length>200||typeof b.ticket!=='string'||b.ticket.length>200)throw new MobileError(400,'VALIDATION_ERROR','请检查邮箱验证码和新密码');
    const service=mailService();if(!service.status().enabled)throw new MobileError(503,'MAIL_NOT_CONFIGURED','邮箱服务待配置，用户名账户仍可正常使用');
    const password=b.password,ticket=b.ticket;service.assertProof(b.email,'reset',ticket);
    const hash=await passwordJob(()=>{service.assertProof(b.email,'reset',ticket);return hashPasswordAsync(password);},request.ip);service.reset(b.email,ticket,hash);return response({ok:true});
  });
  app.get('/api/v1/me/email',async request=>{const user=owner(request),email=mailService().accountEmail(user.id);return response({email,verified:!!email});});
  app.post('/api/v1/me/email/bind',async request=>{
    const user=owner(request),b=bodyObject(request.body);if(Object.keys(b).some(k=>!['email','ticket','currentPassword'].includes(k))||typeof b.currentPassword!=='string'||b.currentPassword.length>200||typeof b.ticket!=='string'||b.ticket.length>200)throw new MobileError(400,'VALIDATION_ERROR','请检查邮箱验证码和当前密码');
    const service=mailService();if(!service.status().enabled)throw new MobileError(503,'MAIL_NOT_CONFIGURED','邮箱服务待配置，用户名账户仍可正常使用');
    const record=store.userByName(user.username),password=b.currentPassword,ticket=b.ticket;service.assertProof(b.email,'bind',ticket,user.id);
    if(!record||!await passwordJob(()=>{service.assertProof(b.email,'bind',ticket,user.id);return verifyPasswordAsync(password,record.password_hash);},request.ip))throw new MobileError(401,'INVALID_CREDENTIALS','当前密码不正确');
    owner(request);
    service.bind(user.id,b.email,b.ticket,record.password_hash);return response({ok:true});
  });
  app.get('/api/v1/me',async request=>response(owner(request)));
  app.get('/api/v1/cloud/head',async request=>response(store.head(owner(request).id)));
  app.get<{Querystring:{before?:string}}>('/api/v1/cloud/history',async request=>{const before=request.query.before===undefined?Number.MAX_SAFE_INTEGER:Number(request.query.before);if(!Number.isSafeInteger(before)||before<1)throw new MobileError(400,'VALIDATION_ERROR','备份页码无效');return response({items:store.history(owner(request).id,before)});});
  app.get<{Querystring:{revision?:string}}>('/api/v1/cloud/snapshot',async request=>{
    const revision=request.query.revision===undefined?undefined:Number(request.query.revision);
    if(revision!==undefined&&(!Number.isSafeInteger(revision)||revision<1))throw new MobileError(400,'VALIDATION_ERROR','备份版本无效');
    return response(store.snapshot(owner(request).id,revision));
  });
  app.put('/api/v1/cloud/snapshot',async request=>{const user=owner(request),b=bodyObject(request.body);return response(store.put(user.id,b.expectedRevision as number,b.requestId as string,b.snapshot));});
  if (shared) {
    app.get('/api/v1/shared/lists', async request => response({ items: shared.list(owner(request).id) }));
    app.post('/api/v1/shared/lists', { bodyLimit: 4096 }, async request => {
      const user = owner(request);
      const body = bodyObject(request.body);
      return response(shared.create(user.id, body.title, body.requestId));
    });
    app.post('/api/v1/shared/join', { bodyLimit: 4096 }, async request => {
      const user = owner(request);
      return response(shared.join(user.id, bodyObject(request.body).code));
    });
    app.get<{ Params: { listId: string } }>('/api/v1/shared/lists/:listId', async request =>
      response(shared.get(owner(request).id, request.params.listId)));
    app.post<{ Params: { listId: string } }>('/api/v1/shared/lists/:listId/invite', { bodyLimit: 4096 },
      async request => response(shared.invite(owner(request).id, request.params.listId)));
    app.delete<{ Params: { listId: string; memberId: string } }>('/api/v1/shared/lists/:listId/members/:memberId',
      async request => response(shared.remove(owner(request).id, request.params.listId, request.params.memberId)));
    app.put<{ Params: { listId: string; itemId: string } }>('/api/v1/shared/lists/:listId/items/:itemId',
      { bodyLimit: 4096 }, async request => {
        const user = owner(request);
        const body = bodyObject(request.body);
        return response(shared.write(user.id, request.params.listId, request.params.itemId,
          body.expectedRevision, body.title, body.done));
      });
    app.addHook('onClose', async () => shared.close());
  }
  const aiService=()=>{if(!ai)throw new MobileError(503,'AI_NOT_CONFIGURED','AI 服务尚未接入，请稍后重试；本地计划仍可使用');return ai;};
  app.get('/api/v1/ai/status',async request=>{owner(request);return response(ai?ai.status():{enabled:false,modes:AI_MODES});});
  app.post('/api/v1/ai/jobs',{bodyLimit:8*1024*1024+4096},async(request,reply)=>{const user=owner(request);return reply.code(202).send(response(aiService().create(user.id,request.body)));});
  app.get<{Querystring:{before?:string}}>('/api/v1/ai/jobs',async request=>{const user=owner(request);const before=request.query.before===undefined?Number.MAX_SAFE_INTEGER:Number(request.query.before);if(!Number.isSafeInteger(before)||before<1)throw new MobileError(400,'VALIDATION_ERROR','请求页码无效');return response({items:aiService().list(user.id,before)});});
  app.get<{Params:{id:string}}>('/api/v1/ai/jobs/:id',async request=>{const user=owner(request);return response(aiService().get(user.id,request.params.id));});
  app.post<{Params:{id:string}}>('/api/v1/ai/jobs/:id/cancel',async request=>{const user=owner(request);return response(aiService().cancel(user.id,request.params.id));});
  if(ai)app.addHook('onClose',async()=>{await ai.close();});
  if(mail)app.addHook('onClose',async()=>{await mail.close();});
  return app;
}
