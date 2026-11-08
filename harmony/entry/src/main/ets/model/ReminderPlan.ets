import { MobileData, MobileTask, Block, activeTasks } from './MobileModel';
import { AppTime } from './AppTime';
export class ReminderOptions {
  starts:boolean=true;deadlines:boolean=true;leadMinutes:number=0;sound:string='notification';
  quiet:boolean=false;quietStart:number=1320;quietEnd:number=480;
}
export class ReminderItem {taskId:string='';title:string='';at:number=0;kind:string='';}
export function reminderPlan(data:MobileData,now:number=Date.now(),options:ReminderOptions=new ReminderOptions()):ReminderItem[] {
  const result:ReminderItem[]=[];
  for(const t of activeTasks(data).filter((t:MobileTask)=>!t.done)){
    const starts=data.blocks.filter((b:Block)=>b.taskId===t.id&&!b.done&&b.start>now+1000).map((b:Block)=>b.start);
    if(options.starts){for(const at of starts){const item=new ReminderItem();item.taskId=t.id;item.title=t.title;item.at=at-options.leadMinutes*60000;item.kind=options.leadMinutes?`开始前${options.leadMinutes}分钟`:'开始';result.push(item);}}
    if(options.deadlines&&t.deadline>now+1000&&(!options.starts||!starts.includes(t.deadline))){const item=new ReminderItem();item.taskId=t.id;item.title=t.title;item.at=t.deadline-options.leadMinutes*60000;item.kind=options.leadMinutes?`截止前${options.leadMinutes}分钟`:'截止';result.push(item);}
  }
  return result.filter((item:ReminderItem)=>{
    if(item.at<=now+1000){return false;}if(!options.quiet){return true;}
    const d=AppTime.civil(item.at,data.timeZone||AppTime.zone),minute=d.getUTCHours()*60+d.getUTCMinutes();
    const quiet=options.quietStart<options.quietEnd?minute>=options.quietStart&&minute<options.quietEnd:minute>=options.quietStart||minute<options.quietEnd;
    return !quiet;
  }).sort((a:ReminderItem,b:ReminderItem)=>a.at-b.at);
}
