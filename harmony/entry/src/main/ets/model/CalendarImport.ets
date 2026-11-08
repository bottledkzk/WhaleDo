import { MobileData, MobileTask, Block, clone, checkData, MINUTE, dayStart, dateKey } from './MobileModel';
import { AppTime } from './AppTime';
export class CalendarImportRecord {id:string='';title:string='';start:number=0;end:number=0;location:string='';allDay:boolean=false;}
export function calendarRecord(eventId:number,title:string,start:number,end:number,allDay:boolean,location:string=''):CalendarImportRecord {
  if(!Number.isSafeInteger(eventId)||eventId<0||!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||end<=start){throw new Error('系统日程时间无效，未导入任何事项');}
  const record=new CalendarImportRecord();record.id=`event-${eventId}-${start}-${end}`;record.title=title||'未命名日程';record.location=location;record.start=start;record.end=end;record.allDay=allDay;
  if(allDay){
    const first=new Date(start),last=new Date(end),utcMidnights=first.getUTCHours()===0&&first.getUTCMinutes()===0&&first.getUTCSeconds()===0&&last.getUTCHours()===0&&last.getUTCMinutes()===0&&last.getUTCSeconds()===0;
    // Calendar providers commonly encode date-only holidays at UTC midnight. Preserve their calendar date, not their UTC+8 clock time.
    record.start=utcMidnights?AppTime.fromCivil(Date.UTC(first.getUTCFullYear(),first.getUTCMonth(),first.getUTCDate())):dayStart(start);
    record.end=utcMidnights?AppTime.fromCivil(Date.UTC(last.getUTCFullYear(),last.getUTCMonth(),last.getUTCDate())):dayStart(end);
    if(record.end<=record.start){throw new Error('全天日程日期无效，未导入任何事项');}
  }
  return record;
}
export function calendarImport(data:MobileData,records:CalendarImportRecord[],signature:string,now:number=Date.now()):MobileData {
  if(JSON.stringify(data)!==signature){throw new Error('事项已变化，请重新预览系统日历');}
  if(records.length===0){throw new Error('请先选择要导入的日程');}
  const next=clone(data);let added=0;
  for(const record of records){
    if(!record.id||record.id.length>100||!record.title.trim()||record.title.length>120||!Number.isSafeInteger(record.start)||!Number.isSafeInteger(record.end)||record.start<0||record.end<=record.start||record.end<=now||Math.ceil((record.end-record.start)/MINUTE)>525600||record.location.length>1900){throw new Error('日程内容或时间无效，请重新选择');}
    const id=`calendar-${record.id}`;if(next.tasks.some((t:MobileTask)=>t.id===id)){continue;}
    if(next.blocks.some((b:Block)=>record.start<b.end&&b.start<record.end)){throw new Error(`“${record.title}”与已有或所选安排重叠，请取消冲突项后重试`);}
    const task=new MobileTask();task.id=id;task.title=record.title.trim();task.category='日历';task.note=(record.allDay?`全天日程：${dateKey(record.start)}${dateKey(record.start)!==dateKey(record.end-1)?` — ${dateKey(record.end-1)}`:''}`:'')+(record.location?`${record.allDay?'\n':''}地点：${record.location}`:'');task.minutes=Math.ceil((record.end-record.start)/MINUTE);task.deadline=record.end;task.createdAt=now;next.tasks.push(task);
    const block=new Block();block.id=`calendar-block-${record.id}`;block.taskId=id;block.start=record.start;block.end=record.end;block.locked=true;next.blocks.push(block);added++;
  }
  if(added===0){throw new Error('所选日程已导入，未重复添加；已删除的日程可在回收站恢复');}
  return checkData(next);
}
