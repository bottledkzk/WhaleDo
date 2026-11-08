import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { MobileData, checkData, uid } from '../model/MobileModel';
import { TaskEdit, PlannedTime } from '../model/AssistantPlan';
import { AiMessage, AiReceipt, AiClock, AiTask } from './CourseCloud';

export class AssistantPending {
  id:string='';kind:string='chat';prompt:string='';history:AiMessage[]=[];
  context?:MobileData;clock:AiClock=new AiClock();
  images?:string[];
}
export class AssistantRecord {
  version:number=1;owner:string='guest';messages:AiMessage[]=[];
  job:AiReceipt=new AiReceipt();pending:AssistantPending=new AssistantPending();
  baseSignature:string='';displayedJobId:string='';applied:boolean=false;
  mode:string='聊天';readContext:boolean=false;
}
const MAX_FILE:number=96*1024*1024;
export class ConversationInfo {
  id:string='legacy';title:string='新对话';updatedAt:number=0;archived:boolean=false;pinned:boolean=false;manualTitle:boolean=false;
}
class ConversationIndex {version:number=1;owner:string='guest';current:string='legacy';items:ConversationInfo[]=[];}
function pictures(value:string[]|undefined):boolean {return value===undefined||(Array.isArray(value)&&value.length<=4&&value.every((item:string)=>typeof item==='string'&&item.length<=3*1024*1024&&/^data:image\/(jpeg|png);base64,[A-Za-z0-9+/]+={0,2}$/.test(item)));}
function fields(value:Object,allowed:string[]):boolean {return value!==null&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).every((key:string)=>allowed.includes(key));}
function text(value:string,max:number):boolean {return typeof value==='string'&&value.length<=max;}
function messages(value:AiMessage[],maximum:number):boolean {return Array.isArray(value)&&value.length<=maximum&&value.every((m:AiMessage)=>fields(m,['role','content','images'])&&['user','assistant'].includes(m.role)&&text(m.content,4*1024*1024)&&pictures(m.images)&&(m.role==='user'||m.images===undefined));}
function task(value:AiTask):boolean {return fields(value,['title','note','category','minutes','deadline','priority'])&&text(value.title,120)&&value.title.trim().length>0&&text(value.note,2000)&&text(value.category,120)&&Number.isSafeInteger(value.minutes)&&value.minutes>=0&&value.minutes<=525600&&Number.isSafeInteger(value.deadline)&&value.deadline>=0&&value.deadline<=8640000000000000&&Number.isFinite(value.priority)&&value.priority>=1&&value.priority<=5;}
function validEdit(value:TaskEdit):boolean {const base=new AiTask();base.title=value.title;base.note=value.note;base.category=value.category;base.minutes=value.minutes;base.deadline=value.deadline;base.priority=value.priority;return fields(value,['taskId','title','note','category','minutes','deadline','priority'])&&text(value.taskId,120)&&!!value.taskId&&task(base);}
function changes(value:AiReceipt):boolean {return (value.result.edits===undefined||(Array.isArray(value.result.edits)&&value.result.edits.length<=200&&value.result.edits.every((item:TaskEdit)=>validEdit(item))))&&(value.result.schedule===undefined||(Array.isArray(value.result.schedule)&&value.result.schedule.length<=200&&value.result.schedule.every((item:PlannedTime)=>fields(item,['taskId','start','end'])&&text(item.taskId,120)&&!!item.taskId&&Number.isSafeInteger(item.start)&&Number.isSafeInteger(item.end)&&item.start>=0&&item.end>item.start&&item.end<=8640000000000000)));}
export function checkAssistant(value:AssistantRecord,owner:string):AssistantRecord {
  if(!fields(value,['version','owner','messages','job','pending','baseSignature','displayedJobId','applied','mode','readContext'])||value.version!==1||value.owner!==owner||!messages(value.messages,2000)||typeof value.applied!=='boolean'||typeof value.readContext!=='boolean'||!['聊天','拆解任务','计划建议','回顾','日记润色','分享配文'].includes(value.mode)||!text(value.baseSignature,32*1024*1024)||!text(value.displayedJobId,80)){throw new Error('助手会话格式无效，原文件已保留');}
  if(value.baseSignature){checkData(JSON.parse(value.baseSignature) as MobileData);}
  const job=value.job;
  if(!fields(job,['id','status','kind','createdAt','updatedAt','result','error'])||!text(job.id,80)||!['','queued','running','completed','failed','cancelled'].includes(job.status)||!['','chat','tasks','plan','review'].includes(job.kind)||!Number.isSafeInteger(job.createdAt)||job.createdAt<0||!Number.isSafeInteger(job.updatedAt)||job.updatedAt<0||!fields(job.result,['text','tasks','warnings','edits','schedule'])||!text(job.result.text,4*1024*1024)||!Array.isArray(job.result.tasks)||job.result.tasks.length>1000||!job.result.tasks.every((item:AiTask)=>task(item))||!Array.isArray(job.result.warnings)||job.result.warnings.length>100||!job.result.warnings.every((item:string)=>text(item,2000))||!fields(job.error,['code','message'])||!text(job.error.code,120)||!text(job.error.message,2000)){throw new Error('助手请求记录无效，原文件已保留');}
  if(!changes(job)){throw new Error('助手提案格式无效，原记录已保留');}
  if((job.status!==''&&!/^[a-f0-9-]{36}$/.test(job.id))||(job.status==='completed'&&!job.result.text.trim())){throw new Error('助手请求状态无效，原文件已保留');}
  const pending=value.pending;
  if(!fields(pending,['id','kind','prompt','history','context','clock','images'])||!pictures(pending.images)||!text(pending.id,120)||!['chat','tasks','review','plan'].includes(pending.kind)||!text(pending.prompt,200000)||!messages(pending.history,200)||!fields(pending.clock,['now','timezoneOffsetMinutes'])||!Number.isSafeInteger(pending.clock.now)||pending.clock.now<0||!Number.isInteger(pending.clock.timezoneOffsetMinutes)||pending.clock.timezoneOffsetMinutes< -840||pending.clock.timezoneOffsetMinutes>840){throw new Error('助手待发送记录无效，原文件已保留');}
  if(pending.id&&(!/^[A-Za-z0-9_-]{8,120}$/.test(pending.id)||!pending.prompt.trim()||pending.clock.now===0)){throw new Error('助手请求标识无效，原文件已保留');}
  if(pending.context!==undefined){checkData(pending.context);}
  return value;
}
export class AssistantSession {
  private path:string='';private owner:string='guest';
  private base:string='';private indexPath:string='';private library:ConversationIndex=new ConversationIndex();
  init(context:common.Context,owner:string='guest'):AssistantRecord {
    if(owner!=='guest'&&!/^[a-f0-9-]{36}$/.test(owner)){throw new Error('账户标识无效');}
    this.owner=owner;this.base=context.getApplicationContext().filesDir;this.indexPath=`${this.base}/whaletodo-assistant-index-${owner}.json`;
    this.library=new ConversationIndex();this.library.owner=owner;this.library.items=[new ConversationInfo()];
    if(fs.accessSync(this.indexPath)){
      if(fs.statSync(this.indexPath).size>1024*1024){throw new Error('会话列表过大，原文件已保留');}
      try{
        const index=JSON.parse(fs.readTextSync(this.indexPath)) as ConversationIndex;
        if(index.version!==1||index.owner!==owner||!Array.isArray(index.items)||index.items.length===0||index.items.length>1000||
          index.items.some((item:ConversationInfo,i:number)=>!item||!/^([A-Za-z0-9_-]{8,120}|legacy)$/.test(item.id)||!text(item.title,80)||!Number.isSafeInteger(item.updatedAt)||item.updatedAt<0||typeof item.archived!=='boolean'||typeof item.pinned!=='boolean'||typeof item.manualTitle!=='boolean'||index.items.findIndex((other:ConversationInfo)=>other.id===item.id)!==i)||!index.items.some((item:ConversationInfo)=>item.id===index.current)){throw new Error('invalid index');}
        this.library=index;
      }catch{throw new Error('会话列表无法读取，原文件已保留');}
    }
    this.path=this.recordPath(this.library.current);
    const empty=new AssistantRecord();empty.owner=owner;if(!fs.accessSync(this.path)){return empty;}
    if(fs.statSync(this.path).size>MAX_FILE){throw new Error('助手会话文件过大，原文件已保留');}
    try{return checkAssistant(JSON.parse(fs.readTextSync(this.path)) as AssistantRecord,owner);}catch{throw new Error('助手会话无法读取，原文件已保留；事项不受影响');}
  }
  save(value:AssistantRecord):void {
    if(!this.path){throw new Error('助手会话尚未就绪');}checkAssistant(value,this.owner);
    const bytes=new util.TextEncoder().encodeInto(JSON.stringify(value));if(bytes.byteLength>MAX_FILE){throw new Error('本次对话已较长，请开始新对话；原记录保持不变');}
    const file=fs.openSync(`${this.path}.tmp`,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
    try{let offset=0;while(offset<bytes.length){const count=fs.writeSync(file.fd,(bytes.buffer as ArrayBuffer).slice(offset));if(count<=0){throw new Error('助手会话保存中断');}offset+=count;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}
    fs.renameSync(`${this.path}.tmp`,this.path);
    const row=this.library.items.find((item:ConversationInfo)=>item.id===this.library.current);
    if(row){const first=value.messages.find((item:AiMessage)=>item.role==='user');if(!row.manualTitle&&(first?.content||value.pending.prompt)){row.title=(first?.content||value.pending.prompt).slice(0,60);}row.updatedAt=Date.now();}
    this.writeIndex();
  }
  private recordPath(id:string):string {return `${this.base}/whaletodo-assistant-${this.owner}${id==='legacy'?'':'-'+id}.json`;}
  private writeIndex():void {
    const bytes=new util.TextEncoder().encodeInto(JSON.stringify(this.library));
    const file=fs.openSync(this.indexPath+'.tmp',fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
    try{let offset=0;while(offset<bytes.length){const n=fs.writeSync(file.fd,(bytes.buffer as ArrayBuffer).slice(offset));if(n<=0){throw new Error('会话列表保存失败');}offset+=n;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}
    fs.renameSync(this.indexPath+'.tmp',this.indexPath);
  }
  list():ConversationInfo[] {return this.library.items.map((row:ConversationInfo)=>JSON.parse(JSON.stringify(row)) as ConversationInfo).sort((a:ConversationInfo,b:ConversationInfo)=>Number(b.pinned)-Number(a.pinned)||b.updatedAt-a.updatedAt);}
  current():ConversationInfo {return this.list().find((item:ConversationInfo)=>item.id===this.library.current)||new ConversationInfo();}
  create():void {
    if(this.library.items.length>=1000){throw new Error('会话较多，请先整理已有对话');}
    const previous=JSON.stringify(this.library),oldPath=this.path,row=new ConversationInfo();row.id=uid('conversation');row.updatedAt=Date.now();
    this.library.items.push(row);this.library.current=row.id;this.path=this.recordPath(row.id);
    try{const empty=new AssistantRecord();empty.owner=this.owner;this.save(empty);}catch{this.library=JSON.parse(previous) as ConversationIndex;this.path=oldPath;throw new Error('新对话未能保存，原对话保留');}
  }
  open(id:string):void {if(!this.library.items.some((row:ConversationInfo)=>row.id===id)){throw new Error('未找到对话');}const path=this.recordPath(id);if(fs.accessSync(path)){if(fs.statSync(path).size>MAX_FILE){throw new Error('对话文件过大，原文件保留');}checkAssistant(JSON.parse(fs.readTextSync(path)) as AssistantRecord,this.owner);}else if(id!=='legacy'){throw new Error('对话文件未找到，原选择保留');}const previous=this.library.current;this.library.current=id;try{this.writeIndex();this.path=path;}catch{this.library.current=previous;throw new Error('未能切换对话');}}
  edit(id:string,title:string,archived:boolean,pinned:boolean):void {
    const previous=JSON.stringify(this.library),row=this.library.items.find((item:ConversationInfo)=>item.id===id);if(!row){throw new Error('未找到对话');}
    if(!title.trim()||title.trim().length>80){throw new Error('对话名称需为1至80字');}row.manualTitle=true;row.title=title.trim();row.archived=archived;row.pinned=pinned;
    try{this.writeIndex();}catch{this.library=JSON.parse(previous) as ConversationIndex;throw new Error('会话修改未能保存');}
  }
  clear():AssistantRecord {const value=new AssistantRecord();value.owner=this.owner;if(this.path&&fs.accessSync(this.path)){fs.copyFileSync(this.path,`${this.path}.before-clear-${Date.now()}`);}this.save(value);return value;}
}
