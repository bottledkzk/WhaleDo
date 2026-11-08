export const zoneIds:string[]=['Asia/Shanghai','UTC','Asia/Tokyo','Asia/Kolkata','Asia/Dubai','Europe/London','Europe/Paris','America/New_York','America/Los_Angeles','Australia/Sydney','Pacific/Auckland'];
export const zoneLabels:string[]=['北京 / 上海','协调世界时 UTC','东京','新德里','迪拜','伦敦','巴黎','纽约','洛杉矶','悉尼','奥克兰'];

export class AppTime {
  static systemZone:string='system';
  static zone:string='system';
  private static resolve:(zone:string,time:number)=>number=(zone:string,time:number)=>{
    if(zone==='UTC'){return 0;}if(zone==='system'){return -new Date(time).getTimezoneOffset()*60000;}
    throw new Error('时区尚未初始化');
  };
  static configure(resolve:(zone:string,time:number)=>number,systemZone:string):void {AppTime.resolve=resolve;AppTime.systemZone=systemZone;}
  static offset(time:number,zone:string=AppTime.zone):number {return AppTime.resolve(zone,time);}
  static civil(time:number,zone:string=AppTime.zone):Date {return new Date(time+AppTime.offset(time,zone));}
  static fromCivil(stamp:number,zone:string=AppTime.zone):number {
    const offsets:number[]=[];
    for(const delta of [-172800000,-86400000,0,86400000,172800000]){
      const offset=AppTime.offset(stamp+delta,zone);if(!offsets.includes(offset)){offsets.push(offset);}
    }
    const matches=offsets.map((offset:number)=>stamp-offset).filter((at:number)=>at+AppTime.offset(at,zone)===stamp);
    if(matches.length!==1){throw new Error('目标时区的这个时间不存在或重复，请选择其它时间');}
    return matches[0];
  }
  static view(time:number,zone:string=AppTime.zone):Date {
    const c=AppTime.civil(time,zone);return new Date(c.getUTCFullYear(),c.getUTCMonth(),c.getUTCDate(),c.getUTCHours(),c.getUTCMinutes(),c.getUTCSeconds(),c.getUTCMilliseconds());
  }
  static fromView(date:Date,zone:string=AppTime.zone):number {return AppTime.fromCivil(Date.UTC(date.getFullYear(),date.getMonth(),date.getDate(),date.getHours(),date.getMinutes(),date.getSeconds(),date.getMilliseconds()),zone);}
  static dayStart(time:number,zone:string=AppTime.zone):number {const c=AppTime.civil(time,zone);return AppTime.fromCivil(Date.UTC(c.getUTCFullYear(),c.getUTCMonth(),c.getUTCDate()),zone);}
  static addDays(time:number,count:number,zone:string=AppTime.zone):number {const c=AppTime.civil(time,zone);c.setUTCDate(c.getUTCDate()+count);return AppTime.fromCivil(c.getTime(),zone);}
  static atMinute(day:number,minute:number,zone:string=AppTime.zone):number {const c=AppTime.civil(day,zone);return AppTime.fromCivil(Date.UTC(c.getUTCFullYear(),c.getUTCMonth(),c.getUTCDate(),Math.floor(minute/60),minute%60),zone);}
  static weekday(time:number,zone:string=AppTime.zone):number {return AppTime.civil(time,zone).getUTCDay();}
  static dateKey(time:number,zone:string=AppTime.zone):string {const c=AppTime.civil(time,zone);return `${c.getUTCFullYear()}-${String(c.getUTCMonth()+1).padStart(2,'0')}-${String(c.getUTCDate()).padStart(2,'0')}`;}
  static clock(time:number,zone:string=AppTime.zone):string {const c=AppTime.civil(time,zone);return `${String(c.getUTCHours()).padStart(2,'0')}:${String(c.getUTCMinutes()).padStart(2,'0')}`;}
  static move(time:number,from:string,to:string):number {return AppTime.fromCivil(AppTime.civil(time,from).getTime(),to);}
}
