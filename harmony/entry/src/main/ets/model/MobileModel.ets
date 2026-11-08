import { AppData, Task, Block, FreeWindow, MINUTE, dayStart, addDays, uid, dateKey } from '../engine/Types';
import { schedule, overlap } from '../engine/Scheduler';
import { AppTime } from './AppTime';

export { Block, MINUTE, dayStart, addDays, uid, dateKey };
export class MobileTask {
  timeZone?:string;
  id:string=''; title:string=''; note:string=''; category:string='生活';
  minutes:number=0; deadline:number=0; priority:number=3;
  done:boolean=false; createdAt:number=0; completedAt:number=0; rating:number=0;
  repeat:string='none'; deletedAt:number=0; repeatSource:string='';
}
export class Diary { day:string=''; text:string='';timeZone?:string; }
export class WorkHours {
  start:number;
  end:number;
  constructor(start:number,end:number){this.start=start;this.end=end;}
}
export class WorkDate {
  day:string='';start:number=540;end:number=1320;
}
export class MobileData {
  version:number=1; tasks:MobileTask[]=[]; blocks:Block[]=[]; diaries:Diary[]=[];
  revision:number=0;
  workStart:number=540; workEnd:number=1320; theme:string='light';
  workWindows?:WorkHours[];
  workDates?:WorkDate[];
  tone?:string;
  corners?:string;
  avatar?:string;
  nickname?:string;
  motto?:string;
  timeZone?:string;
  zonePolicy?:string;
}
export class ArrangeResult { data:MobileData=new MobileData(); missing:number=0; skipped:number=0; }
export function clone(value:MobileData):MobileData { return JSON.parse(JSON.stringify(value)) as MobileData; }
export function clock(time:number):string {return AppTime.clock(time);}
export function minuteText(value:number):string {return `${String(Math.floor(value/60)).padStart(2,'0')}:${String(value%60).padStart(2,'0')}`;}
export function localText(value:number):string {return value>0?`${dateKey(value)} ${clock(value)}`:'';}
export function parseTime(value:string):number {
  if(!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(value)){return NaN;}
  let time:number;try{time=AppTime.fromCivil(Date.parse(value.replace(' ','T')+'Z'));}catch{return NaN;}
  return Number.isFinite(time)&&localText(time)===value?time:NaN;
}
export function parseClock(value:string):number {if(!/^\d{2}:\d{2}$/.test(value)){return NaN;}const p=value.split(':');const h=Number(p[0]),m=Number(p[1]);return h<24&&m<60?h*60+m:NaN;}
function validWorkHours(start:number,end:number):boolean {
  return Number.isInteger(start)&&Number.isInteger(end)&&start>=0&&end<=1440&&start<end;
}
export function validZone(zone:string):boolean {return typeof zone==='string'&&zone.length<=80&&/^[A-Za-z0-9_+\-]+(?:\/[A-Za-z0-9_+\-]+){0,2}$/.test(zone);}
export function workHoursFor(data:MobileData,weekday:number):WorkHours {
  const windows=data.workWindows;
  if(windows?.length===7){return windows[weekday];}
  if(windows?.length===2){return windows[weekday===0||weekday===6?1:0];}
  return new WorkHours(data.workStart,data.workEnd);
}
export function workHoursOn(data:MobileData,time:number):WorkHours {
  const override=data.workDates?.find((entry:WorkDate)=>entry.day===dateKey(time));
  return override?new WorkHours(override.start,override.end):workHoursFor(data,AppTime.weekday(time));
}
export function checkData(data:MobileData):MobileData {
  if(data===null||typeof data!=='object'||data.version!==1||!Array.isArray(data.tasks)||!Array.isArray(data.blocks)||!Array.isArray(data.diaries)) {throw new Error('本机记录格式无效，原文件已保留');}
  if(data.revision===undefined){data.revision=0;}
  if(!Number.isSafeInteger(data.revision)||data.revision<0||!validWorkHours(data.workStart,data.workEnd)||!['light','dark','system'].includes(data.theme)) {throw new Error('偏好设置无效，原文件已保留');}
  if(data.workWindows!==undefined&&(!Array.isArray(data.workWindows)||![2,7].includes(data.workWindows.length)||
    data.workWindows.some((hours:WorkHours)=>!hours||!validWorkHours(hours.start,hours.end)))){
    throw new Error('行动时间设置无效');
  }
  if(data.workDates!==undefined&&(!Array.isArray(data.workDates)||data.workDates.length>512||
    data.workDates.some((entry:WorkDate,index:number)=>!entry||typeof entry.day!=='string'||
      !/^\d{4}-\d{2}-\d{2}$/.test(entry.day)||new Date(entry.day+'T12:00:00Z').toISOString().slice(0,10)!==entry.day||
      !validWorkHours(entry.start,entry.end)||data.workDates!.findIndex((other:WorkDate)=>other.day===entry.day)!==index))){
    throw new Error('单日行动时间无效');
  }
  if((data.tone!==undefined&&!['mono','whale','orange','red','green','pink','purple'].includes(data.tone))||
    (data.corners!==undefined&&!['round','square'].includes(data.corners))||
    (data.avatar!==undefined&&(typeof data.avatar!=='string'||!/^whaletodo-avatar-(guest|[a-f0-9-]{36})-\d+\.jpg$/.test(data.avatar)))){
    throw new Error('外观设置无效');
  }
  if((data.nickname!==undefined&&(typeof data.nickname!=='string'||data.nickname.length>40))||
    (data.motto!==undefined&&(typeof data.motto!=='string'||data.motto.length>160))||
    (data.timeZone!==undefined&&!validZone(data.timeZone))||
    (data.zonePolicy!==undefined&&!['absolute','relative'].includes(data.zonePolicy))){throw new Error('个人资料或时区设置无效');}
  if(data.tasks.some((task:MobileTask)=>task.timeZone!==undefined&&!validZone(task.timeZone))||
    data.blocks.some((block:Block)=>block.timeZone!==undefined&&!validZone(block.timeZone))||
    data.diaries.some((diary:Diary)=>diary.timeZone!==undefined&&!validZone(diary.timeZone))){throw new Error('记录时区无效');}
  const ids:string[]=[];
  for(const t of data.tasks){
    if(t.repeat===undefined){t.repeat='none';}if(t.deletedAt===undefined){t.deletedAt=0;}if(t.repeatSource===undefined){t.repeatSource='';}
    if(!['none','daily','weekdays','weekly'].includes(t.repeat)||!Number.isFinite(t.deletedAt)||t.deletedAt<0||typeof t.repeatSource!=='string'||t.repeatSource.length>120){throw new Error('重复或回收记录无效，原文件已保留');}
    if(!t||typeof t.id!=='string'||t.id===''||ids.includes(t.id)||typeof t.title!=='string'||!t.title.trim()||t.title.length>120||typeof t.note!=='string'||t.note.length>2000||typeof t.category!=='string'||!Number.isInteger(t.minutes)||t.minutes<0||t.minutes>525600||!Number.isFinite(t.deadline)||t.deadline<0||!Number.isFinite(t.createdAt)||!Number.isFinite(t.completedAt)||typeof t.done!=='boolean'||!Number.isFinite(t.priority)||t.priority<1||t.priority>5||!Number.isInteger(t.rating)||t.rating<0||t.rating>5){throw new Error('事项记录无效，原文件已保留');}ids.push(t.id);
  }
  const blocks:string[]=[];
  for(const b of data.blocks){if(!b||typeof b.id!=='string'||blocks.includes(b.id)||!ids.includes(b.taskId)||!Number.isFinite(b.start)||!Number.isFinite(b.end)||b.start>=b.end||typeof b.locked!=='boolean'||typeof b.done!=='boolean'){throw new Error('时间安排无效，原文件已保留');}blocks.push(b.id);}
  for(const d of data.diaries){if(!d||typeof d.day!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(d.day)||typeof d.text!=='string'||d.text.length>800){throw new Error('日记记录无效，原文件已保留');}}
  return data;
}
export class PlanProposal {
  id:string='';baseSignature:string='';before:Block[]=[];after:Block[]=[];
  missing:number=0;skipped:number=0;added:number=0;moved:number=0;preserved:number=0;
}
export function proposePlan(data:MobileData,now:number=Date.now()):PlanProposal {
  const planned=arrange(data,now),p=new PlanProposal();p.id=uid('proposal');p.baseSignature=JSON.stringify(data);p.before=clone(data).blocks;p.after=planned.data.blocks;p.missing=planned.missing;p.skipped=planned.skipped;
  p.preserved=p.after.filter((b:Block)=>data.blocks.some((old:Block)=>old.id===b.id&&old.start===b.start&&old.end===b.end)).length;
  p.added=p.after.length-p.preserved;p.moved=data.blocks.filter((old:Block)=>!p.after.some((b:Block)=>b.id===old.id&&b.start===old.start&&b.end===old.end)).length;return p;
}
export function acceptPlan(data:MobileData,proposal:PlanProposal,now:number=Date.now()):MobileData {
  if(JSON.stringify(data)!==proposal.baseSignature){throw new Error('事项已变化，请重新生成计划提案');}
  if(proposal.after.some((b:Block)=>!proposal.before.some((old:Block)=>old.id===b.id)&&b.start<now)){throw new Error('提案的开始时间已过，请重新生成');}
  const next=clone(data);next.blocks=proposal.after.map((b:Block)=>JSON.parse(JSON.stringify(b)) as Block);return checkData(next);
}
export function undoPlan(data:MobileData,before:Block[],appliedSignature:string):MobileData {
  if(JSON.stringify(data)!==appliedSignature){throw new Error('计划之后已有其它修改，不能直接撤销，请重新安排');}
  const next=clone(data);next.blocks=before.map((b:Block)=>JSON.parse(JSON.stringify(b)) as Block);return checkData(next);
}
export function upsertTask(data:MobileData,task:MobileTask,reservation:number=0,now:number=Date.now()):MobileData {
  if(!task.title.trim()){throw new Error('先写下想做的事');}
  if(task.minutes!==0&&task.minutes<15){throw new Error('预计用时至少15分钟，也可以留空稍后整理');}
  const next=clone(data);const index=next.tasks.findIndex((t:MobileTask)=>t.id===task.id);
  task.title=task.title.trim();
  if(index>=0){next.tasks[index]=task;}else{next.tasks.push(task);}
  const protectedBlocks=next.blocks.filter((b:Block)=>b.taskId===task.id&&(b.locked||b.done||b.start<now));
  if(task.deadline>0&&protectedBlocks.some((b:Block)=>b.end>task.deadline)){throw new Error('截止时间早于已保留的安排，请先调整安排');}
  if(reservation>0){
    const end=reservation+task.minutes*MINUTE;
    if(task.done||task.minutes<15||reservation<now||task.deadline<=0||end>task.deadline){throw new Error('预约须在未来，填写用时和截止时间，并在截止前结束');}
    const date=AppTime.view(reservation),hours=workHoursOn(data,reservation);
    const minute=date.getHours()*60+date.getMinutes();
    if(dayStart(reservation)!==dayStart(end-1)||minute<hours.start||minute+task.minutes>hours.end){throw new Error('预约须在当天的行动时间内');}
    if(next.blocks.some((b:Block)=>b.taskId!==task.id&&overlap({start:b.start,end:b.end},{start:reservation,end:end}))){throw new Error('这个时段已有安排，请选择其它时间');}
    if(protectedBlocks.some((b:Block)=>b.done||b.start<now)){throw new Error('事项已有执行记录，暂不能覆盖预约');}
    next.blocks=next.blocks.filter((b:Block)=>b.taskId!==task.id);
    const block=new Block();block.id=uid('manual');block.taskId=task.id;block.start=reservation;block.end=end;block.locked=true;next.blocks.push(block);
  }else if(index>=0){next.blocks=next.blocks.filter((b:Block)=>b.taskId!==task.id||b.locked||b.done||b.start<now);}
  return checkData(next);
}
export function arrange(data:MobileData,now:number=Date.now()):ArrangeResult {
  const engine=new AppData();engine.settings.horizonDays=366;engine.settings.termStart=dayStart(now);
  for(let i=0;i<engine.settings.horizonDays;i++){
    const day=addDays(engine.settings.termStart,i),hours=workHoursOn(data,day),f=new FreeWindow();
    f.id=`day-${dateKey(day)}`;f.date=dateKey(day);f.startMinute=hours.start;f.endMinute=hours.end;engine.free.push(f);
  }
  let skipped=0;
  for(const m of activeTasks(data)){
    if(m.minutes===0||m.deadline===0){if(!m.done){skipped++;}continue;}
    const t=new Task();t.id=m.id;t.title=m.title;t.note=m.note;t.minutes=m.minutes;t.deadline=m.deadline;t.priority=m.priority;t.archived=m.done;t.chunk=Math.min(45,m.minutes);t.createdAt=m.createdAt;engine.tasks.push(t);
  }
  engine.blocks=data.blocks.filter((b:Block)=>data.tasks.some((t:MobileTask)=>t.id===b.taskId&&!t.deletedAt)).map((b:Block)=>JSON.parse(JSON.stringify(b)) as Block);
  const planned=schedule(engine,now);const result=new ArrangeResult();result.data=clone(data);result.data.blocks=planned.blocks;result.missing=planned.unmet.reduce((sum:number,u)=>sum+u.minutes,0);result.skipped=skipped;checkData(result.data);return result;
}
export function finishTask(data:MobileData,id:string,rating:number,now:number=Date.now()):MobileData {
  if(!Number.isInteger(rating)||rating<1||rating>5){throw new Error('请选择1—5星自评');}
  const next=clone(data);const task=next.tasks.find((t:MobileTask)=>t.id===id&&!t.deletedAt);if(task===undefined){throw new Error('事项不存在');}
  if(task.done){task.done=false;task.completedAt=0;task.rating=0;next.blocks=next.blocks.filter((b:Block)=>b.taskId!==id||!b.done);}
  else{task.done=true;task.completedAt=now;task.rating=rating;next.blocks=next.blocks.filter((b:Block)=>b.taskId!==id||b.start<now);for(const b of next.blocks.filter((b:Block)=>b.taskId===id)){b.done=true;b.completedAt=now;b.rating=rating;}
    if(task.repeat&&task.repeat!=='none'&&!next.tasks.some((t:MobileTask)=>t.repeatSource===id)){const upcoming=JSON.parse(JSON.stringify(task)) as MobileTask;upcoming.id=uid('repeat');upcoming.repeatSource=id;upcoming.done=false;upcoming.completedAt=0;upcoming.rating=0;upcoming.createdAt=now;upcoming.deadline=nextRepeat(task.deadline||now,task.repeat,now);next.tasks.push(upcoming);}
  }
  return checkData(next);
}
export function tasksOn(data:MobileData,day:number):MobileTask[] {
  const end=addDays(dayStart(day),1),start=dayStart(day);
  return activeTasks(data).filter((t:MobileTask)=>{const span=allDaySpan(t);if(span.length===2){const key=dateKey(start);return key>=span[0]&&key<=span[1];}const deadline=t.category==='日历'&&t.note.startsWith('全天日程：')&&t.deadline>0?t.deadline-1:t.deadline;return (deadline>=start&&deadline<end)||(t.done&&t.completedAt>=start&&t.completedAt<end)||data.blocks.some((b:Block)=>b.taskId===t.id&&b.start<end&&b.end>start);});
}
export function activeTasks(data:MobileData):MobileTask[] {return data.tasks.filter((t:MobileTask)=>!t.deletedAt);}
export function allDaySpan(task:MobileTask):string[] {
  if(!task.id.startsWith('calendar-event-')||task.category!=='日历'){return [];}
  const found=/^全天日程：(\d{4}-\d{2}-\d{2})(?: — (\d{4}-\d{2}-\d{2}))?(?:\n|$)/.exec(task.note);if(!found){return [];}
  const first=found[1],last=found[2]||first;
  for(const key of [first,last]){const at=Date.parse(key+'T00:00:00Z');if(!Number.isFinite(at)||new Date(at).toISOString().slice(0,10)!==key){return [];}}
  return first<=last?[first,last]:[];
}
export function allDayEvent(data:MobileData,block:Block):boolean {const task=data.tasks.find((item:MobileTask)=>item.id===block.taskId);return !!task&&allDaySpan(task).length===2&&block.id===`calendar-block-${task.id.slice('calendar-'.length)}`;}
export function trashTasks(data:MobileData):MobileTask[] {return data.tasks.filter((t:MobileTask)=>t.deletedAt>0).sort((a:MobileTask,b:MobileTask)=>b.deletedAt-a.deletedAt);}
export function deleteTask(data:MobileData,id:string,now:number=Date.now()):MobileData {const next=clone(data),task=next.tasks.find((t:MobileTask)=>t.id===id&&!t.deletedAt);if(!task){throw new Error('事项不存在');}task.deletedAt=now;next.blocks=next.blocks.filter((b:Block)=>b.taskId!==id);return checkData(next);}
export function restoreTask(data:MobileData,id:string):MobileData {const next=clone(data),task=next.tasks.find((t:MobileTask)=>t.id===id&&t.deletedAt>0);if(!task){throw new Error('回收事项不存在');}task.deletedAt=0;return checkData(next);}
export function nextRepeat(deadline:number,repeat:string,now:number):number {
  if(!['daily','weekdays','weekly'].includes(repeat)){throw new Error('重复规则无效');}
  const step=repeat==='weekly'?7:1;let at=addDays(deadline,step);
  if(at<=now){const elapsed=Math.floor((dayStart(now)-dayStart(at))/(24*60*MINUTE));at=addDays(at,Math.max(0,Math.floor(elapsed/step))*step);while(at<=now){at=addDays(at,step);}}
  if(repeat==='weekdays'){while(AppTime.weekday(at)===0||AppTime.weekday(at)===6){at=addDays(at,1);}}
  return at;
}
export class TaskStats {total:number=0;pending:number=0;completed:number=0;overdue:number=0;completedWeek:number=0;plannedMinutes:number=0;completedMinutes:number=0;}
export function taskStats(data:MobileData,now:number=Date.now()):TaskStats {const s=new TaskStats(),tasks=activeTasks(data),week=addDays(dayStart(now),-6);s.total=tasks.length;s.pending=tasks.filter((t:MobileTask)=>!t.done).length;s.completed=tasks.filter((t:MobileTask)=>t.done).length;s.overdue=tasks.filter((t:MobileTask)=>!t.done&&t.deadline>0&&t.deadline<now).length;s.completedWeek=tasks.filter((t:MobileTask)=>t.done&&t.completedAt>=week&&t.completedAt<=now).length;s.plannedMinutes=data.blocks.filter((b:Block)=>!b.done&&tasks.some((t:MobileTask)=>t.id===b.taskId&&!t.done)).reduce((sum:number,b:Block)=>sum+(b.end-b.start)/MINUTE,0);s.completedMinutes=tasks.filter((t:MobileTask)=>t.done).reduce((sum:number,t:MobileTask)=>sum+t.minutes,0);return s;}
export function monthCells(month:number):number[] {
  const d=AppTime.view(month);d.setDate(1);const first=AppTime.fromView(d);const start=addDays(first,-((d.getDay()+6)%7));const days:number[]=[];for(let i=0;i<42;i++){days.push(addDays(start,i));}return days;
}
