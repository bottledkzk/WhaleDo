import { MobileData, MobileTask, Block, Diary, clone, checkData } from './MobileModel';
export class SyncScope {schedule:boolean=true;diaries:boolean=false;}
export class SyncPlan {candidate:MobileData=new MobileData();skippedBlocks:number=0;addedTasks:number=0;addedDiaries:number=0;}
export function serverSnapshot(data:MobileData):MobileData {
  const next=clone(data);next.workWindows=undefined;next.workDates=undefined;next.tone=undefined;next.corners=undefined;
  next.avatar=undefined;next.nickname=undefined;next.motto=undefined;next.zonePolicy=undefined;return checkData(next);
}
export function checkScope(scope:SyncScope):void {if(typeof scope.schedule!=='boolean'||typeof scope.diaries!=='boolean'||(!scope.schedule&&!scope.diaries)){throw new Error('请至少选择日程或日记');}}
export function buildSyncPlan(local:MobileData,remote:MobileData,kind:string,scope:SyncScope):SyncPlan {
  checkScope(scope);checkData(local);checkData(remote);if(!['push','pull','merge'].includes(kind)){throw new Error('同步方式无效');}
  const plan=new SyncPlan();
  if(kind==='push'){
    const next=clone(remote),source=clone(local);if(scope.schedule){next.tasks=source.tasks;next.blocks=source.blocks;next.workStart=source.workStart;next.workEnd=source.workEnd;next.timeZone=source.timeZone;}if(scope.diaries){next.diaries=source.diaries;}next.theme='light';next.revision=source.revision;plan.candidate=serverSnapshot(next);return plan;
  }
  const next=clone(local),source=clone(remote);next.theme=local.theme;
  if(kind==='pull'){
    if(scope.schedule){next.tasks=source.tasks;next.blocks=source.blocks;next.workStart=source.workStart;next.workEnd=source.workEnd;}if(scope.diaries){next.diaries=source.diaries;}
  }else{
    if(scope.schedule){
      const localIds=next.tasks.map((t:MobileTask)=>t.id),added:string[]=[];
      for(const task of source.tasks){if(localIds.includes(task.id)){continue;}next.tasks.push(task);added.push(task.id);plan.addedTasks++;}
      for(const block of source.blocks.sort((a:Block,b:Block)=>a.start-b.start||a.id.localeCompare(b.id))){
        if(!added.includes(block.taskId)||next.tasks.some((t:MobileTask)=>t.id===block.taskId&&t.deletedAt>0)){continue;}
        if(next.blocks.some((b:Block)=>b.id===block.id||(block.start<b.end&&b.start<block.end))){plan.skippedBlocks++;continue;}next.blocks.push(block);
      }
    }
    if(scope.diaries){for(const diary of source.diaries){if(next.diaries.some((d:Diary)=>d.day===diary.day)){continue;}next.diaries.push(diary);plan.addedDiaries++;}}
  }
  if(next.tasks.length>10000||next.blocks.length>50000||next.diaries.length>10000){throw new Error('合并记录超过当前存储能力，请缩小范围或整理后重试');}
  plan.candidate=checkData(next);return plan;
}
