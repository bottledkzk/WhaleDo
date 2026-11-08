import { MobileError, validateSnapshot } from './snapshot.ts';
import { modelTime } from './ai-time.ts';

export type AiKind = 'chat' | 'tasks' | 'review' | 'plan';
export type AiStatus = 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';
export interface AiMessage { role:'user'|'assistant'; content:string; images?:string[]; }
export interface AiInput { requestId:string; kind:AiKind; prompt:string; history:AiMessage[]; images?:string[]; context?:Record<string,unknown>; now?:number;timezoneOffsetMinutes?:number; }
export interface AiTask { title:string; note:string; category:string; minutes:number; deadline:number; priority:number; }
export interface AiEdit extends AiTask {taskId:string;}
export interface AiSchedule {taskId:string;start:number;end:number;}
export interface AiResult { text:string; tasks:AiTask[]; warnings:string[]; edits?:AiEdit[]; schedule?:AiSchedule[]; }
export interface AiReceipt { id:string; status:AiStatus; kind:AiKind; createdAt:number; updatedAt:number; result?:AiResult; error?:{code:string;message:string}; }
export const AI_MODES:AiKind[]=['chat','tasks','review','plan'];
export const AI_RESULT_BYTES=4*1024*1024;
const bad=():never=>{throw new MobileError(400,'INVALID_AI_REQUEST','请检查消息与共享记录的格式');};
const object=(v:unknown):Record<string,unknown>=>{if(!v||typeof v!=='object'||Array.isArray(v))return bad();return v as Record<string,unknown>;};
function images(value:unknown):string[]|undefined {
  if(value===undefined)return undefined;
  if(!Array.isArray(value)||value.length>4)bad();
  for(const item of value as unknown[]){
    if(typeof item!=='string'||item.length>3*1024*1024||!/^data:image\/(jpeg|png);base64,[A-Za-z0-9+/]+={0,2}$/.test(item))bad();
    const url=item as string,bytes=Buffer.from(url.slice(url.indexOf(',')+1),'base64');
    if(bytes.toString('base64')!==url.slice(url.indexOf(',')+1)||
      !(url.startsWith('data:image/jpeg;')?bytes[0]===255&&bytes[1]===216&&bytes[2]===255:bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))))bad();
  }
  return value as string[];
}
export function validateAiInput(value:unknown):AiInput {
  const raw=object(value);
  if(Object.keys(raw).some(k=>!['requestId','kind','prompt','history','images','context','now','timezoneOffsetMinutes'].includes(k))||typeof raw.requestId!=='string'||!/^[A-Za-z0-9_-]{8,120}$/.test(raw.requestId)||!AI_MODES.includes(raw.kind as AiKind)||typeof raw.prompt!=='string'||!raw.prompt.trim()||raw.prompt.length>200000)bad();
  if(raw.now!==undefined&&(!Number.isSafeInteger(raw.now)||Number(raw.now)<0||Number(raw.now)>8640000000000000))bad();
  if(raw.timezoneOffsetMinutes!==undefined&&(!Number.isSafeInteger(raw.timezoneOffsetMinutes)||Number(raw.timezoneOffsetMinutes)<-840||Number(raw.timezoneOffsetMinutes)>840))bad();
  const history=raw.history??[];
  if(!Array.isArray(history)||history.length>200)bad();
  for(const v of history as unknown[]){const m=object(v);if(Object.keys(m).some(k=>!['role','content','images'].includes(k))||!['user','assistant'].includes(String(m.role))||typeof m.content!=='string'||m.content.length>1000000||(m.role!=='user'&&m.images!==undefined))bad();images(m.images);}
  const input:AiInput={requestId:raw.requestId as string,kind:raw.kind as AiKind,prompt:(raw.prompt as string).trim(),history:history as AiMessage[]};
  if(raw.images!==undefined)input.images=images(raw.images);
  if(raw.now!==undefined)input.now=raw.now as number;if(raw.timezoneOffsetMinutes!==undefined)input.timezoneOffsetMinutes=raw.timezoneOffsetMinutes as number;
  if(raw.context!==undefined){
    const context=JSON.parse(validateSnapshot(raw.context)) as Record<string,unknown>;
    const tasks=(context.tasks as Array<Record<string,unknown>>).filter(t=>!t.deletedAt);
    const ids=new Set(tasks.map(t=>t.id));
    context.tasks=tasks;context.blocks=(context.blocks as Array<Record<string,unknown>>).filter(b=>ids.has(b.taskId));
    input.context=context;
  }
  if(Buffer.byteLength(JSON.stringify(input))>8*1024*1024)throw new MobileError(413,'AI_CONTEXT_TOO_LARGE','本次内容和图片较大，请缩小范围或开启新对话');
  return input;
}

export function parseAiResult(content:string,input?:AiInput):AiResult {
  const invalid=():never=>{throw new MobileError(502,'AI_INVALID_RESULT','模型未返回完整可用的提案，本机记录未改动，请调整要求后重试');};
  if(Buffer.byteLength(content)>AI_RESULT_BYTES)throw new MobileError(502,'AI_RESULT_TOO_LARGE','本次结果超出安全接收容量，请拆分任务后重试');
  let raw:Record<string,unknown>;
  try{const parsed=JSON.parse(content.trim());if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))return invalid();raw=parsed;}catch{return invalid();}
  if(typeof raw.text!=='string'||!raw.text.trim()||!Array.isArray(raw.tasks)||raw.tasks.length>1000||!Array.isArray(raw.warnings)||raw.warnings.length>100)return invalid();
  if(raw.edits!==undefined&&(!Array.isArray(raw.edits)||raw.edits.length>200))return invalid();
  if(raw.schedule!==undefined&&(!Array.isArray(raw.schedule)||raw.schedule.length>200))return invalid();
  for(const value of [...raw.tasks,...(raw.edits as unknown[]??[])]){
    if(!value||typeof value!=='object'||Array.isArray(value))return invalid();
    const task=value as Record<string,unknown>;
    task.deadline=modelTime(task.deadline,input);
    const edit=(raw.edits as unknown[]??[]).includes(value);
    if(Object.keys(task).some(k=>!['title','note','category','minutes','deadline','priority',...(edit?['taskId']:[])].includes(k))||edit&&(typeof task.taskId!=='string'||!task.taskId||task.taskId.length>120)||typeof task.title!=='string'||!task.title.trim()||task.title.length>120||typeof task.note!=='string'||task.note.length>2000||typeof task.category!=='string'||task.category.length>120||!Number.isSafeInteger(task.minutes)||Number(task.minutes)<0||Number(task.minutes)>525600||!Number.isSafeInteger(task.deadline)||Number(task.deadline)<0||Number(task.deadline)>8640000000000000||typeof task.priority!=='number'||!Number.isFinite(task.priority)||task.priority<1||task.priority>5)return invalid();
  }
  for(const value of raw.schedule as unknown[]??[]){if(!value||typeof value!=='object'||Array.isArray(value))return invalid();const b=value as Record<string,unknown>;b.start=modelTime(b.start,input,false);b.end=modelTime(b.end,input,false);if(Object.keys(b).some(k=>!['taskId','start','end'].includes(k))||typeof b.taskId!=='string'||!b.taskId||b.taskId.length>120||!Number.isSafeInteger(b.start)||!Number.isSafeInteger(b.end)||Number(b.start)<0||Number(b.end)<=Number(b.start)||Number(b.end)>8640000000000000)return invalid();}
  if(raw.warnings.some(v=>typeof v!=='string'||v.length>2000))return invalid();
  const result:AiResult={text:raw.text.trim(),tasks:raw.tasks as AiTask[],warnings:raw.warnings as string[]};
  if(raw.edits!==undefined)result.edits=raw.edits as AiEdit[];
  if(raw.schedule!==undefined)result.schedule=raw.schedule as AiSchedule[];
  return result;
}
