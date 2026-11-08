import { DatabaseSync } from 'node:sqlite';
import { createHmac,randomInt,randomBytes,randomUUID,timingSafeEqual } from 'node:crypto';
import { MobileError,digest } from './snapshot.ts';
import { normalizeMailbox,MailDeliveryError,type MailPurpose,type MailRuntime } from './mail-provider.ts';
import type { User } from './store.ts';

type MailStatus='queued'|'sending'|'accepted'|'failed'|'unknown';
interface RequestRow {id:string;email:string;purpose:MailPurpose;owner_id:string|null;status:MailStatus;created_at:number;fingerprint:string;}
interface TicketRow {email:string;purpose:MailPurpose;owner_id:string|null;expires_at:number;consumed:number;}
export interface MailReceipt {id:string;status:MailStatus;retryAfterSeconds:number;message:string;}
const CODE_TTL=300000,RESEND_MS=60000,MAX_ATTEMPTS=5,TICKET_TTL=300000;
const invalidCode=()=>new MobileError(400,'INVALID_EMAIL_CODE','验证码不正确或已过期，请检查后重试');
function purpose(raw:unknown):MailPurpose {if(!['register','reset','bind'].includes(String(raw)))throw new MobileError(400,'INVALID_EMAIL_PURPOSE','邮箱操作无效');return raw as MailPurpose;}
function object(value:unknown):Record<string,unknown> {if(!value||typeof value!=='object'||Array.isArray(value))throw new MobileError(400,'VALIDATION_ERROR','请求格式无效');return value as Record<string,unknown>;}
function same(a:string,b:string):boolean {const x=Buffer.from(a,'hex'),y=Buffer.from(b,'hex');return x.length===y.length&&x.length>0&&timingSafeEqual(x,y);}

export class MobileMail {
  private db:DatabaseSync;private runtime:MailRuntime|undefined;private now:()=>number;
  private active=new Map<string,AbortController>();private workers=new Set<Promise<void>>();private stopped=false;private started:boolean;
  constructor(file:string,runtime?:MailRuntime,options:{now?:()=>number;autoStart?:boolean}={}){
    this.runtime=runtime;this.now=options.now??Date.now;this.started=options.autoStart!==false;
    this.db=new DatabaseSync(file);this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS mobile_email_accounts(user_id TEXT PRIMARY KEY REFERENCES mobile_users(id),email TEXT NOT NULL COLLATE NOCASE UNIQUE,verified_at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS mobile_email_requests(id TEXT PRIMARY KEY,email TEXT NOT NULL,purpose TEXT NOT NULL,owner_id TEXT REFERENCES mobile_users(id),request_id TEXT NOT NULL,fingerprint TEXT NOT NULL,status TEXT NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,UNIQUE(email,request_id));
      CREATE INDEX IF NOT EXISTS mobile_email_queue ON mobile_email_requests(status,created_at);
      CREATE INDEX IF NOT EXISTS mobile_email_cooldown ON mobile_email_requests(email,created_at);
      CREATE TABLE IF NOT EXISTS mobile_email_codes(request_id TEXT PRIMARY KEY REFERENCES mobile_email_requests(id),email TEXT NOT NULL,purpose TEXT NOT NULL,owner_id TEXT REFERENCES mobile_users(id),code_hash TEXT NOT NULL,expires_at INTEGER NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,consumed INTEGER NOT NULL DEFAULT 0);
      CREATE INDEX IF NOT EXISTS mobile_email_codes_lookup ON mobile_email_codes(email,purpose,expires_at);
      CREATE TABLE IF NOT EXISTS mobile_email_tickets(token_hash TEXT PRIMARY KEY,email TEXT NOT NULL,purpose TEXT NOT NULL,owner_id TEXT REFERENCES mobile_users(id),expires_at INTEGER NOT NULL,consumed INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS mobile_email_throttle(scope TEXT NOT NULL,scope_hash TEXT NOT NULL,window INTEGER NOT NULL,count INTEGER NOT NULL,PRIMARY KEY(scope,scope_hash,window));`);
    // SMTP may have accepted a message before the old process disappeared. Do not send it twice.
    this.db.prepare("UPDATE mobile_email_requests SET status='unknown',updated_at=? WHERE status='sending'").run(this.now());
    if(this.started&&runtime)setImmediate(()=>this.pump());
  }
  private tx<T>(fn:()=>T):T {this.db.exec('BEGIN IMMEDIATE');try{const value=fn();this.db.exec('COMMIT');return value;}catch(error){this.db.exec('ROLLBACK');throw error;}}
  private requireEnabled():MailRuntime {if(!this.runtime||this.stopped)throw new MobileError(503,'MAIL_NOT_CONFIGURED','邮箱服务待配置，用户名账户仍可正常使用');return this.runtime;}
  status(){return {enabled:!!this.runtime&&!this.stopped,purposes:['register','reset','bind'],codeExpiresSeconds:300,resendAfterSeconds:60};}
  private hmac(value:string):string {return createHmac('sha256',this.requireEnabled().secret).update(value).digest('hex');}
  private receipt(row:RequestRow):MailReceipt {
    const messages:Record<MailStatus,string>={queued:'发送请求已排队，请稍候',sending:'正在提交邮件，请稍候',accepted:'邮件服务已接收，请检查收件箱和垃圾邮件',failed:'邮件服务未接受本次投递，请稍后重新发送',unknown:'投递结果未确认；若已收到邮件，仍可输入验证码'};
    return {id:row.id,status:row.status,retryAfterSeconds:Math.max(0,Math.ceil((row.created_at+RESEND_MS-this.now())/1000)),message:messages[row.status]};
  }
  get(id:string):MailReceipt {
    if(!/^[a-f0-9-]{36}$/.test(id))throw new MobileError(404,'MAIL_REQUEST_NOT_FOUND','未找到这次发送请求');
    const row=this.db.prepare('SELECT * FROM mobile_email_requests WHERE id=?').get(id) as RequestRow|undefined;
    if(!row)throw new MobileError(404,'MAIL_REQUEST_NOT_FOUND','未找到这次发送请求');return this.receipt(row);
  }
  send(raw:unknown,ip:string,owner?:string):MailReceipt {
    const config=this.requireEnabled(),body=object(raw),email=normalizeMailbox(body.email),kind=purpose(body.purpose);
    if(Object.keys(body).some(k=>!['email','purpose','requestId'].includes(k))||typeof body.requestId!=='string'||!/^[A-Za-z0-9_-]{8,120}$/.test(body.requestId))throw new MobileError(400,'VALIDATION_ERROR','请求格式无效');
    if(kind==='bind'&&!owner)throw new MobileError(401,'UNAUTHENTICATED','请先登录账户');
    const boundOwner=kind==='bind'?owner!:null,fingerprint=digest(JSON.stringify([kind,boundOwner])),now=this.now();
    const value=this.tx(()=>{
      const prior=this.db.prepare('SELECT * FROM mobile_email_requests WHERE email=? AND request_id=?').get(email,body.requestId as string) as RequestRow|undefined;
      if(prior){if(prior.fingerprint!==fingerprint)throw new MobileError(409,'IDEMPOTENCY_CONFLICT','这次请求的内容已变化，请重新发送');return this.receipt(prior);}
      const last=this.db.prepare('SELECT created_at FROM mobile_email_requests WHERE email=? ORDER BY created_at DESC LIMIT 1').get(email) as {created_at:number}|undefined;
      if(last&&now-last.created_at<RESEND_MS)throw new MobileError(429,'MAIL_COOLDOWN','请等待一分钟后再获取验证码');
      const count=this.db.prepare("SELECT count(*) AS n FROM mobile_email_requests WHERE status IN ('queued','sending')").get() as {n:number};
      if(count.n>=(config.maxQueued??200))throw new MobileError(503,'MAIL_QUEUE_BUSY','邮件请求较多，请稍后再试');
      const window=Math.floor(now/3600000)*3600000;
      const limits:Array<[string,string,number]>=[['email',this.hmac('mail-scope-email\0'+email),config.perEmailHour??10],['ip',this.hmac('mail-scope-ip\0'+ip),config.perIpHour??120],['global','all',config.perHour??600]];
      for(const [scope,key,limit] of limits){const row=this.db.prepare('SELECT count FROM mobile_email_throttle WHERE scope=? AND scope_hash=? AND window=?').get(scope,key,window) as {count:number}|undefined;if((row?.count??0)>=limit)throw new MobileError(429,'MAIL_RATE_LIMITED','验证码请求较频繁，请稍后再试');}
      for(const [scope,key] of limits)this.db.prepare('INSERT INTO mobile_email_throttle VALUES(?,?,?,1) ON CONFLICT(scope,scope_hash,window) DO UPDATE SET count=count+1').run(scope,key,window);
      this.db.prepare('DELETE FROM mobile_email_throttle WHERE window<?').run(window-86400000);
      const id=randomUUID();this.db.prepare("INSERT INTO mobile_email_requests VALUES(?,?,?,?,?,?,'queued',?,?)").run(id,email,kind,boundOwner,body.requestId as string,fingerprint,now,now);
      return this.get(id);
    });
    if(this.started)setImmediate(()=>this.pump());return value;
  }
  private codeHash(kind:MailPurpose,email:string,owner:string|null,code:string){return this.hmac(`mail-code\0${kind}\0${email}\0${owner??''}\0${code}`);}
  start(){this.started=true;this.pump();}
  private pump():void {
    if(!this.runtime||!this.started||this.stopped||this.active.size)return;
    const row=this.db.prepare("SELECT * FROM mobile_email_requests WHERE status='queued' ORDER BY created_at,id LIMIT 1").get() as RequestRow|undefined;if(!row)return;
    const code=String(randomInt(0,1000000)).padStart(6,'0'),now=this.now();
    this.tx(()=>{
      this.db.prepare("UPDATE mobile_email_requests SET status='sending',updated_at=? WHERE id=? AND status='queued'").run(now,row.id);
      this.db.prepare('UPDATE mobile_email_codes SET consumed=1 WHERE email=? AND purpose=? AND consumed=0').run(row.email,row.purpose);
      this.db.prepare('INSERT INTO mobile_email_codes(request_id,email,purpose,owner_id,code_hash,expires_at) VALUES(?,?,?,?,?,?)').run(row.id,row.email,row.purpose,row.owner_id,this.codeHash(row.purpose,row.email,row.owner_id,code),now+CODE_TTL);
    });
    const controller=new AbortController();this.active.set(row.id,controller);
    const worker=this.deliver(row,code,controller);this.workers.add(worker);void worker.then(()=>this.workers.delete(worker),()=>this.workers.delete(worker));
  }
  private async deliver(row:RequestRow,code:string,controller:AbortController):Promise<void>{
    try{
      await this.requireEnabled().provider.send({email:row.email,purpose:row.purpose,code},controller.signal);
      if(controller.signal.aborted)throw new MailDeliveryError(true);
      this.db.prepare("UPDATE mobile_email_requests SET status='accepted',updated_at=? WHERE id=? AND status='sending'").run(this.now(),row.id);
    }catch(error){
      const uncertain=!(error instanceof MailDeliveryError)||error.uncertain;
      this.db.prepare("UPDATE mobile_email_requests SET status=?,updated_at=? WHERE id=? AND status='sending'").run(uncertain?'unknown':'failed',this.now(),row.id);
      if(!uncertain)this.db.prepare('UPDATE mobile_email_codes SET consumed=1 WHERE request_id=?').run(row.id);
    }finally{this.active.delete(row.id);this.pump();}
  }
  verify(raw:unknown,owner?:string):{ticket:string;expiresInSeconds:number}{
    this.requireEnabled();const body=object(raw),email=normalizeMailbox(body.email),kind=purpose(body.purpose);
    if(Object.keys(body).some(k=>!['email','purpose','code'].includes(k))||typeof body.code!=='string'||!/^\d{6}$/.test(body.code))throw invalidCode();
    if(kind==='bind'&&!owner)throw new MobileError(401,'UNAUTHENTICATED','请先登录账户');
    const boundOwner=kind==='bind'?owner!:null,now=this.now(),codeHash=this.codeHash(kind,email,boundOwner,body.code),token=randomBytes(32).toString('base64url');
    const valid=this.tx(()=>{
      const row=this.db.prepare('SELECT request_id,code_hash,expires_at,attempts FROM mobile_email_codes WHERE email=? AND purpose=? AND owner_id IS ? AND consumed=0 ORDER BY expires_at DESC LIMIT 1').get(email,kind,boundOwner) as {request_id:string;code_hash:string;expires_at:number;attempts:number}|undefined;
      if(!row)return false;
      if(row.expires_at<=now||row.attempts>=MAX_ATTEMPTS){this.db.prepare('UPDATE mobile_email_codes SET consumed=1 WHERE request_id=?').run(row.request_id);return false;}
      if(!same(row.code_hash,codeHash)){this.db.prepare('UPDATE mobile_email_codes SET attempts=attempts+1,consumed=CASE WHEN attempts+1>=? THEN 1 ELSE 0 END WHERE request_id=?').run(MAX_ATTEMPTS,row.request_id);return false;}
      this.db.prepare('UPDATE mobile_email_codes SET consumed=1 WHERE request_id=?').run(row.request_id);
      this.db.prepare('INSERT INTO mobile_email_tickets VALUES(?,?,?,?,?,0)').run(digest(token),email,kind,boundOwner,now+TICKET_TTL);return true;
    });
    if(!valid)throw invalidCode();return {ticket:token,expiresInSeconds:TICKET_TTL/1000};
  }
  assertProof(emailRaw:unknown,kind:MailPurpose,raw:string,owner:string|null=null):void {
    this.requireEnabled();const email=normalizeMailbox(emailRaw);
    if(typeof raw!=='string'||raw.length>200)throw invalidCode();
    const row=this.db.prepare('SELECT * FROM mobile_email_tickets WHERE token_hash=?').get(digest(raw)) as TicketRow|undefined;
    if(!row||row.email!==email||row.purpose!==kind||row.owner_id!==owner||row.consumed||row.expires_at<=this.now())throw invalidCode();
  }
  private ticket(email:string,kind:MailPurpose,raw:string,owner:string|null):void {
    this.assertProof(email,kind,raw,owner);
    this.db.prepare('UPDATE mobile_email_tickets SET consumed=1 WHERE token_hash=?').run(digest(raw));
  }
  register(emailRaw:unknown,username:string,hash:string,token:string,maxAccounts:number):User {
    this.requireEnabled();const email=normalizeMailbox(emailRaw);
    return this.tx(()=>{
      this.ticket(email,'register',token,null);
      if(this.db.prepare('SELECT 1 FROM mobile_email_accounts WHERE email=?').get(email))throw new MobileError(409,'EMAIL_TAKEN','该邮箱已绑定账户，请尝试登录或找回密码');
      if(this.db.prepare('SELECT 1 FROM mobile_users WHERE username=? COLLATE NOCASE').get(username))throw new MobileError(409,'USERNAME_TAKEN','用户名已被使用');
      const count=this.db.prepare('SELECT count(*) AS n FROM mobile_users').get() as {n:number};if(count.n>=maxAccounts)throw new MobileError(409,'ACCOUNT_LIMIT','当前账户容量已满，请联系管理员调整容量');
      const user={id:randomUUID(),username};this.db.prepare('INSERT INTO mobile_users VALUES(?,?,?,?)').run(user.id,user.username,hash,this.now());this.db.prepare('INSERT INTO mobile_email_accounts VALUES(?,?,?)').run(user.id,email,this.now());return user;
    });
  }
  bind(user:string,emailRaw:unknown,token:string,expectedHash:string):void {
    this.requireEnabled();const email=normalizeMailbox(emailRaw);
    this.tx(()=>{
      const account=this.db.prepare('SELECT password_hash FROM mobile_users WHERE id=?').get(user) as {password_hash:string}|undefined;
      if(!account||account.password_hash!==expectedHash)throw new MobileError(401,'UNAUTHENTICATED','账户凭据已变化，请重新登录');
      this.ticket(email,'bind',token,user);
      const existing=this.db.prepare('SELECT user_id FROM mobile_email_accounts WHERE email=?').get(email) as {user_id:string}|undefined;
      if(existing&&existing.user_id!==user)throw new MobileError(409,'EMAIL_TAKEN','该邮箱已绑定其它账户');
      this.db.prepare('INSERT INTO mobile_email_accounts VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET email=excluded.email,verified_at=excluded.verified_at').run(user,email,this.now());
    });
  }
  reset(emailRaw:unknown,token:string,passwordHash:string):void {
    this.requireEnabled();const email=normalizeMailbox(emailRaw);
    this.tx(()=>{
      this.ticket(email,'reset',token,null);
      const account=this.db.prepare('SELECT user_id FROM mobile_email_accounts WHERE email=?').get(email) as {user_id:string}|undefined;
      if(!account)return;
      this.db.prepare('UPDATE mobile_users SET password_hash=? WHERE id=?').run(passwordHash,account.user_id);
      this.db.prepare('UPDATE mobile_sessions SET revoked=1 WHERE user_id=?').run(account.user_id);
      // Outstanding older proofs must not reset a newly established password again.
      this.db.prepare('UPDATE mobile_email_tickets SET consumed=1 WHERE email=?').run(email);
      this.db.prepare('UPDATE mobile_email_codes SET consumed=1 WHERE email=?').run(email);
    });
  }
  accountEmail(user:string):string {return (this.db.prepare('SELECT email FROM mobile_email_accounts WHERE user_id=?').get(user) as {email:string}|undefined)?.email??'';}
  async close(){this.stopped=true;for(const controller of this.active.values())controller.abort();await Promise.allSettled([...this.workers]);this.db.close();}
}
