import { i18n } from '@kit.LocalizationKit';
import { AppTime } from '../model/AppTime';

export function prepareDeviceTime():void {
  const zone=i18n.getTimeZone().getID();
  const cache:Map<string,i18n.TimeZone>=new Map<string,i18n.TimeZone>();
  AppTime.configure((id:string,time:number)=>{const key=id==='system'?zone:id;let tz=cache.get(key);if(!tz){tz=i18n.getTimeZone(key);cache.set(key,tz);}return tz.getOffset(time);},zone);
}
