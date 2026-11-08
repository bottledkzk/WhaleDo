import { common } from '@kit.AbilityKit';
import { recognizeSelectedPhoto, requestTaskMicrophone, TaskVoiceCapture, selectAudioPcm } from '../services/TaskCapture';
import { themeColors } from '../model/AppTheme';

@CustomDialog
struct AssistantCapturePreview {
  controller?:CustomDialogController;
  @Link preview:string;
  @Link status:string;
  @Link mode:string;
  @Link listening:boolean;
  @Prop dark:boolean=false;
  @Prop tone:string='whale';
  @Prop corners:string='round';
  onFinish:()=>void=()=>{};
  onCancel:()=>void=()=>{};
  onApply:()=>void=()=>{};
  build(){
    Column({space:16}){
      Text(this.mode==='voice'?'语音输入':this.mode==='audio'?'音频转写':'识别内容').fontSize(20).fontWeight(FontWeight.Medium).fontColor(themeColors(this.dark,this.tone).ink).width('100%')
      if(this.status){Text(this.status).fontSize(13).lineHeight(21).fontColor(themeColors(this.dark,this.tone).muted).width('100%')}
      if(this.preview){TextArea({text:this.preview,placeholder:'识别内容'}).fontSize(15).height(120).maxLength(2120).enabled(!this.mode).fontColor(themeColors(this.dark,this.tone).ink).backgroundColor(themeColors(this.dark,this.tone).paper).borderRadius(this.corners==='square'?0:12).onChange((value:string)=>this.preview=value).id('assistant-capture-preview')}
      Row({space:10}){
        Button('取消').type(ButtonType.Normal).layoutWeight(1).height(44).fontColor(themeColors(this.dark,this.tone).accent).backgroundColor(themeColors(this.dark,this.tone).tint).borderRadius(this.corners==='square'?0:12).onClick(()=>this.onCancel()).id('assistant-capture-cancel')
        if(this.mode==='voice'&&this.listening){Button('结束听写').type(ButtonType.Normal).layoutWeight(1).height(44).fontColor(themeColors(this.dark,this.tone).onPrimary).backgroundColor(themeColors(this.dark,this.tone).primary).borderRadius(this.corners==='square'?0:12).onClick(()=>this.onFinish()).id('assistant-capture-finish')}
        if(!this.mode&&this.preview.trim()){Button('填入对话').type(ButtonType.Normal).layoutWeight(1).height(44).fontColor(themeColors(this.dark,this.tone).onPrimary).backgroundColor(themeColors(this.dark,this.tone).primary).borderRadius(this.corners==='square'?0:12).onClick(()=>this.onApply()).id('assistant-capture-apply')}
      }.width('100%')
    }.padding(22).width('90%').constraintSize({maxWidth:440}).backgroundColor(themeColors(this.dark,this.tone).surface).borderRadius(this.corners==='square'?0:22)
  }
}

@Component
export struct TaskCaptureInput {
  @Prop dark: boolean = false;
  @Prop applyLabel: string = '填入事项草稿';
  @Prop tone: string = 'whale';
  @Prop corners: string = 'round';
  @Prop assistantMode:boolean=false;
  @Prop blocked:boolean=false;
  @Prop sendEnabled:boolean=true;
  @Prop sendLabel:string='发送';
  @Prop imageLabel:string='添加图片';
  onAddImage:()=>void=()=>{};
  onSend:()=>void=()=>{};
  @StorageLink('appActive') @Watch('foregroundChanged') foreground: boolean = true;
  onApply: (value: string) => void = () => {};
  @State mode: string = '';
  @State listening: boolean = false;
  @State preview: string = '';
  @State status: string = '';
  private voice: TaskVoiceCapture | undefined;
  private epoch: number = 0;
  private previewOpen:boolean=false;
  private openAssistantPreview():void {if(!this.previewOpen){this.previewOpen=true;this.assistantPreview.open();}}
  private closeAssistantPreview():void {this.previewOpen=false;this.assistantPreview.close();}
  private assistantPreview:CustomDialogController=new CustomDialogController({
    builder:AssistantCapturePreview({preview:$preview,status:$status,mode:$mode,listening:$listening,dark:this.dark,tone:this.tone,corners:this.corners,onFinish:()=>this.finishVoice(),onCancel:()=>{this.cancelVoice();this.closeAssistantPreview();},onApply:()=>{this.apply();this.closeAssistantPreview();}}),
    autoCancel:false,cancel:()=>{this.previewOpen=false;this.cancelVoice();},customStyle:true,alignment:DialogAlignment.Center
  });

  aboutToDisappear(): void {
    this.epoch++;
    this.voice?.close();
    this.voice = undefined;
    this.closeAssistantPreview();
  }

  private foregroundChanged(): void {
    if (!this.foreground && this.voice) {
      this.cancelVoice();
      this.status = '应用进入后台，已停止录音。';
    }
  }

  private acceptResult(value: string, empty: string): void {
    this.preview = value.trim().slice(0, 2120).replace(/[\uD800-\uDBFF]$/, '');
    this.status = this.preview
      ? (value.length > 2120 ? '识别文字过长，已截取。' : '')
      : empty;
  }

  private async scan(): Promise<void> {
    if (this.mode) {
      return;
    }
    if (!canIUse('SystemCapability.AI.OCR.TextRecognition')) {
      this.status = '当前设备不支持系统图片识字，可手动输入。';
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    this.mode = 'photo';
    this.status = '';
    const epoch = ++this.epoch;
    try {
      const result = await recognizeSelectedPhoto();
      if (epoch === this.epoch) {
        if (result === undefined) {
          this.status = '已取消选择图片。';
        } else {
          this.acceptResult(result, '图片里没有识别到文字，请换一张清晰的图片。');
        }
      }
    } catch {
      if (epoch === this.epoch) {
        this.status = '图片识字失败，请换一张图片或手动输入。';
      }
    } finally {
      if (epoch === this.epoch) {
        this.mode = '';
      }
    }
  }

  private async speak(): Promise<void> {
    if (this.mode) {
      return;
    }
    if (!canIUse('SystemCapability.AI.SpeechRecognizer')) {
      this.status = '当前设备不支持系统语音识别，可手动输入。';
      if(this.assistantMode){this.openAssistantPreview();}
      return;
    }
    this.getUIContext().getFocusController().clearFocus();
    this.mode = 'voice';
    this.preview='';
    this.status = '正在准备麦克风…';
    const epoch = ++this.epoch;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const granted = await requestTaskMicrophone(context);
      if (epoch !== this.epoch) {
        return;
      }
      if (!granted || !this.foreground) {
        this.mode = '';
        this.status = granted ? '请回到事项页面后再开始录音。' : '未获麦克风权限，可手动输入。';
        if(this.assistantMode){this.openAssistantPreview();}
        return;
      }
      if(this.assistantMode){this.openAssistantPreview();}
      this.voice = new TaskVoiceCapture(() => {
        if (epoch === this.epoch) {
          this.listening = true;
          this.status = '正在听写…';
        }
      }, (text: string, error: string) => {
        if (epoch !== this.epoch) {
          return;
        }
        this.voice = undefined;
        this.mode = '';
        this.listening = false;
        if (error) {
          this.status = error;
        } else {
          this.acceptResult(text, '没有听到可识别的文字，请重试。');
        }
      },(text:string)=>{if(epoch===this.epoch){this.preview=text.slice(0,2120);}});
      await this.voice.start();
    } catch {
      if (epoch === this.epoch) {
        this.cancelVoice();
        this.status = '麦克风暂时不可用，可手动输入。';
      }
    }
  }

  private async audioFile():Promise<void> {
    if(this.mode){return;}this.getUIContext().getFocusController().clearFocus();this.mode='audio';this.preview='';this.status='';const epoch=++this.epoch;
    try{const pcm=await selectAudioPcm();if(epoch!==this.epoch){return;}if(!pcm){this.mode='';return;}if(this.assistantMode){this.openAssistantPreview();}
      this.status='正在准备转写…';this.voice=new TaskVoiceCapture(()=>{if(epoch===this.epoch){this.status='正在转写…';}},(text:string,error:string)=>{if(epoch===this.epoch){this.voice=undefined;this.mode='';if(error){this.status=error;}else{this.acceptResult(text,'没有识别到文字，请换一段清晰的语音。');}}},(text:string)=>{if(epoch===this.epoch){this.preview=text.slice(0,2120);}});await this.voice.startPcm(pcm);
    }catch(error){if(epoch===this.epoch){this.mode='';this.status=(error as Error).message||'音频暂时无法读取';if(this.assistantMode){this.openAssistantPreview();}}}
  }

  private cancelVoice(): void {
    this.epoch++;
    this.voice?.close();
    this.voice = undefined;
    this.mode = '';
    this.listening = false;
    this.preview='';
    this.status = '已取消录音。';
  }

  private finishVoice(): void {
    this.listening = false;
    this.status = '正在整理识别文字…';
    this.voice?.finish();
  }

  private apply(): void {
    const value = this.preview.trim();
    if (value) {
      this.onApply(value);
      this.preview = '';
      this.status = '';
    }
  }

  private teal(): string {
    return themeColors(this.dark,this.tone).accent;
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        if(this.assistantMode){
          Button(this.imageLabel).type(ButtonType.Normal).height(40).layoutWeight(1).padding({left:4,right:4}).fontSize(12).fontColor(this.teal()).backgroundColor(themeColors(this.dark,this.tone).tint).borderRadius(this.corners==='square'?0:12).enabled(!this.blocked&&!this.mode).onClick(()=>this.onAddImage()).id('assistant-add-image')
        }else{
        Button('图片识字').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).layoutWeight(1).fontSize(12).padding({left:4,right:4}).fontColor(this.teal())
          .backgroundColor(Color.Transparent).borderRadius(this.corners==='square'?0:12).enabled(!this.mode).onClick(() => this.scan()).id('capture-ocr')
        }
        Button('语音输入').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).layoutWeight(1).fontSize(12).padding({left:4,right:4}).fontColor(this.teal())
          .height(this.assistantMode?40:36).backgroundColor(this.assistantMode?themeColors(this.dark,this.tone).tint:Color.Transparent).borderRadius(this.corners==='square'?0:12).enabled(!this.mode&&!this.blocked).onClick(() => this.speak()).id('capture-voice')
        Button('音频转写').type(ButtonType.Normal).height(this.assistantMode?40:36).layoutWeight(1).padding({left:4,right:4}).fontSize(12).fontColor(this.teal()).backgroundColor(this.assistantMode?themeColors(this.dark,this.tone).tint:Color.Transparent).borderRadius(this.corners==='square'?0:12).enabled(!this.mode&&!this.blocked).onClick(()=>this.audioFile()).id('capture-audio')
        if(this.assistantMode){Button(this.sendLabel).type(ButtonType.Normal).height(40).layoutWeight(1).padding({left:4,right:4}).fontSize(12).fontColor(themeColors(this.dark,this.tone).onPrimary).backgroundColor(themeColors(this.dark,this.tone).primary).borderRadius(this.corners==='square'?0:12).enabled(this.sendEnabled&&!this.mode).onClick(()=>this.onSend()).id('assistant-send')}
      }.width('100%')
      if (!this.assistantMode&&this.status) {
        Text(this.status).width('100%').fontSize(12).lineHeight(20)
          .fontColor(themeColors(this.dark,this.tone).muted).id('capture-input-status')
      }
      if (!this.assistantMode&&(this.mode === 'voice' || this.mode === 'audio')) {
        Row({ space: 10 }) {
          if (this.listening) {
            Button('结束录音').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(13).onClick(() => this.finishVoice()).id('capture-voice-finish')
          }
          Button('取消录音').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(13).fontColor(this.teal())
            .backgroundColor(Color.Transparent).borderRadius(this.corners==='square'?0:12).onClick(() => this.cancelVoice()).id('capture-voice-cancel')
        }.width('100%')
      }
      if (!this.assistantMode&&this.preview) {
        TextArea({ text: this.preview, placeholder: '识别文字' }).borderRadius(this.corners==='square'?0:12).maxLength(2120).height(105)
          .enabled(!this.mode).fontColor(themeColors(this.dark,this.tone).ink)
          .backgroundColor(themeColors(this.dark,this.tone).surface)
          .onChange((value: string) => this.preview = value).id('capture-input-preview')
        Button(this.applyLabel).type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(13).enabled(!this.mode)
          .onClick(() => this.apply()).id('capture-input-apply')
      }
    }.width('100%')
  }
}
