import { MobileData, MobileTask, Block, clone, checkData, validZone, allDaySpan, allDayEvent } from './MobileModel';
import { AppTime } from './AppTime';

export function changeTimeZone(data:MobileData,zone:string,policy:string,now:number=Date.now()):MobileData {
  if(!validZone(zone)||!['absolute','relative'].includes(policy)){throw new Error('请选择时区和同步方式');}
  const next=clone(data),old=data.timeZone||AppTime.zone;
  AppTime.offset(now,zone);
  for(const task of next.tasks){task.timeZone=task.timeZone||old;}
  for(const block of next.blocks){block.timeZone=block.timeZone||old;}
  for(const diary of next.diaries){diary.timeZone=diary.timeZone||old;}
  if(old!==zone){for(const task of next.tasks){
    const span=allDaySpan(task);if(span.length!==2){continue;}
    const start=AppTime.fromCivil(Date.parse(span[0]+'T00:00:00Z'),zone),end=AppTime.fromCivil(Date.parse(span[1]+'T00:00:00Z')+86400000,zone);
    task.deadline=end;task.minutes=Math.round((end-start)/60000);task.timeZone=zone;
    for(const block of next.blocks.filter((item:Block)=>item.taskId===task.id&&allDayEvent(next,item))){block.start=start;block.end=end;block.timeZone=zone;}
  }}
  if(old!==zone&&policy==='relative'){
    for(const task of next.tasks){
      if(allDaySpan(task).length===2){continue;}
      if(!task.done&&!task.deletedAt&&task.deadline>now){const shifted=AppTime.move(task.deadline,old,zone);if(shifted<=now){throw new Error('切换会把截止时间移到过去，请先调整事项');}task.deadline=shifted;task.timeZone=zone;}
    }
    for(const block of next.blocks){
      if(allDayEvent(next,block)){continue;}
      if(block.done||block.start<=now){continue;}
      const start=AppTime.move(block.start,old,zone),end=AppTime.move(block.end,old,zone);
      if(start<=now||end-start!==block.end-block.start){throw new Error('切换会改变安排时长或移到过去，请调整安排后重试');}
      block.start=start;block.end=end;block.timeZone=zone;
    }
  }
  if(old!==zone){
    for(let i=0;i<next.blocks.length;i++){
      const b=next.blocks[i],original=data.blocks[i];
      if(b.start===original.start&&b.end===original.end){continue;}
      const task=next.tasks.find((t:MobileTask)=>t.id===b.taskId);
      if(task&&task.deadline>0&&b.end>task.deadline){throw new Error('切换后安排超出截止时间，请先调整事项');}
      if(next.blocks.some((other:Block,index:number)=>index!==i&&b.start<other.end&&other.start<b.end&&
        !(original.start<data.blocks[index].end&&data.blocks[index].start<original.end))){throw new Error('切换会造成安排重叠，请先调整事项');}
    }
  }
  next.timeZone=zone;next.zonePolicy=policy;return checkData(next);
}
