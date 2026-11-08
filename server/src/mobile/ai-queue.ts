import { DatabaseSync } from 'node:sqlite';
import { randomUUID } from 'node:crypto';
import { statfsSync } from 'node:fs';
import { dirname } from 'node:path';
import { MobileError, digest } from './snapshot.ts';
import { AI_MODES, validateAiInput, type AiInput, type AiReceipt, type AiResult, type AiKind, type AiStatus } from './ai-types.ts';
import type { AiProvider } from './ai-provider.ts';

interface Row { id:string; user_id:string; fingerprint:string; kind:AiKind; status:AiStatus; created_at:number; updated_at:number; payload:string; result:string|null; error_code:string|null; error_message:string|null; }
export interface AiQueueOptions { concurrency?:number;maxQueued?:number;timeoutMs?:number;autoStart?:boolean;minimumFreeBytes?:number; }
export class MobileAi {
  private db:DatabaseSync;private provider:AiProvider;private file:string;private concurrency:number;private maxQueued:number;private timeoutMs:number;private minimumFreeBytes:number;
  private running=new Map<string,AbortController>();private workers=new Set<Promise<void>>();private stopped=false;private started:boolean;
  constructor(file:string,provider:AiProvider,options:AiQueueOptions={}){
    this.file=file;this.provider=provider;this.concurrency=options.concurrency??1;this.maxQueued=options.maxQueued??250;this.timeoutMs=options.timeoutMs??600000;this.minimumFreeBytes=options.minimumFreeBytes??512*1024*1024;this.started=options.autoStart!==false;
    if(!Number.isSafeInteger(this.concurrency)||this.concurrency<1||this.concurrency>2||!Number.isSafeInteger(this.maxQueued)||this.maxQueued<1||this.maxQueued>2000||!Number.isSafeInteger(this.timeoutMs)||this.timeoutMs<1)throw new Error('Invalid mobile AI queue configuration');
    this.db=new DatabaseSync(file);this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS mobile_ai_jobs(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES mobile_users(id),request_id TEXT NOT NULL,fingerprint TEXT NOT NULL,kind TEXT NOT NULL,status TEXT NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,payload TEXT NOT NULL,result TEXT,error_code TEXT,error_message TEXT,UNIQUE(user_id,request_id));
      CREATE INDEX IF NOT EXISTS mobile_ai_queue ON mobile_ai_jobs(status,created_at);
      CREATE INDEX IF NOT EXISTS mobile_ai_owner ON mobile_ai_jobs(user_id,created_at);`);
    // A process crash may occur after the provider accepted payment. Never replay automatically.
    this.db.prepare("UPDATE mobile_ai_jobs SET status='failed',updated_at=?,payload='',error_code='AI_INTERRUPTED',error_message=? WHERE status='running'").run(Date.now(),'服务在处理期间重启，结果未确认；请检查需求后重新发送');
    if(this.started)setImmediate(()=>this.pump());
  }
  status(){return {enabled:true,modes:AI_MODES};}
  private receipt(row:Row):AiReceipt {
    const result:AiReceipt={id:row.id,status:row.status,kind:row.kind,createdAt:row.created_at,updatedAt:row.updated_at};
    if(row.result)result.result=JSON.parse(row.result) as AiResult;
    if(row.error_code)result.error={code:row.error_code,message:row.error_message??'请求未完成，请稍后重试'};
    return result;
  }
  get(user:string,id:string):AiReceipt {
    const row=this.db.prepare('SELECT * FROM mobile_ai_jobs WHERE id=? AND user_id=?').get(id,user) as Row|undefined;
    if(!row)throw new MobileError(404,'AI_JOB_NOT_FOUND','没有找到这条请求');return this.receipt(row);
  }
  list(user:string,before:number=Number.MAX_SAFE_INTEGER){return this.db.prepare('SELECT id,kind,status,created_at,updated_at,error_code,error_message FROM mobile_ai_jobs WHERE user_id=? AND created_at<? ORDER BY created_at DESC,id DESC LIMIT 20').all(user,before).map(row=>this.receipt(row as unknown as Row));}
  create(user:string,raw:unknown):AiReceipt {
    if(this.stopped)throw new MobileError(503,'AI_RESTARTING','服务正在更新，请稍后重试');
    const input=validateAiInput(raw),payload=JSON.stringify(input),fingerprint=digest(payload);
    this.db.exec('BEGIN IMMEDIATE');let receipt:AiReceipt;
    try{
      const previous=this.db.prepare('SELECT * FROM mobile_ai_jobs WHERE user_id=? AND request_id=?').get(user,input.requestId) as Row|undefined;
      if(previous){if(previous.fingerprint!==fingerprint)throw new MobileError(409,'IDEMPOTENCY_CONFLICT','同一请求已提交不同内容，请重新发送');receipt=this.receipt(previous);}
      else{
        const count=this.db.prepare("SELECT count(*) AS n FROM mobile_ai_jobs WHERE status IN ('queued','running')").get() as {n:number};
        if(count.n>=this.maxQueued)throw new MobileError(503,'AI_QUEUE_BUSY','等待处理的请求较多，请稍后重试；已有请求会继续处理');
        if(this.minimumFreeBytes>0){const disk=statfsSync(dirname(this.file));if(disk.bavail*disk.bsize<this.minimumFreeBytes)throw new MobileError(503,'AI_STORAGE_BUSY','服务存储空间暂时不足，已有记录已保留，请稍后重试');}
        const id=randomUUID(),now=Date.now();
        this.db.prepare("INSERT INTO mobile_ai_jobs(id,user_id,request_id,fingerprint,kind,status,created_at,updated_at,payload) VALUES(?,?,?,?,?,'queued',?,?,?)").run(id,user,input.requestId,fingerprint,input.kind,now,now,payload);
        receipt={id,status:'queued',kind:input.kind,createdAt:now,updatedAt:now};
      }
      this.db.exec('COMMIT');
    }catch(error){this.db.exec('ROLLBACK');throw error;}
    if(this.started)setImmediate(()=>this.pump());return receipt;
  }
  cancel(user:string,id:string):AiReceipt {
    this.get(user,id);
    this.db.prepare("UPDATE mobile_ai_jobs SET status='cancelled',updated_at=?,payload='',error_code=NULL,error_message=NULL WHERE id=? AND user_id=? AND status IN ('queued','running')").run(Date.now(),id,user);
    this.running.get(id)?.abort();return this.get(user,id);
  }
  start(){this.started=true;this.pump();}
  private pump(){
    if(this.stopped||!this.started)return;
    while(this.running.size<this.concurrency){
      const row=this.db.prepare("SELECT * FROM mobile_ai_jobs WHERE status='queued' ORDER BY created_at,id LIMIT 1").get() as Row|undefined;
      if(!row)break;
      this.db.prepare("UPDATE mobile_ai_jobs SET status='running',updated_at=? WHERE id=? AND status='queued'").run(Date.now(),row.id);
      const controller=new AbortController();this.running.set(row.id,controller);
      const worker=this.execute(row,controller);this.workers.add(worker);void worker.then(()=>this.workers.delete(worker),()=>this.workers.delete(worker));
    }
  }
  private async execute(row:Row,controller:AbortController):Promise<void> {
    const timeout=setTimeout(()=>controller.abort(new Error('AI_TIMEOUT')),this.timeoutMs);
    try{
      const input=JSON.parse(row.payload) as AiInput,result=await this.provider.run(input,controller.signal);
      if(controller.signal.aborted)throw new Error('AI_ABORTED');
      this.db.prepare("UPDATE mobile_ai_jobs SET status='completed',updated_at=?,payload='',result=? WHERE id=? AND status='running'").run(Date.now(),JSON.stringify(result),row.id);
    }catch(error){
      const publicError=error instanceof MobileError?{code:error.code,message:error.message}:controller.signal.aborted?{code:this.stopped?'AI_INTERRUPTED':'AI_TIMEOUT',message:this.stopped?'服务正在更新，本次结果未确认，请重新发送':'模型处理时间较长，本次已停止等待；请缩小要求或稍后重试'}:{code:'AI_UNAVAILABLE',message:'AI 服务暂未完成请求，请稍后重试'};
      this.db.prepare("UPDATE mobile_ai_jobs SET status='failed',updated_at=?,payload='',error_code=?,error_message=? WHERE id=? AND status='running'").run(Date.now(),publicError.code,publicError.message,row.id);
    }finally{clearTimeout(timeout);this.running.delete(row.id);this.pump();}
  }
  async close(){this.stopped=true;for(const controller of this.running.values())controller.abort();await Promise.allSettled([...this.workers]);this.db.close();}
}
