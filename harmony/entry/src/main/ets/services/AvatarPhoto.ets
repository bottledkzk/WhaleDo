import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

export class AvatarPhoto {
  static uri(context:common.Context,name:string):string {
    return fileUri.getUriFromPath(`${context.getApplicationContext().filesDir}/${name}`);
  }
  static remove(context:common.Context,name:string):void {
    if(!/^whaletodo-avatar-(guest|[a-f0-9-]{36})-\d+\.jpg$/.test(name)){return;}
    try{fs.unlinkSync(`${context.getApplicationContext().filesDir}/${name}`);}catch{}
  }
  static async select(context:common.UIAbilityContext,owner:string,takePhoto:boolean,maxDimension:number=512):Promise<string> {
    if(owner!=='guest'&&!/^[a-f0-9-]{36}$/.test(owner)){throw new Error('账户标识无效');}
    let uri='';
    if(takePhoto){
      const result=await cameraPicker.pick(context,[cameraPicker.PickerMediaType.PHOTO],{
        cameraPosition:maxDimension>512?camera.CameraPosition.CAMERA_POSITION_BACK:camera.CameraPosition.CAMERA_POSITION_FRONT
      });
      if(result.resultCode!==0){return '';}
      uri=result.resultUri;
    }else{
      const options=new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType=photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;options.maxSelectNumber=1;
      const selected=await new photoAccessHelper.PhotoViewPicker().select(options);
      uri=selected.photoUris[0]||'';
    }
    if(!uri){return '';}
    const file=await fs.open(uri,fs.OpenMode.READ_ONLY);
    let source:image.ImageSource|undefined;
    let pixels:image.PixelMap|undefined;
    let packer:image.ImagePacker|undefined;
    try{
      source=image.createImageSource(file.fd);
      const size=(await source.getImageInfo()).size;
      if(size.width<=0||size.height<=0){throw new Error('图片无效');}
      const scale=Math.min(1,maxDimension/Math.max(size.width,size.height));
      pixels=await source.createPixelMap({desiredSize:{width:Math.max(1,Math.round(size.width*scale)),height:Math.max(1,Math.round(size.height*scale))}});
      packer=image.createImagePacker();
      const bytes=await packer.packing(pixels,{format:'image/jpeg',quality:maxDimension>512?85:90});
      const name=`whaletodo-avatar-${owner}-${Date.now()}.jpg`;
      const path=`${context.getApplicationContext().filesDir}/${name}`;
      const output=fs.openSync(path,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
      try{
        let offset=0;
        while(offset<bytes.byteLength){const count=fs.writeSync(output.fd,bytes.slice(offset));if(count<=0){throw new Error('图片保存失败');}offset+=count;}
        fs.fsyncSync(output.fd);
      }catch{try{fs.unlinkSync(path);}catch{}throw new Error('图片保存失败');}
      finally{fs.closeSync(output);}
      return name;
    }finally{
      try{await packer?.release();}catch{}
      try{await pixels?.release();}catch{}
      try{await source?.release();}catch{}
      await fs.close(file);
    }
  }
}
