import {MobileError} from './snapshot.ts';
import type {AiInput} from './ai-types.ts';
const bad=():never=>{throw new MobileError(502,'AI_INVALID_TIME','建议时间不明确或遇到夏令时切换，请重新说明日期和时刻；本机记录未改动');};
const formatters=new Map<string,Intl.DateTimeFormat>();
function wall(instant:number,zone:string):number {
  let fmt=formatters.get(zone);if(!fmt){fmt=new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'});formatters.set(zone,fmt);}
  const p=Object.fromEntries(fmt.formatToParts(instant).map(part=>[part.type,part.value]));
  return Date.UTC(Number(p.year),Number(p.month)-1,Number(p.day),Number(p.hour),Number(p.minute),Number(p.second));
}
export function localIso(instant:number,input:AiInput):string {
  const zone=input.context?.timeZone;
  const value=typeof zone==='string'?wall(instant,zone):instant-(input.timezoneOffsetMinutes??0)*60000;
  return new Date(value).toISOString().slice(0,19);
}
/** Models write civil clock strings; deterministic code handles UTC and DST. */
export function modelTime(raw:unknown,input?:AiInput,allowZero=true):number {
  if(raw===0&&allowZero)return 0;
  if(typeof raw==='number'){if(input)return bad();return Number.isSafeInteger(raw)&&raw>=0&&raw<=8640000000000000?raw:bad();}
  if(typeof raw!=='string')return bad();
  const match=/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::(\d{2}))?(Z|[+-]\d{2}:\d{2})?$/.exec(raw);if(!match)return bad();
  const civil=match[1]+'T'+match[2]+':'+(match[3]??'00'),naive=Date.parse(civil+'Z');
  if(!Number.isFinite(naive)||new Date(naive).toISOString().slice(0,19)!==civil)return bad();
  if(match[4]){const instant=Date.parse(civil+match[4]);if(!Number.isFinite(instant))return bad();if(input&&localIso(instant,input)!==civil)return bad();return instant;}
  if(!input)return bad();
  const zone=input.context?.timeZone;
  if(typeof zone!=='string'){if(input.timezoneOffsetMinutes===undefined)return bad();return naive+input.timezoneOffsetMinutes*60000;}
  const offsets=new Set<number>();for(const delta of [-2,-1,0,1,2]){const t=naive+delta*86400000;offsets.add(wall(t,zone)-t);}
  const candidates=[...offsets].map(offset=>naive-offset).filter(instant=>wall(instant,zone)===naive);
  if(candidates.length!==1)return bad();return candidates[0]!;
}
