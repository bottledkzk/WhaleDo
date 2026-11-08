import { MobileData, MobileTask, Block, activeTasks, localText } from './MobileModel';

function escapeIcs(value:string):string {return value.replace(/\\/g,'\\\\').replace(/\r\n|\r|\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');}
function utc(value:number):string {return new Date(value).toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z$/,'Z');}
class AllDayDates {start:string='';last:string='';end:string='';}
function validDate(value:string):boolean {
  const time=Date.parse(`${value}T00:00:00Z`);
  return Number.isFinite(time)&&value.slice(0,4)!=='0000'&&new Date(time).toISOString().slice(0,10)===value;
}
function allDayDates(task:MobileTask):AllDayDates|undefined {
  if(!task.id.startsWith('calendar-event-')||task.category!=='日历'){return undefined;}
  const match=/^全天日程：(\d{4}-\d{2}-\d{2})(?: — (\d{4}-\d{2}-\d{2}))?(?:\n|$)/.exec(task.note);
  if(!match){return undefined;}
  const first=match[1],last=match[2]||first;
  if(!validDate(first)||!validDate(last)||last<first||last==='9999-12-31'){return undefined;}
  // The import note retains the original date-only span. Re-deriving dates from
  // block instants after a device timezone change would shift an all-day event.
  const dates=new AllDayDates();dates.start=first.replace(/-/g,'');dates.last=last.replace(/-/g,'');
  dates.end=new Date(Date.parse(`${last}T00:00:00Z`)+86400000).toISOString().slice(0,10).replace(/-/g,'');
  return dates;
}
export function foldIcs(value:string):string {
  let result='',line='',bytes=0;
  for(let i=0;i<value.length;i++){let c=value.charAt(i),code=value.charCodeAt(i),size=code<128?1:code<2048?2:3;if(code>=0xD800&&code<=0xDBFF&&i+1<value.length){c+=value.charAt(++i);size=4;}if(bytes+size>75){result+=`${line}\r\n`;line=' ';bytes=1;}line+=c;bytes+=size;}
  return result+line;
}
export function tasksIcs(data:MobileData,taskId:string='',now:number=Date.now()):string {
  const tasks=activeTasks(data).filter((t:MobileTask)=>!taskId||t.id===taskId);if(tasks.length===0){throw new Error('没有可导出的事项');}
  const lines:string[]=['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//WhaleDo//Harmony Course//ZH','CALSCALE:GREGORIAN'];
  for(const task of tasks){const blocks=data.blocks.filter((b:Block)=>b.taskId===task.id),dates=allDayDates(task);
    if(blocks.length>0){for(const b of blocks){
      const allDay=dates!==undefined&&b.id===`calendar-block-${task.id.slice('calendar-'.length)}`;
      lines.push('BEGIN:VEVENT',`UID:${encodeURIComponent(b.id)}@whaletodo.mobile`,`DTSTAMP:${utc(now)}`);
      if(allDay&&dates){lines.push(`DTSTART;VALUE=DATE:${dates.start}`,`DTEND;VALUE=DATE:${dates.end}`);}
      else{lines.push(`DTSTART:${utc(b.start)}`,`DTEND:${utc(b.end)}`);}
      lines.push(`SUMMARY:${escapeIcs(task.title)}`,`DESCRIPTION:${escapeIcs(task.note)}`,'END:VEVENT');
    }}
    else{lines.push('BEGIN:VTODO',`UID:${encodeURIComponent(task.id)}@whaletodo.mobile`,`DTSTAMP:${utc(now)}`,`SUMMARY:${escapeIcs(task.title)}`,`DESCRIPTION:${escapeIcs(task.note)}`,`STATUS:${task.done?'COMPLETED':'NEEDS-ACTION'}`,`PRIORITY:${Math.max(1,10-Math.round(task.priority)*2)}`);if(task.deadline>0){lines.push(dates?`DUE;VALUE=DATE:${dates.last}`:`DUE:${utc(task.deadline)}`);}if(task.done&&task.completedAt>0){lines.push(`COMPLETED:${utc(task.completedAt)}`);}lines.push('END:VTODO');}
  }
  lines.push('END:VCALENDAR');return lines.map((line:string)=>foldIcs(line)).join('\r\n')+'\r\n';
}
export function taskText(data:MobileData,taskId:string=''):string {
  const tasks=activeTasks(data).filter((t:MobileTask)=>!taskId||t.id===taskId);if(tasks.length===0){throw new Error('没有可分享的事项');}
  return '鲸办 WhaleDo · 我的清单\n\n'+tasks.map((t:MobileTask)=>{
    const dates=allDayDates(t),blocks=data.blocks.filter((b:Block)=>b.taskId===t.id);
    const allDay=dates!==undefined&&(blocks.length===0||blocks.every((b:Block)=>b.id===`calendar-block-${t.id.slice('calendar-'.length)}`));
    return `${t.done?'✓':'□'} ${t.title}${!allDay&&t.deadline?'\n截止 '+localText(t.deadline):''}${!allDay&&t.minutes?' · 预计 '+t.minutes+' 分钟':''}${t.note?'\n'+t.note:''}`;
  }).join('\n\n');
}
