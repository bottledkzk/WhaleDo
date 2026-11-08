import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager as agent } from '@kit.BackgroundTasksKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { MobileData, clone, clock } from '../model/MobileModel';
import { reminderPlan, ReminderOptions } from '../model/ReminderPlan';
class ReminderFailure {code:number=0;}
class ReminderSettings {enabled:boolean=false;options?:ReminderOptions;}

export class MobileReminders {
  private static enabled:boolean=false;
  private static path:string='';
  private static generation:number=0;
  private static chain:Promise<void>=Promise.resolve();
  private static preferences:ReminderOptions=new ReminderOptions();
  static options():ReminderOptions {return JSON.parse(JSON.stringify(MobileReminders.preferences)) as ReminderOptions;}
  static validate(options:ReminderOptions):void {
    if(typeof options.starts!=='boolean'||typeof options.deadlines!=='boolean'||(!options.starts&&!options.deadlines)||
      !Number.isInteger(options.leadMinutes)||options.leadMinutes<0||options.leadMinutes>1440||!['silent','notification','alarm'].includes(options.sound)||
      typeof options.quiet!=='boolean'||!Number.isInteger(options.quietStart)||!Number.isInteger(options.quietEnd)||options.quietStart<0||options.quietStart>1439||options.quietEnd<0||options.quietEnd>1439||options.quietStart===options.quietEnd){throw new Error('请检查提醒设置');}
  }
  static async configure(context:common.UIAbilityContext,data:MobileData,options:ReminderOptions):Promise<string> {
    MobileReminders.validate(options);const previous=MobileReminders.options(),epoch=++MobileReminders.generation;
    MobileReminders.preferences=JSON.parse(JSON.stringify(options)) as ReminderOptions;
    try{const message=MobileReminders.enabled?await MobileReminders.refresh(context,data):'提醒偏好已保存';if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}MobileReminders.persist();return message;}
    catch(error){if(epoch===MobileReminders.generation){MobileReminders.preferences=previous;MobileReminders.persist();}throw error as Error;}
  }
  static async init(context:common.UIAbilityContext,owner:string='guest'):Promise<boolean> {
    if(owner!=='guest'&&!/^[a-f0-9-]{36}$/.test(owner)){throw new Error('账户标识无效');}
    MobileReminders.generation++;const epoch=MobileReminders.generation;MobileReminders.path=`${context.filesDir}/whaletodo-reminders-${owner}.json`;MobileReminders.enabled=false;MobileReminders.preferences=new ReminderOptions();
    const pending=MobileReminders.chain.then(async()=>{let cancellationFailed=false;try{await agent.cancelAllReminders();}catch{cancellationFailed=true;}if(epoch!==MobileReminders.generation){return;}if(fs.accessSync(MobileReminders.path)){try{const saved=JSON.parse(fs.readTextSync(MobileReminders.path)) as ReminderSettings;if(saved.options){MobileReminders.validate(saved.options);MobileReminders.preferences=saved.options;}MobileReminders.enabled=saved.enabled===true;}catch{}}if(cancellationFailed&&MobileReminders.enabled){MobileReminders.enabled=false;throw new Error('系统提醒状态未能恢复');}});MobileReminders.chain=pending.then(()=>{},()=>{});
    try{await pending;}catch{if(epoch===MobileReminders.generation){MobileReminders.enabled=false;}throw new Error('系统提醒状态未能恢复，请重新启用后核验');}if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}return MobileReminders.enabled;
  }
  static isEnabled():boolean {return MobileReminders.enabled;}
  private static persist():void {if(!MobileReminders.path){return;}const file=fs.openSync(`${MobileReminders.path}.tmp`,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{const text=JSON.stringify({enabled:MobileReminders.enabled,options:MobileReminders.preferences});let offset=0;while(offset<text.length){const count=fs.writeSync(file.fd,text.slice(offset));if(count<=0){throw new Error('提醒设置保存中断');}offset+=count;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}fs.renameSync(`${MobileReminders.path}.tmp`,MobileReminders.path);}
  private static failure(error:ReminderFailure):Error {return new Error(error.code===1700002?'当前设备未开放后台提醒，可添加到系统日历使用日历提醒':error.code===1700001?'系统通知未授权，请在设置中允许通知':'系统提醒登记失败，尚未确认后台到达');}
  static async enable(context:common.UIAbilityContext,data:MobileData):Promise<string> {
    const epoch=MobileReminders.generation;
    if(!await notificationManager.isNotificationEnabled()){await notificationManager.requestEnableNotification(context);}
    if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化，请重新启用');}
    if(!await notificationManager.isNotificationEnabled()){throw new Error('系统通知未授权，未启用提醒');}
    if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化，请重新启用');}
    MobileReminders.enabled=true;
    try{const value=await MobileReminders.refresh(context,data);if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}MobileReminders.persist();return value;}catch(error){if(epoch===MobileReminders.generation){MobileReminders.enabled=false;MobileReminders.persist();}throw error as Error;}
  }
  static async refresh(context:common.UIAbilityContext,data:MobileData):Promise<string> {
    if(!MobileReminders.enabled){return '系统提醒已关闭';}const snapshot=clone(data),epoch=MobileReminders.generation;
    const pending=MobileReminders.chain.then(()=>MobileReminders.perform(context,snapshot,epoch));MobileReminders.chain=pending.then(()=>{},()=>{});return pending;
  }
  private static async perform(context:common.UIAbilityContext,data:MobileData,epoch:number):Promise<string> {
    if(!MobileReminders.enabled||epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}
    if(!await notificationManager.isNotificationEnabled()){throw new Error('系统通知未授权，请在设置中允许通知');}
    if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}
    await agent.cancelAllReminders();const options=MobileReminders.options(),items=reminderPlan(data,Date.now(),options);let count=0;
    try{for(const item of items.slice(0,20)){
      if(!MobileReminders.enabled||epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}
      const d=new Date(item.at),request:agent.ReminderRequestCalendar={reminderType:agent.ReminderType.REMINDER_TYPE_CALENDAR,dateTime:{year:d.getFullYear(),month:d.getMonth()+1,day:d.getDate(),hour:d.getHours(),minute:d.getMinutes(),second:d.getSeconds()},title:'鲸办 WhaleDo',content:`${clock(item.at)} ${item.kind} · ${item.title}`,expiredContent:'提醒时间已到，打开查看最新事项',notificationId:2000+count,groupId:'whaletodo-mobile',ringDuration:options.sound==='silent'?0:options.sound==='alarm'?10:1,ringChannel:options.sound==='alarm'?agent.RingChannel.RING_CHANNEL_ALARM:agent.RingChannel.RING_CHANNEL_NOTIFICATION,snoozeTimes:0,tapDismissed:true,wantAgent:{pkgName:context.applicationInfo.name,abilityName:'EntryAbility'}};
      await agent.publishReminder(request);count++;
    }if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}}
    catch(error){await agent.cancelAllReminders();if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}MobileReminders.enabled=false;MobileReminders.persist();throw MobileReminders.failure(error as ReminderFailure);}
    return `系统已登记 ${count} 个提醒${items.length>20?'，最近20个优先，打开应用时续排':''}`;
  }
  static async disable():Promise<void> {MobileReminders.generation++;MobileReminders.enabled=false;let saved=true;try{MobileReminders.persist();}catch{saved=false;}const pending=MobileReminders.chain.then(()=>agent.cancelAllReminders());MobileReminders.chain=pending.then(()=>{},()=>{});await pending;if(!saved){throw new Error('已取消当前提醒，但关闭设置未保存，请检查空间后重试');}}
  static async testNotification(context:common.UIAbilityContext):Promise<string> {
    const epoch=MobileReminders.generation;
    if(!await notificationManager.isNotificationEnabled()){await notificationManager.requestEnableNotification(context);}
    if(epoch!==MobileReminders.generation){throw new Error('账户已变化');}
    if(!await notificationManager.isNotificationEnabled()){throw new Error('请先允许通知');}
    await notificationManager.publish({id:2998,content:{contentType:0,normal:{title:'鲸办 WhaleDo',text:'这是一条通知测试',additionalText:'事项提醒'}}});
    return '已提交通知测试，请检查通知中心';
  }
  static async test(context:common.UIAbilityContext):Promise<string> {
    const epoch=MobileReminders.generation;
    if(!await notificationManager.isNotificationEnabled()){await notificationManager.requestEnableNotification(context);}
    if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}
    const pending=MobileReminders.chain.then(()=>MobileReminders.performTest(context,epoch));MobileReminders.chain=pending.then(()=>{},()=>{});return pending;
  }
  private static async performTest(context:common.UIAbilityContext,epoch:number):Promise<string> {
    if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}
    try{await agent.publishReminder({reminderType:agent.ReminderType.REMINDER_TYPE_TIMER,triggerTimeInSeconds:12,title:'WhaleDo · 提醒测试',content:'这是一条系统提醒',notificationId:2999,ringDuration:0,ringChannel:agent.RingChannel.RING_CHANNEL_NOTIFICATION,wantAgent:{pkgName:context.applicationInfo.name,abilityName:'EntryAbility'}} as agent.ReminderRequestTimer);if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}return '系统已接受测试提醒，可退出应用等待12秒核验';}catch(error){if(epoch!==MobileReminders.generation){throw new Error('账户或设置已变化');}throw MobileReminders.failure(error as ReminderFailure);}
  }
}
