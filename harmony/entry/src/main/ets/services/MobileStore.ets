import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { MobileData, checkData } from '../model/MobileModel';
import { AppTime } from '../model/AppTime';

export class MobileStore {
  private path:string='';
  init(context:common.Context,owner:string='guest'):MobileData {
    if(owner!=='guest'&&!/^[a-f0-9-]{36}$/.test(owner)){throw new Error('账户标识无效');}
    this.path=`${context.getApplicationContext().filesDir}/${owner==='guest'?'whaletodo-mobile':`whaletodo-mobile-${owner}`}.json`;
    if(!fs.accessSync(this.path)){const empty=new MobileData();empty.timeZone=AppTime.systemZone;AppTime.zone=empty.timeZone;return empty;}
    try{const data=checkData(JSON.parse(fs.readTextSync(this.path)) as MobileData);data.timeZone=data.timeZone||AppTime.systemZone;AppTime.zone=data.timeZone;return data;}catch{throw new Error('无法读取本机记录，原文件已保留；请勿卸载应用');}
  }
  restore(data:MobileData):void {
    checkData(data);if(this.path===''){throw new Error('本机存储尚未就绪');}
    if(fs.accessSync(this.path)){fs.copyFileSync(this.path,`${this.path}.before-restore-${Date.now()}`);}
    this.save(data);
  }
  save(data:MobileData):void {
    data.timeZone=data.timeZone||AppTime.zone;
    for(const task of data.tasks){task.timeZone=task.timeZone||data.timeZone;}
    for(const block of data.blocks){block.timeZone=block.timeZone||data.timeZone;}
    for(const diary of data.diaries){diary.timeZone=diary.timeZone||data.timeZone;}
    if(this.path===''){throw new Error('本机存储尚未就绪');}checkData(data);
    const bytes=new util.TextEncoder().encodeInto(JSON.stringify(data));
    if(bytes.byteLength>32*1024*1024){throw new Error('记录超过本机保存限制');}
    const file=fs.openSync(`${this.path}.tmp`,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
    try{let offset=0;while(offset<bytes.length){const count=fs.writeSync(file.fd,(bytes.buffer as ArrayBuffer).slice(offset));if(count<=0){throw new Error('写入中断');}offset+=count;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}
    fs.renameSync(`${this.path}.tmp`,this.path);
  }
}
