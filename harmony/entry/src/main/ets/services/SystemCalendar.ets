import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { addDays, dayStart } from '../model/MobileModel';
import { CalendarImportRecord, calendarRecord } from '../model/CalendarImport';
export { CalendarImportRecord };
export class SystemCalendar {
  static async openNewEvent(context: common.UIAbilityContext, title: string, start: number,
    end: number): Promise<boolean> {
    if (!title.trim() || !Number.isSafeInteger(start) || !Number.isSafeInteger(end) || end <= start) {
      throw new Error('请先为事项设置有效的时间。');
    }
    const manager = calendarManager.getCalendarManager(context);
    const eventId = await manager.editEvent({
      type: calendarManager.EventType.NORMAL,
      title: title,
      startTime: start,
      endTime: end
    });
    return Number.isSafeInteger(eventId) && eventId > 0;
  }

  static async read(context:common.UIAbilityContext):Promise<CalendarImportRecord[]> {
    const permissions:Permissions[]=['ohos.permission.READ_WHOLE_CALENDAR'];
    const authorization=await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context,permissions);
    if(authorization.authResults.length!==1||authorization.authResults[0]!==0){throw new Error('未获日历读取权限，原日历保持不变');}
    const from=Date.now(),to=addDays(from,30),calendars=await calendarManager.getCalendarManager(context).getAllCalendars(),records:CalendarImportRecord[]=[],seen:Set<string>=new Set<string>();
    for(const calendar of calendars){
      const events=await calendar.queryEventInstances(addDays(dayStart(from),-1),addDays(dayStart(to),1),undefined,['id','title','startTime','endTime','instanceStartTime','instanceEndTime','isAllDay','location','timeZone']);
      for(const event of events){
        const start=event.instanceStartTime===undefined?event.startTime:event.instanceStartTime,end=event.instanceEndTime===undefined?event.endTime:event.instanceEndTime;
        if(event.id===undefined){continue;}
        const record=calendarRecord(event.id,event.title||'未命名日程',start,end,event.isAllDay===true,event.location?.location||'');
        if(record.end<=from||record.start>=to||seen.has(record.id)){continue;}seen.add(record.id);records.push(record);
        if(records.length>2000){throw new Error('未来30天日程超过2000项，请在系统日历整理后重试；未导入任何事项');}
      }
    }
    return records.sort((a:CalendarImportRecord,b:CalendarImportRecord)=>a.start-b.start||a.id.localeCompare(b.id));
  }
}
