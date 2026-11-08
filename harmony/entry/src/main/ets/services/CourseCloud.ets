import { http } from '@kit.NetworkKit';
import { MobileData, checkData } from '../model/MobileModel';
import { SessionVault } from './SessionVault';
import { serverSnapshot } from '../model/SyncPlan';
import { AppTime } from '../model/AppTime';
import { HistoryMessage } from '../model/AiHistory';
import { TaskEdit, PlannedTime, AssistantPlan, AiTask } from '../model/AssistantPlan';
import { COURSE_ENDPOINT as COURSE_FEED_ENDPOINT } from './Endpoint';

export class CloudUser {id:string='';username:string='';}
export class CloudSession {user:CloudUser=new CloudUser();accessToken:string='';refreshToken:string='';accessExpiresAt:number=0;endpoint:string='';}
export class CloudHead {revision:number=0;hash:string='';updatedAt:number=0;}
export class CloudSnapshot extends CloudHead {snapshot:MobileData=new MobileData();}
export class CloudHistory {items:CloudHead[]=[];}
export class AiStatus {enabled:boolean=false;modes:string[]=[];}
export class AiMessage implements HistoryMessage {role:string='user';content:string='';images?:string[];}
export { AiTask };
export class AiResult extends AssistantPlan {text:string='';tasks:AiTask[]=[];warnings:string[]=[];edits?:TaskEdit[];schedule?:PlannedTime[];}
export class FeedCard {style:number=0;title:string='';lines:string[]=[];date:string='';footer:string='';}
export class FeedDraft {requestId:string='';author:string='';card:FeedCard=new FeedCard();caption:string='';}
export class FeedPost {id:string='';author:string='';card:FeedCard=new FeedCard();caption:string='';createdAt:number=0;likes:number=0;liked:boolean=false;mine:boolean=false;}
export class FeedPage {items:FeedPost[]=[];nextBefore:number=0;}
class FeedLike {liked:boolean=false;}
export class AiError {code:string='';message:string='';}
export class AiReceipt {id:string='';status:string='';kind:string='';createdAt:number=0;updatedAt:number=0;result:AiResult=new AiResult();error:AiError=new AiError();}
export class AiClock {now:number=0;timezoneOffsetMinutes:number=0;}
export class EmailStatus {enabled:boolean=false;purposes:string[]=[];codeExpiresSeconds:number=300;resendAfterSeconds:number=60;}
export class EmailReceipt {id:string='';status:string='';retryAfterSeconds:number=60;message:string='';}
export class EmailTicket {ticket:string='';expiresInSeconds:number=300;}
export class EmailOutcome {ok:boolean=false;}
class EmailSendBody {email:string='';purpose:string='';requestId:string='';}
class EmailVerifyBody {email:string='';purpose:string='';code:string='';}
class EmailRegisterBody {username:string='';email:string='';password:string='';ticket:string='';}
class EmailBindBody {email:string='';ticket:string='';currentPassword:string='';}
class EmailResetBody {email:string='';ticket:string='';password:string='';}
class AiRequest {requestId:string='';kind:string='';prompt:string='';now:number=0;timezoneOffsetMinutes:number=0;context?:MobileData;history?:AiMessage[];images?:string[];}
class Envelope<T> {data:T;constructor(data:T){this.data=data;}}
class ServiceHealth {service:string='';contract:string='';maxAccounts:number=0;}
class ErrorDetail {code:string='';message:string='';}
class ErrorEnvelope {error:ErrorDetail=new ErrorDetail();}
class Credentials {username:string='';password:string='';}
class RefreshBody {refreshToken:string='';}
class UploadBody {expectedRevision:number=0;requestId:string='';snapshot:MobileData=new MobileData();}
export class CloudFailure extends Error {status:number=0;constructor(status:number,message:string){super(message);this.status=status;}}

export function courseEndpoint(raw:string):string {
  const value=raw.trim().replace(/\/+$/,'');
  if(!/^https:\/\/mobile-api\.whaletodo\.top(?::\d+)?\/api\/v1$/.test(value)&&!/^http:\/\/127\.0\.0\.1:\d{2,5}\/api\/v1$/.test(value)){throw new Error('请使用独立移动服务地址，或本机调试地址');}
  return value;
}
export class CourseCloud {
  session:CloudSession=new CloudSession();
  private refreshPromise:Promise<CloudSession>|undefined=undefined;
  private generation:number=0;
  private availability:AiStatus|undefined=undefined;
  private availabilityAt:number=0;
  private availabilityGeneration:number=-1;
  private aiClocks:Map<string,AiClock>=new Map<string,AiClock>();
  async load():Promise<void> {
    const value=await SessionVault.read();if(!value){return;}
    const candidate=JSON.parse(value) as CloudSession;courseEndpoint(candidate.endpoint);
    if(!candidate.user||!/^[a-f0-9-]{36}$/.test(candidate.user.id)||!candidate.accessToken||!candidate.refreshToken){throw new Error('登录记录无效，请重新登录');}
    this.generation++;this.session=candidate;
  }
  private async request<T>(base:string,path:string,method:http.RequestMethod,body:string='',token:string=''):Promise<T> {
    const request=http.createHttp();
    try{
      const payload=body===''&&(method===http.RequestMethod.POST||method===http.RequestMethod.DELETE)?'{}':body;
      const result=await request.request(`${courseEndpoint(base)}${path}`,{method:method,header:{'Content-Type':'application/json','User-Agent':'WhaleDo-Harmony/0.4.0','Authorization':token?`Bearer ${token}`:''},extraData:payload,expectDataType:http.HttpDataType.STRING,usingCache:false,connectTimeout:15000,readTimeout:60000,maxLimit:33*1024*1024,maxRedirects:0});
      if(result.responseCode<200||result.responseCode>=300){let message=`服务请求失败（${result.responseCode}）`;try{const detail=JSON.parse(result.result as string) as ErrorEnvelope;message=detail.error.message||message;}catch{}throw new CloudFailure(result.responseCode,message);}
      return (JSON.parse(result.result as string) as Envelope<T>).data;
    }catch(error){if(error instanceof CloudFailure){throw error;}throw new Error('连接暂时不可用，请稍后重试');}finally{request.destroy();}
  }
  async login(base:string,username:string,password:string,register:boolean):Promise<CloudSession> {
    const endpoint=courseEndpoint(base),health=await this.request<ServiceHealth>(endpoint,'/health',http.RequestMethod.GET);
    if(health.service!=='whaletodo-mobile-course'||health.contract!=='harmony-mobile-v1'){throw new Error('地址不是独立的移动课程服务');}
    const body=new Credentials();body.username=username.trim();body.password=password;
    const next=await this.request<CloudSession>(endpoint,register?'/auth/register':'/auth/login',http.RequestMethod.POST,JSON.stringify(body));next.endpoint=endpoint;
    await SessionVault.write(JSON.stringify(next));this.generation++;this.session=next;return next;
  }
  private async refreshSession(old:CloudSession,epoch:number):Promise<CloudSession> {
    if(this.generation!==epoch||this.session.user.id!==old.user.id){throw new Error('账户已变化，请重试');}
    if(this.session.refreshToken!==old.refreshToken){return this.session;}
    if(this.refreshPromise){return await this.refreshPromise;}
    const result=this.performRefresh(old,epoch);this.refreshPromise=result;
    try{return await result;}finally{if(this.refreshPromise===result){this.refreshPromise=undefined;}}
  }
  private async performRefresh(old:CloudSession,epoch:number):Promise<CloudSession> {
    const refresh=new RefreshBody();refresh.refreshToken=old.refreshToken;
    const next=await this.request<CloudSession>(old.endpoint,'/auth/refresh',http.RequestMethod.POST,JSON.stringify(refresh));next.endpoint=old.endpoint;
    if(next.user.id!==old.user.id||this.generation!==epoch||this.session.user.id!==old.user.id){throw new Error('账户已变化，请重试');}
    await SessionVault.write(JSON.stringify(next));
    if(this.generation!==epoch){throw new Error('账户已变化，请重试');}this.session=next;return next;
  }
  private async authorized<T>(path:string,method:http.RequestMethod,body:string=''):Promise<T> {
    if(!this.session.user.id){throw new Error('请先登录账户');}
    const old=this.session,epoch=this.generation;
    try{return await this.request<T>(this.session.endpoint,path,method,body,this.session.accessToken);}catch(error){
      if((error as CloudFailure).status!==401){throw error as Error;}
      const next=await this.refreshSession(old,epoch);
      return await this.request<T>(next.endpoint,path,method,body,next.accessToken);
    }
  }
  async logout():Promise<boolean> {
    let revoked=true;try{await this.authorized<CloudUser>('/auth/logout',http.RequestMethod.POST);}catch{revoked=false;}
    this.generation++;await SessionVault.write('');this.session=new CloudSession();return revoked;
  }
  async head():Promise<CloudHead> {return await this.authorized<CloudHead>('/cloud/head',http.RequestMethod.GET);}
  async history(before:number=Number.MAX_SAFE_INTEGER):Promise<CloudHistory> {return await this.authorized<CloudHistory>(`/cloud/history?before=${before}`,http.RequestMethod.GET);}
  async download(revision:number):Promise<CloudSnapshot> {const result=await this.authorized<CloudSnapshot>(`/cloud/snapshot?revision=${revision}`,http.RequestMethod.GET);result.snapshot=checkData(result.snapshot);return result;}
  async upload(data:MobileData,expected:number,requestId:string):Promise<CloudHead> {const body=new UploadBody();body.snapshot=checkData(data);body.expectedRevision=expected;body.requestId=requestId;return await this.authorized<CloudHead>('/cloud/snapshot',http.RequestMethod.PUT,JSON.stringify(body));}
  async aiStatus():Promise<AiStatus> {if(this.availability?.enabled&&this.availabilityGeneration===this.generation&&Date.now()-this.availabilityAt<30000){return this.availability;}const generation=this.generation;const status=await this.authorized<AiStatus>('/ai/status',http.RequestMethod.GET);if(generation===this.generation){this.availability=status;this.availabilityAt=Date.now();this.availabilityGeneration=generation;}return status;}
  private normalizeAi(receipt:AiReceipt):AiReceipt {if(!receipt.result){receipt.result=new AiResult();}if(!receipt.result.tasks){receipt.result.tasks=[];}if(!receipt.result.warnings){receipt.result.warnings=[];}if(!receipt.error){receipt.error=new AiError();}return receipt;}
  async aiCreate(kind:string,prompt:string,requestId:string,context?:MobileData,history?:AiMessage[],clock?:AiClock,images?:string[]):Promise<AiReceipt> {const body=new AiRequest();body.kind=kind;body.prompt=prompt;body.requestId=requestId;let stamp=clock||this.aiClocks.get(requestId);if(!stamp){stamp=new AiClock();stamp.now=Date.now();stamp.timezoneOffsetMinutes=-AppTime.offset(stamp.now)/60000;if(this.aiClocks.size>=64){this.aiClocks.clear();}this.aiClocks.set(requestId,stamp);}if(!Number.isSafeInteger(stamp.now)||stamp.now<0||!Number.isInteger(stamp.timezoneOffsetMinutes)||stamp.timezoneOffsetMinutes < -840||stamp.timezoneOffsetMinutes>840){throw new Error('请求时间记录无效，请重新发起');}body.now=stamp.now;body.timezoneOffsetMinutes=stamp.timezoneOffsetMinutes;if(context){body.context=serverSnapshot(context);}if(history){body.history=history;}if(images?.length){body.images=images;}return this.normalizeAi(await this.authorized<AiReceipt>('/ai/jobs',http.RequestMethod.POST,JSON.stringify(body)));}
  async aiGet(id:string):Promise<AiReceipt> {return this.normalizeAi(await this.authorized<AiReceipt>(`/ai/jobs/${encodeURIComponent(id)}`,http.RequestMethod.GET));}
  async aiCancel(id:string):Promise<AiReceipt> {return this.normalizeAi(await this.authorized<AiReceipt>(`/ai/jobs/${encodeURIComponent(id)}/cancel`,http.RequestMethod.POST));}
  async feedPage(before:number=0):Promise<FeedPage> {const path='/feed/posts'+(before?`?before=${before}`:'');return this.session.user.id?await this.authorized<FeedPage>(path,http.RequestMethod.GET):await this.request<FeedPage>(COURSE_FEED_ENDPOINT,path,http.RequestMethod.GET);}
  async feedPublish(draft:FeedDraft):Promise<FeedPost> {return await this.authorized<FeedPost>('/feed/posts',http.RequestMethod.POST,JSON.stringify(draft));}
  async feedLike(id:string,liked:boolean):Promise<FeedPost> {const body=new FeedLike();body.liked=liked;return await this.authorized<FeedPost>(`/feed/posts/${encodeURIComponent(id)}/like`,http.RequestMethod.PUT,JSON.stringify(body));}
  async feedDelete(id:string):Promise<EmailOutcome> {return await this.authorized<EmailOutcome>(`/feed/posts/${encodeURIComponent(id)}`,http.RequestMethod.DELETE);}
  async emailStatus(base:string):Promise<EmailStatus> {return await this.request<EmailStatus>(base,'/auth/email/status',http.RequestMethod.GET);}
  async emailSend(base:string,email:string,purpose:string,requestId:string):Promise<EmailReceipt> {const body=new EmailSendBody();body.email=email.trim();body.purpose=purpose;body.requestId=requestId;return purpose==='bind'?await this.authorized<EmailReceipt>('/auth/email/send-code',http.RequestMethod.POST,JSON.stringify(body)):await this.request<EmailReceipt>(base,'/auth/email/send-code',http.RequestMethod.POST,JSON.stringify(body));}
  async emailRequest(base:string,id:string):Promise<EmailReceipt> {return await this.request<EmailReceipt>(base,`/auth/email/requests/${encodeURIComponent(id)}`,http.RequestMethod.GET);}
  async emailVerify(base:string,email:string,purpose:string,code:string):Promise<EmailTicket> {const body=new EmailVerifyBody();body.email=email.trim();body.purpose=purpose;body.code=code.trim();return purpose==='bind'?await this.authorized<EmailTicket>('/auth/email/verify',http.RequestMethod.POST,JSON.stringify(body)):await this.request<EmailTicket>(base,'/auth/email/verify',http.RequestMethod.POST,JSON.stringify(body));}
  async emailRegister(base:string,username:string,email:string,password:string,ticket:string):Promise<CloudSession> {
    const endpoint=courseEndpoint(base),health=await this.request<ServiceHealth>(endpoint,'/health',http.RequestMethod.GET);
    if(health.service!=='whaletodo-mobile-course'||health.contract!=='harmony-mobile-v1'){throw new Error('账户服务暂时不可用');}
    const body=new EmailRegisterBody();body.username=username.trim();body.email=email.trim();body.password=password;body.ticket=ticket;
    const next=await this.request<CloudSession>(endpoint,'/auth/register/email',http.RequestMethod.POST,JSON.stringify(body));next.endpoint=endpoint;
    await SessionVault.write(JSON.stringify(next));this.generation++;this.session=next;return next;
  }
  async emailBind(email:string,ticket:string,currentPassword:string):Promise<EmailOutcome> {const body=new EmailBindBody();body.email=email.trim();body.ticket=ticket;body.currentPassword=currentPassword;return await this.authorized<EmailOutcome>('/me/email/bind',http.RequestMethod.POST,JSON.stringify(body));}
  async emailReset(base:string,email:string,ticket:string,password:string):Promise<EmailOutcome> {const body=new EmailResetBody();body.email=email.trim();body.ticket=ticket;body.password=password;return await this.request<EmailOutcome>(base,'/auth/password/reset',http.RequestMethod.POST,JSON.stringify(body));}
}
