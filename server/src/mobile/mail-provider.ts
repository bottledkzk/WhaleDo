import { existsSync,readFileSync,openSync,writeFileSync,closeSync,fsyncSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { connect,type Socket } from 'node:net';
import nodemailer from 'nodemailer';
import { MobileError } from './snapshot.ts';

export type MailPurpose='register'|'reset'|'bind';
export interface CodeMail {email:string;purpose:MailPurpose;code:string;}
export interface MailProvider {send(mail:CodeMail,signal:AbortSignal):Promise<void>;}
export interface MailConfig {host:string;port:number;secure:boolean;user:string;pass:string;from:string;perEmailHour:number;perIpHour:number;perHour:number;maxQueued:number;}
export interface MailRuntime {secret:string;provider:MailProvider;perEmailHour?:number;perIpHour?:number;perHour?:number;maxQueued?:number;}
export class MailDeliveryError extends Error {uncertain:boolean;constructor(uncertain:boolean){super('Mail delivery not confirmed');this.uncertain=uncertain;}}
export function normalizeMailbox(raw:unknown):string {
  if(typeof raw!=='string'||raw.length>254)throw new MobileError(400,'INVALID_EMAIL','请填写有效邮箱地址');
  const email=raw.trim().toLowerCase(),parts=email.split('@');
  if(parts.length!==2||!parts[0]||parts[0].length>64||! /^[A-Za-z0-9!#$%&'*+\/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+\/=?^_`{|}~-]+)*$/.test(parts[0])||!parts[1]||parts[1].split('.').length<2||parts[1].split('.').some(p=>!p||p.length>63||!/^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(p))||parts[1].split('.').at(-1)!.length<2)throw new MobileError(400,'INVALID_EMAIL','请填写有效邮箱地址');
  return email;
}
function limit(value:unknown,fallback:number,min:number,max:number):number {const n=value??fallback;if(typeof n!=='number'||!Number.isSafeInteger(n)||n<min||n>max)throw new Error('Invalid course mail configuration');return n;}
export function loadMailConfig(env:NodeJS.ProcessEnv=process.env):MailConfig|undefined {
  const file=env.MOBILE_MAIL_CONFIG_FILE;if(!file)return undefined;
  try{
    const raw=JSON.parse(readFileSync(file,'utf8').replace(/^\uFEFF/,'')) as Record<string,unknown>;
    if(raw.enabled===false)return undefined;
    const password=raw.password??raw.pass;
    if(raw.password!==undefined&&raw.pass!==undefined&&raw.password!==raw.pass)throw new Error();
    if(!raw||typeof raw!=='object'||Array.isArray(raw)||typeof raw.host!=='string'||!raw.host||/[\s\/@]/.test(raw.host)||typeof raw.user!=='string'||!raw.user||/[\r\n]/.test(raw.user)||typeof password!=='string'||!password.trim()||/[\r\n]/.test(password)||typeof raw.secure!=='boolean')throw new Error();
    const port=limit(raw.port,465,1,65535);if(port===465&&!raw.secure)throw new Error();
    return {host:raw.host,port,secure:raw.secure,user:raw.user,pass:password,from:normalizeMailbox(raw.from),perEmailHour:limit(raw.perEmailHour,10,1,100),perIpHour:limit(raw.perIpHour,120,10,10000),perHour:limit(raw.perHour,600,20,100000),maxQueued:limit(raw.maxQueued,200,1,2000)};
  }catch{throw new Error('Invalid course mail configuration file');}
}
export function createMailRuntime(database:string,env:NodeJS.ProcessEnv=process.env):MailRuntime|undefined {
  const config=loadMailConfig(env);if(!config)return undefined;
  const file=database+'.mail-secret';
  if(!existsSync(file)){let fd:number|undefined;try{fd=openSync(file,'wx',0o600);writeFileSync(fd,randomBytes(32).toString('hex'));fsyncSync(fd);}catch(error){if((error as NodeJS.ErrnoException).code!=='EEXIST')throw new Error('Course mail secret is unavailable');}finally{if(fd!==undefined)closeSync(fd);}}
  let secret:string;try{secret=readFileSync(file,'utf8').trim();}catch{throw new Error('Course mail secret is unavailable');}
  if(!/^[a-f0-9]{64}$/.test(secret))throw new Error('Course mail secret is invalid');
  return {...config,secret,provider:new SmtpCodeProvider(config)};
}
type Sender={sendMail(input:{from:string;to:string;subject:string;text:string}):Promise<{accepted?:unknown[];rejected?:unknown[]}>;close():void;};
function smtpSender(config:MailConfig):Sender {
  let socket:Socket|undefined,closed=false;
  const transport=nodemailer.createTransport({host:config.host,port:config.port,secure:config.secure,auth:{user:config.user,pass:config.pass},requireTLS:!config.secure,tls:{rejectUnauthorized:true},connectionTimeout:10000,greetingTimeout:10000,socketTimeout:20000,logger:false,debug:false,disableFileAccess:true,disableUrlAccess:true,
    // Nodemailer's non-pool close() does not abort an active SMTP connection.
    // The supported getSocket hook lets us destroy the actual TCP connection,
    // including while Nodemailer wraps it for implicit TLS or STARTTLS.
    getSocket(_options:unknown,callback:(error:Error|null,socket:false|{connection:Socket;secured:boolean})=>void){
      if(closed){callback(new MailDeliveryError(true),false);return;}
      let finished=false;const pending=connect({host:config.host,port:config.port});socket=pending;
      const timer=setTimeout(()=>{pending.destroy(new MailDeliveryError(true));},10000);
      const finish=(error:Error|null)=>{if(finished)return;finished=true;clearTimeout(timer);callback(error,error?false:{connection:pending,secured:false});};
      pending.once('error',finish);pending.once('close',()=>finish(new MailDeliveryError(true)));
      pending.once('connect',()=>{if(closed){pending.destroy();finish(new MailDeliveryError(true));}else finish(null);});
    }});
  return {sendMail:input=>transport.sendMail(input),close(){closed=true;socket?.destroy();transport.close();}};
}
export class SmtpCodeProvider implements MailProvider {
  private config:MailConfig;private factory:()=>Sender;
  constructor(config:MailConfig,factory?:()=>Sender){this.config=config;this.factory=factory??(()=>smtpSender(config));}
  async send(mail:CodeMail,signal:AbortSignal):Promise<void>{
    const to=normalizeMailbox(mail.email);if(!['register','reset','bind'].includes(mail.purpose)||!/^\d{6}$/.test(mail.code))throw new MailDeliveryError(false);
    const transport=this.factory();let timer:ReturnType<typeof setTimeout>|undefined;let rejectAbort:(e:Error)=>void=()=>{};
    const stop=()=>{transport.close();rejectAbort(new MailDeliveryError(true));};
    const interrupted=new Promise<never>((_resolve,reject)=>{rejectAbort=reject;});
    signal.addEventListener('abort',stop,{once:true});timer=setTimeout(stop,30000);
    try{
      signal.throwIfAborted();
      const label=mail.purpose==='register'?'注册':mail.purpose==='bind'?'绑定邮箱':'重置密码';
      const delivery=await Promise.race([transport.sendMail({from:this.config.from,to,subject:`鲸办 WhaleDo · ${label}验证码`,text:`你的${label}验证码是：${mail.code}\n5分钟内有效。请勿向他人提供验证码。\n若不是你发起的操作，请忽略此邮件。`}),interrupted]);
      if(!delivery.accepted?.some(value=>String(value).toLowerCase()===to)||delivery.rejected?.some(value=>String(value).toLowerCase()===to))throw new MailDeliveryError(false);
    }catch(error){if(error instanceof MailDeliveryError)throw error;const e=error as {code?:string;responseCode?:number};throw new MailDeliveryError(!['EAUTH','EENVELOPE','EMESSAGE'].includes(e.code??'')&&!(Number(e.responseCode)>=500));}
    finally{if(timer)clearTimeout(timer);signal.removeEventListener('abort',stop);transport.close();}
  }
}
