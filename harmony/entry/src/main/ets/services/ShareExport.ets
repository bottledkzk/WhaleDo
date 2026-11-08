import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { MobileData } from '../model/MobileModel';
import { tasksIcs, taskText } from '../model/SharingModel';
export { tasksIcs, taskText };

export class ShareExport {
  static async imageFile(context:common.UIAbilityContext,pixels:image.PixelMap):Promise<string> {
    const packer=image.createImagePacker();
    try{
      const bytes=await packer.packing(pixels,{format:'image/png',quality:100}),path=`${context.cacheDir}/WhaleDo-card-${Date.now()}.png`;
      const file=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
      try{let offset=0;while(offset<bytes.byteLength){const n=fs.writeSync(file.fd,bytes.slice(offset));if(n<=0){throw new Error('分享图片保存失败');}offset+=n;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}
      return path;
    }finally{await packer.release();}
  }
  static async shareImage(context:common.UIAbilityContext,path:string):Promise<void> {
    const record:systemShare.SharedRecord={utd:utd.UniformDataType.IMAGE,uri:fileUri.getUriFromPath(path),title:'鲸办 WhaleDo · 分享卡片'};
    const controller=new systemShare.ShareController(new systemShare.SharedData(record));
    await controller.show(context,{previewMode:systemShare.SharePreviewMode.DEFAULT,selectionMode:systemShare.SelectionMode.SINGLE});
  }
  static async saveImage(context:common.UIAbilityContext,path:string):Promise<boolean> {
    const helper=photoAccessHelper.getPhotoAccessHelper(context),source=fileUri.getUriFromPath(path);
    try{
      const selected=await helper.showAssetsCreationDialog([source],[{title:'WhaleDo-'+Date.now(),fileNameExtension:'png',photoType:photoAccessHelper.PhotoType.IMAGE}]);
      if(!selected.length){return false;}
      const input=await fs.open(source,fs.OpenMode.READ_ONLY);
      try{const output=await fs.open(selected[0],fs.OpenMode.WRITE_ONLY);try{await fs.copyFile(input.fd,output.fd);}finally{await fs.close(output);}}finally{await fs.close(input);}
      return true;
    }finally{await helper.release();}
  }
  static async share(context:common.UIAbilityContext,data:MobileData,calendar:boolean,taskId:string=''):Promise<void> {
    let record:systemShare.SharedRecord={utd:utd.UniformDataType.PLAIN_TEXT,content:taskText(data,taskId),title:'鲸办 WhaleDo 清单'};
    if(calendar){const path=`${context.cacheDir}/WhaleDo-${Date.now()}.ics`,bytes=new util.TextEncoder().encodeInto(tasksIcs(data,taskId));const file=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);try{let offset=0;while(offset<bytes.length){const count=fs.writeSync(file.fd,(bytes.buffer as ArrayBuffer).slice(offset));if(count<=0){throw new Error('导出未完成');}offset+=count;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}record={utd:utd.UniformDataType.CALENDAR,uri:fileUri.getUriFromPath(path),title:'鲸办 WhaleDo 日历'};}
    const controller=new systemShare.ShareController(new systemShare.SharedData(record));await controller.show(context,{previewMode:systemShare.SharePreviewMode.DEFAULT,selectionMode:systemShare.SelectionMode.SINGLE});
  }
}
