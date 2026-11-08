import { AppTime } from '../model/AppTime';
import { AppData, Task, Block, Course, PlanResult, Unscheduled, LoadBucket, MINUTE, dayStart, addDays, dateKey, remaining } from './Types';
import { taskAvailability, taskWindowsValid } from './TaskRules';

export class Interval { start: number = 0; end: number = 0; }
export function overlap(a: Interval, b: Interval): boolean { return a.start < b.end && b.start < a.end; }
export function effectiveDeadline(task: Task, tasks: Task[]): number {
  let deadline = task.openEnded?Number.MAX_SAFE_INTEGER:task.deadline; let parentId = task.parentId; const visited: string[] = [task.id];
  while (parentId !== '') {
    if (visited.includes(parentId)) { throw new Error('目标层级存在循环'); }
    visited.push(parentId); const parent = tasks.find((t: Task) => t.id === parentId);
    if (parent === undefined) { throw new Error('父目标不存在'); }
    if(!parent.openEnded){deadline = Math.min(deadline,parent.deadline);} parentId = parent.parentId;
  }
  return deadline;
}
export function effectiveEarliest(task:Task,tasks:Task[]):number {
  let earliest=task.earliest;let parentId=task.parentId;const visited:string[]=[task.id];
  while(parentId!==''){if(visited.includes(parentId)){throw new Error('目标层级循环');}visited.push(parentId);const parent=tasks.find((t:Task)=>t.id===parentId);if(parent===undefined){throw new Error('父目标不存在');}earliest=Math.max(earliest,parent.earliest);parentId=parent.parentId;}return earliest;
}
export function validateTask(task: Task, tasks: Task[]): string {
  if (task.title.trim() === '') { return '请输入任务名称'; }
  if (!Number.isFinite(task.deadline) || task.deadline <= 0 || !Number.isFinite(task.earliest) || task.earliest < 0) { return '请输入有效日期时间'; }
  if (task.earliest >= task.deadline) { return '最早开始须早于截止时间'; }
  if (!Number.isFinite(task.minutes) || task.minutes < 15 || task.minutes > 525600) { return '预计工作量须为 15—525600 分钟'; }
  if (task.priority < 0.5 || task.priority > 5 || task.priority*2 !== Math.round(task.priority*2)) { return '重要度须为 0.5—5 星，以半星递增'; }
  if (!Number.isFinite(task.chunk) || task.chunk < 15 || task.chunk > 480) { return '单次时长须为 15—480 分钟'; }
  if(task.windows!==undefined&&!taskWindowsValid(task.windows)){return '可执行时段无效，最多16段';}
  try { if (effectiveDeadline(task,tasks) <= effectiveEarliest(task,tasks)) { return '父目标截止早于子任务开始时间'; } } catch { return '目标层级无效或存在循环'; }
  return '';
}
export function courseOccurrences(data: AppData, from: number, to: number): Interval[] {
  const result: Interval[] = [];
  for (const c of data.courses) {
    if (c.weekdays.length === 0) { if(c.start < to && c.end > from) { result.push({start:c.start,end:c.end}); } continue; }
    const anchor = AppTime.view(c.start); const duration = c.end-c.start;
    for (let day=dayStart(Math.max(from,c.start)); day<to; day=addDays(day,1)) {
      if (!c.weekdays.includes(AppTime.weekday(day))) { continue; }
      const week = Math.floor((dayStart(day)-dayStart(data.settings.termStart))/604800000)+1;
      if (c.weeks.length>0 && !c.weeks.includes(week)) { continue; }
      const at=AppTime.atMinute(day,anchor.getHours()*60+anchor.getMinutes());
      const start=at; if(start < c.start || (c.until>0 && start>c.until)) { continue; }
      if(start<to && start+duration>from) { result.push({start:start,end:start+duration}); }
    }
  }
  return result;
}
export function freeIntervals(data: AppData, from: number, to: number): Interval[] {
  const raw: Interval[]=[];
  for(let day=dayStart(from);day<to;day=addDays(day,1)) {
    const key=dateKey(day),weekday=AppTime.weekday(day);
    for(const f of data.free) {
      if(f.date!=='' ? f.date!==key : f.weekday!==weekday) {continue;}
      if(f.endMinute<=f.startMinute || f.startMinute<0 || f.endMinute>1440) {continue;}
      const start=Math.max(from,AppTime.atMinute(day,f.startMinute)); const end=Math.min(to,AppTime.atMinute(day,f.endMinute));
      if(end>start) {raw.push({start:start,end:end});}
    }
  }
  raw.sort((a:Interval,b:Interval)=>a.start-b.start);
  const merged: Interval[]=[];
  for(const item of raw) {
    const last=merged[merged.length-1];
    if(last!==undefined && item.start<=last.end) {last.end=Math.max(last.end,item.end);} else {merged.push({start:item.start,end:item.end});}
  }
  return merged;
}
export function subtractIntervals(windows: Interval[], busy: Interval[]): Interval[] {
  let available=windows;
  for(const event of busy) {
    const next: Interval[]=[];
    for(const w of available) {
      if(!overlap(w,event)) {next.push(w);continue;}
      if(event.start>w.start) {next.push({start:w.start,end:Math.min(w.end,event.start)});}
      if(event.end<w.end) {next.push({start:Math.max(w.start,event.end),end:w.end});}
    }
    available=next;
  }
  return available;
}
export function schedule(data: AppData, now: number = Date.now()): PlanResult {
  const result=new PlanResult(); const horizon=addDays(dayStart(now),Math.max(1,Math.min(366,data.settings.horizonDays)));
  const preserved=data.blocks.filter((b:Block)=>b.done || b.locked || b.start<now);
  result.preserved=preserved.length; result.blocks=preserved.slice();
  const busy: Interval[]=courseOccurrences(data,now,horizon);
  for(const b of preserved) {if(b.end>now) {busy.push({start:b.start,end:b.end});}}
  let slots=subtractIntervals(freeIntervals(data,Math.ceil(now/(15*MINUTE))*15*MINUTE,horizon),busy);
  const leaves:Task[]=[];
  for(const task of data.tasks.filter((t:Task)=>!t.archived && t.kind!=='goal' && remaining(data,t)>0)) {
    const problem=validateTask(task,data.tasks);
    if(problem!=='') {result.unmet.push({taskId:task.id,minutes:remaining(data,task),reason:problem});}
    else {leaves.push(task);}
  }
  // 截止和松弛时间优先；同等紧急度用重要度，最后用稳定 ID，保证确定性。
  leaves.sort((a:Task,b:Task)=>{
    const ad=effectiveDeadline(a,data.tasks); const bd=effectiveDeadline(b,data.tasks);
    const slackA=(ad-now)/MINUTE-remaining(data,a)*1.5;
    const slackB=(bd-now)/MINUTE-remaining(data,b)*1.5;
    return (slackA-a.priority*120)-(slackB-b.priority*120) || ad-bd || b.priority-a.priority || a.id.localeCompare(b.id);
  });
  for(const task of leaves) {
    const validation=validateTask(task,data.tasks);
    if(validation!=='') {result.unmet.push({taskId:task.id,minutes:remaining(data,task),reason:validation});continue;}
    const deadline=effectiveDeadline(task,data.tasks);
    const committed=preserved.filter((b:Block)=>b.taskId===task.id && !b.done && b.end>now).reduce((sum:number,b:Block)=>sum+(b.end-b.start)/MINUTE,0);
    let needed=Math.max(0,remaining(data,task)-committed); let serial=0;
    while(needed>0) {
      const required=task.splittable ? Math.min(task.chunk,needed) : needed;
      let found=-1; let start=0; let duration=0;
      for(let i=0;i<slots.length;i++) {
        const candidates=taskAvailability(task,slots[i].start,Math.min(slots[i].end,deadline));
        for(const window of candidates){const begin=Math.ceil(Math.max(window.start,effectiveEarliest(task,data.tasks))/(15*MINUTE))*15*MINUTE;
        const available=Math.floor((Math.min(window.end,deadline)-begin)/MINUTE);
        if(available<=0) {continue;}
        const chunk=task.splittable ? Math.min(required,Math.floor(available/15)*15) : required;
        if(chunk<=0 || (!task.splittable && available<required)) {continue;}
        if(chunk<Math.min(15,needed)) {continue;}
        found=i;start=begin;duration=chunk;break;}
        if(found>=0){break;}
      }
      if(found<0) {break;}
      const block=new Block();block.id=`plan-${task.id}-${start}-${serial++}`;block.taskId=task.id;block.start=start;block.end=start+duration*MINUTE;
      while(result.blocks.some((existing:Block)=>existing.id===block.id)){block.id=`plan-${task.id}-${start}-${serial++}`;}
      result.blocks.push(block);needed-=duration;
      slots=subtractIntervals(slots,[{start:block.start,end:block.end}]);
    }
    if(needed>0) {result.unmet.push({taskId:task.id,minutes:needed,reason:deadline<=now?'截止已过':'截止前空闲不足，或没有足够长的连续时段'});}
  }
  const planned=result.blocks.filter((b:Block)=>!preserved.includes(b));
  result.added=planned.filter((b:Block)=>!data.blocks.some((old:Block)=>old.taskId===b.taskId && old.start===b.start && old.end===b.end)).length;
  result.moved=data.blocks.filter((old:Block)=>!preserved.includes(old) && !planned.some((b:Block)=>b.taskId===old.taskId && b.start===old.start && b.end===old.end)).length;
  for(const b of preserved.filter((item:Block)=>item.locked && !item.done)) {
    const t=data.tasks.find((item:Task)=>item.id===b.taskId);
    if(t!==undefined && b.end>effectiveDeadline(t,data.tasks)) {result.warnings.push(`固定安排“${t.title}”超过截止，请手动调整`);}
    if(courseOccurrences(data,b.start,b.end).some((c:Interval)=>overlap(c,{start:b.start,end:b.end}))) {result.warnings.push('固定安排与课表冲突，请手动调整');}
  }
  result.blocks.sort((a:Block,b:Block)=>a.start-b.start || a.id.localeCompare(b.id));
  return result;
}
export function aggregate(data:AppData,from:number,to:number,days:number):LoadBucket[] {
  const buckets:LoadBucket[]=[];
  for(let start=from;start<to;start=addDays(start,days)) {
    const end=Math.min(to,addDays(start,days));const bucket=new LoadBucket();bucket.start=start;bucket.end=end;
    for(const b of data.blocks) {const m=Math.max(0,Math.min(end,b.end)-Math.max(start,b.start))/MINUTE;bucket.planned+=m;if(b.done){bucket.done+=m;}}
    bucket.capacity=subtractIntervals(freeIntervals(data,start,end),courseOccurrences(data,start,end)).reduce((sum:number,w:Interval)=>sum+(w.end-w.start)/MINUTE,0);
    bucket.deadlines=data.tasks.filter((t:Task)=>!t.archived && t.kind!=='goal' && t.deadline>=start && t.deadline<end).length;buckets.push(bucket);
  }
  return buckets;
}
