import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { picker } from '@kit.CoreFileKit';
import { wavPcm } from '../model/AudioWav';

export async function recognizeSelectedPhoto(): Promise<string | undefined> {
  const options = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = 1;
  const selected = await new photoAccessHelper.PhotoViewPicker().select(options);
  if (selected.photoUris.length === 0) {
    return undefined;
  }
  const file = await fileIo.open(selected.photoUris[0], fileIo.OpenMode.READ_ONLY);
  let source: image.ImageSource | undefined;
  let pixels: image.PixelMap | undefined;
  try {
    source = image.createImageSource(file.fd);
    const dimensions = (await source.getImageInfo()).size;
    if (dimensions.width <= 0 || dimensions.height <= 0) {
      throw new Error('图片尺寸无效');
    }
    const scale = Math.min(1, 2600 / Math.max(dimensions.width, dimensions.height));
    pixels = await source.createPixelMap({
      desiredSize: {
        width: Math.max(1, Math.round(dimensions.width * scale)),
        height: Math.max(1, Math.round(dimensions.height * scale))
      }
    });
    const result = await textRecognition.recognizeText({ pixelMap: pixels }, { isDirectionDetectionSupported: false });
    return result.value.trim();
  } finally {
    try { await pixels?.release(); } catch {}
    try { await source?.release(); } catch {}
    await fileIo.close(file);
  }
}

export async function requestTaskMicrophone(context: common.UIAbilityContext): Promise<boolean> {
  const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];
  const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, permissions);
  return result.authResults[0] === 0;
}

export async function selectAudioPcm():Promise<Uint8Array|undefined> {
  const options=new picker.DocumentSelectOptions();options.maxSelectNumber=1;options.fileSuffixFilters=['WAV音频|.wav'];
  const uris=await new picker.DocumentViewPicker().select(options);if(!uris.length){return undefined;}
  const file=await fileIo.open(uris[0],fileIo.OpenMode.READ_ONLY);
  try{const size=(await fileIo.stat(file.fd)).size;if(size<44||size>2*1024*1024){throw new Error('请选择60秒以内的 WAV 音频');}const buffer=new ArrayBuffer(size);const read=await fileIo.read(file.fd,buffer);if(read!==size){throw new Error('音频读取未完成，请重试');}return wavPcm(new Uint8Array(buffer));}finally{await fileIo.close(file);}
}

export class TaskVoiceCapture {
  private readonly sessionId:string='voice_'+String(Date.now());
  private engine:speechRecognizer.SpeechRecognitionEngine|undefined;
  private closed:boolean=false;
  private finishing:boolean=false;
  private timer:number=-1;
  private writer:number=-1;
  private transcript:string='';
  private pcm:Uint8Array|undefined;
  private position:number=0;
  private onComplete:(text:string,error:string)=>void;
  private onListening:()=>void;
  private onProgress:(text:string)=>void;
  constructor(onListening:()=>void,onComplete:(text:string,error:string)=>void,onProgress:(text:string)=>void=()=>{}){this.onListening=onListening;this.onComplete=onComplete;this.onProgress=onProgress;}
  async start():Promise<void>{await this.begin();}
  async startPcm(pcm:Uint8Array):Promise<void>{if(!pcm.length||pcm.length%2||pcm.length>1920000){this.complete('音频格式或时长不支持');return;}this.pcm=pcm;await this.begin();}
  private async begin():Promise<void>{
    try{
      const engine=await speechRecognizer.createEngine({language:'zh-CN',online:1});if(this.closed){engine.shutdown();return;}this.engine=engine;
      engine.setListener({onStart:(id:string)=>{if(id===this.sessionId&&!this.closed){clearTimeout(this.timer);this.timer=setTimeout(()=>this.finish(),60000);this.onListening();if(this.pcm){this.writeFrame();if(!this.closed&&!this.finishing){this.writer=setInterval(()=>this.writeFrame(),20);}}}},onEvent:()=>{},onResult:(id:string,result:speechRecognizer.SpeechRecognitionResult)=>{if(!this.closed&&id===this.sessionId&&result.result.trim()){if(result.isFinal){this.transcript+=result.result.trim();this.onProgress(this.transcript);}else{this.onProgress(this.transcript+result.result.trim());}}},onComplete:(id:string)=>{if(id===this.sessionId){this.complete('');}},onError:(id:string)=>{if(id===this.sessionId){this.complete('语音识别未完成，请重试或手动输入。');}}});
      this.timer=setTimeout(()=>this.complete('语音识别未能启动，请重试。'),10000);
      const extras:Record<string,Object>={'recognitionMode':this.pcm?1:0,'maxAudioDuration':60000,'vadEnd':1500};
      engine.startListening({sessionId:this.sessionId,audioInfo:{audioType:'pcm',sampleRate:16000,soundChannel:1,sampleBit:16},extraParams:extras});
    }catch{this.complete('当前设备暂时无法识别语音，可手动输入。');}
  }
  private writeFrame():void {
    if(this.closed||this.finishing||!this.engine||!this.pcm){return;}
    if(this.position>=this.pcm.length){this.finish();return;}
    try{const frame=new Uint8Array(640);frame.set(this.pcm.subarray(this.position,Math.min(this.position+640,this.pcm.length)));this.engine.writeAudio(this.sessionId,frame);this.position+=640;}catch{this.complete('音频转写未完成，请重试。');}
  }
  finish():void {if(this.closed||this.finishing||!this.engine){return;}this.finishing=true;clearInterval(this.writer);clearTimeout(this.timer);this.timer=setTimeout(()=>this.complete('语音识别超时，请重试。'),8000);try{this.engine.finish(this.sessionId);}catch{this.complete('语音识别未完成，请重试。');}}
  private complete(error:string):void {if(this.closed){return;}this.close();this.onComplete(error?'':this.transcript,error);}
  close():void {if(this.closed){return;}this.closed=true;clearTimeout(this.timer);clearInterval(this.writer);this.pcm=undefined;const engine=this.engine;this.engine=undefined;try{engine?.cancel(this.sessionId);}catch{}try{engine?.shutdown();}catch{}}
}
