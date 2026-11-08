import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AvatarPhoto } from './AvatarPhoto';

export async function assistantImage(context:common.UIAbilityContext,owner:string,takePhoto:boolean):Promise<string> {
  const name=await AvatarPhoto.select(context,owner,takePhoto,1600);if(!name){return '';}
  try{
    const path=`${context.getApplicationContext().filesDir}/${name}`,size=fs.statSync(path).size;
    if(size<=0||size>2*1024*1024){throw new Error('图片较大，请换一张图片');}
    const file=fs.openSync(path,fs.OpenMode.READ_ONLY),bytes=new Uint8Array(size);
    try{let offset=0;while(offset<size){const chunk=new Uint8Array(size-offset),count=fs.readSync(file.fd,chunk.buffer as ArrayBuffer);if(count<=0){throw new Error('图片读取中断');}bytes.set(chunk.subarray(0,count),offset);offset+=count;}}
    finally{fs.closeSync(file);}
    return 'data:image/jpeg;base64,'+new util.Base64Helper().encodeToStringSync(bytes);
  }finally{AvatarPhoto.remove(context,name);}
}
