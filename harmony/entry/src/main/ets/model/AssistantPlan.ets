import { MobileData, MobileTask, Block, clone, uid, upsertTask, checkData, workHoursOn, dayStart } from './MobileModel';
import { AppTime } from './AppTime';

export class AiTask {title:string='';note:string='';category:string='生活';minutes:number=0;deadline:number=0;priority:number=3;}
export class TaskEdit extends AiTask {taskId:string='';}
export class PlannedTime {taskId:string='';start:number=0;end:number=0;}
export class AssistantPlan {tasks:AiTask[]=[];edits?:TaskEdit[];schedule?:PlannedTime[];}
export function planSize(plan:AssistantPlan):number {return plan.tasks.length+(plan.edits?.length||0)+(plan.schedule?.length||0);}

/** Pure preview/application. No writes; callers compare the base signature and ask for consent. */
export function applyAssistantPlan(data:MobileData,plan:AssistantPlan,now:number=Date.now()):MobileData {
  let next=clone(data);
  const edits=plan.edits||[],times=plan.schedule||[],edited:string[]=[],scheduled:string[]=[],newIds:string[]=[];
  for(const item of edits){
    const old=next.tasks.find((task:MobileTask)=>task.id===item.taskId);
    if(!old||old.done||old.deletedAt||old.id.startsWith('calendar-')||edited.includes(item.taskId)){throw new Error('提案包含不可编辑的事项，请重新生成');}
    if(item.minutes!==0&&item.minutes<15){throw new Error('预计用时至少15分钟，也可以留空');}
    if(item.deadline>0&&next.blocks.some((block:Block)=>block.taskId===item.taskId&&block.end>item.deadline)){throw new Error('新截止时间早于已有安排，请先调整安排');}
    edited.push(item.taskId);const task=cloneTask(old);task.title=item.title.trim();task.note=item.note;task.category=item.category;task.minutes=item.minutes;task.deadline=item.deadline;task.priority=item.priority;task.timeZone=AppTime.zone;
    next.tasks[next.tasks.findIndex((entry:MobileTask)=>entry.id===item.taskId)]=task;
  }
  for(const item of plan.tasks){const task=new MobileTask();task.id=uid('ai_task');task.title=item.title;task.note=item.note;task.category=item.category;task.minutes=item.minutes;task.deadline=item.deadline;task.priority=item.priority;task.createdAt=now;task.timeZone=AppTime.zone;next=upsertTask(next,task);newIds.push(task.id);}
  for(const item of times){
    const target=/^new:\d+$/.test(item.taskId)?newIds[Number(item.taskId.slice(4))]||'':item.taskId;
    const task=next.tasks.find((task:MobileTask)=>task.id===target);
    if(!task||task.done||task.deletedAt||task.id.startsWith('calendar-')||scheduled.includes(target)||!Number.isSafeInteger(item.start)||!Number.isSafeInteger(item.end)||item.start<now||item.end<=item.start||item.end-item.start>1440*60000||task.deadline>0&&item.end>task.deadline){throw new Error('建议时段无效，或超出事项截止时间');}
    if(task.minutes>0&&item.end-item.start!==task.minutes*60000){throw new Error('建议时段与预计用时不一致，请先调整提案');}
    if(next.blocks.some((block:Block)=>block.taskId===target&&(block.locked||block.done||block.start<now))){throw new Error('该事项已有固定或历史安排，请手动调整');}
    const hours=workHoursOn(next,item.start),startClock=AppTime.view(item.start),endClock=AppTime.view(item.end-1);
    if(dayStart(item.start)!==dayStart(item.end-1)||startClock.getHours()*60+startClock.getMinutes()<hours.start||endClock.getHours()*60+endClock.getMinutes()>=hours.end){throw new Error('建议时段须在当天的行动时间内');}
    scheduled.push(target);next.blocks=next.blocks.filter((block:Block)=>block.taskId!==target);
    if(next.blocks.some((block:Block)=>item.start<block.end&&block.start<item.end)){throw new Error('建议时段与已有安排冲突，请先调整提案');}
    const block=new Block();block.id=uid('ai_block');block.taskId=target;block.start=item.start;block.end=item.end;block.timeZone=AppTime.zone;next.blocks.push(block);
  }
  return checkData(next);
}
function cloneTask(task:MobileTask):MobileTask {return JSON.parse(JSON.stringify(task)) as MobileTask;}
