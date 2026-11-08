import { Task, TaskWindow, MINUTE, addDays, dayStart, parseLocalDateTime } from './Types';
export const OPEN_DEADLINE:number=new Date(2099,11,31,23,59).getTime();
export class TaskInterval { start:number=0;end:number=0; }
export class PhaseDraft { id:string='';title:string='';start:string='';end:string='';effort:string='30';unit:string='分钟'; }
export class WindowDraft { dated:boolean=false;date:string='';days:number[]=[1,2,3,4,5];start:string='18:00';end:string='20:00'; }
export function minuteOfDay(value:string):number {if(!/^\d{2}:\d{2}$/.test(value)){return -1;}const h=Number(value.slice(0,2)),m=Number(value.slice(3));return h>=0&&h<=24&&m>=0&&m<60&&(h!==24||m===0)?h*60+m:-1;}
export function durationMinutes(value:string,unit:string):number {
  if(!/^(?:\d+(?:\.\d+)?|\.\d+)$/.test(value.trim())){throw new Error('请输入有效工作量');}
  const result=Number(value)*(unit==='小时'?60:unit==='天'?1440:1);
  if(!Number.isInteger(result)||result<15||result>525600){throw new Error('工作量须折合15—525600整数分钟');}return result;
}
export function taskWindowsValid(windows:TaskWindow[]):boolean {
  return Array.isArray(windows)&&windows.length<=16&&windows.every((w:TaskWindow)=>w!==null&&typeof w.date==='string'&&(w.date===''||Number.isFinite(parseLocalDateTime(`${w.date} 00:00`)))&&Array.isArray(w.weekdays)&&w.weekdays.length<=7&&w.weekdays.every((n:number)=>Number.isInteger(n)&&n>=0&&n<=6)&&(w.date!==''||w.weekdays.length>0)&&Number.isInteger(w.startMinute)&&Number.isInteger(w.endMinute)&&w.startMinute>=0&&w.endMinute<=1440&&w.startMinute<w.endMinute);
}
export function taskAvailability(task:Task,from:number,to:number):TaskInterval[] {
  if(!task.windows||task.windows.length===0){return [{start:from,end:to}];}
  const result:TaskInterval[]=[];
  for(let day=dayStart(from);day<to;day=addDays(day,1)){
    const date=new Date(day);const key=`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
    for(const w of task.windows){if(w.date!==''?w.date!==key:!w.weekdays.includes(date.getDay())){continue;}const start=Math.max(from,day+w.startMinute*MINUTE),end=Math.min(to,day+w.endMinute*MINUTE);if(end>start){result.push({start,end});}}
  }
  const sorted=result.sort((a:TaskInterval,b:TaskInterval)=>a.start-b.start||a.end-b.end);const merged:TaskInterval[]=[];for(const span of sorted){const last=merged[merged.length-1];if(last!==undefined&&span.start<=last.end){last.end=Math.max(last.end,span.end);}else{merged.push({start:span.start,end:span.end});}}return merged;
}
