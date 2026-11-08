import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { FeedDraft } from './CourseCloud';
import { util } from '@kit.ArkTS';

/** Save the exact public payload before network access so unknown results reuse its ID. */
export class FeedPending {
  private path:string='';
  init(context:common.UIAbilityContext,owner:string):FeedDraft|undefined {
    if(!/^[a-f0-9-]{36}$/.test(owner)){this.path='';return undefined;}
    this.path=`${context.getApplicationContext().filesDir}/whaledo-feed-pending-${owner}.json`;
    if(!fs.accessSync(this.path)){return undefined;}
    if(fs.statSync(this.path).size>16*1024){throw new Error('分享草稿无法读取，原文件保留');}
    const value=JSON.parse(fs.readTextSync(this.path)) as FeedDraft;
    if(!value.requestId||!value.card||typeof value.author!=='string'||typeof value.caption!=='string'){throw new Error('分享草稿无法读取，原文件保留');}
    return value;
  }
  save(value:FeedDraft):void {
    if(!this.path){throw new Error('请先登录账户');}
    const file=fs.openSync(this.path+'.next',fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
    const bytes=new util.TextEncoder().encodeInto(JSON.stringify(value));
    try{let offset=0;while(offset<bytes.length){const count=fs.writeSync(file.fd,(bytes.buffer as ArrayBuffer).slice(offset));if(count<=0){throw new Error('分享草稿保存中断，请重试');}offset+=count;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}
    fs.renameSync(this.path+'.next',this.path);
  }
  clear():void {if(this.path&&fs.accessSync(this.path)){fs.unlinkSync(this.path);}}
}
