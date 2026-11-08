import { CourseCloud, CloudSession, CloudFailure, EmailReceipt } from '../services/CourseCloud';
import { uid } from '../model/MobileModel';
import { themeColors } from '../model/AppTheme';

@Component
export struct EmailPanel {
  cloud:CourseCloud=new CourseCloud();
  endpoint:string='';
  @Prop mode:string='register';
  @Prop dark:boolean=false;
  @Prop tone:string='whale';
  @Prop corners:string='round';
  @Prop codeExpiresSeconds:number=300;
  onClose:()=>void=()=>{};
  onUsernameRegistration:(username:string)=>void=()=>{};
  onRegistered:(session:CloudSession)=>void=()=>{};
  onBound:()=>void=()=>{};
  onReset:()=>void=()=>{};
  onBusyState:(value:boolean)=>void=()=>{};
  @State email:string='';
  @State code:string='';
  @State username:string='';
  @State password:string='';
  @State repeatedPassword:string='';
  @State currentPassword:string='';
  @State busy:boolean=false;
  @State sending:boolean=false;
  @State retrySeconds:number=0;
  @State message:string='';
  @State deliveryMessage:string='';
  @State canCheckDelivery:boolean=false;
  private active:boolean=true;
  private epoch:number=0;
  private timer:number=-1;
  private countdown:number=-1;
  private retryAt:number=0;
  private requestId:string='';
  private receiptId:string='';
  private deliveryStatus:string='';
  private pollFailures:number=0;
  private ticket:string='';
  private ticketUntil:number=0;
  aboutToAppear():void {this.active=true;}
  aboutToDisappear():void {this.active=false;this.epoch++;this.stopTimers();this.password='';this.repeatedPassword='';this.currentPassword='';this.code='';this.ticket='';this.onBusyState(false);}
  private ink():string {return themeColors(this.dark,this.tone).ink;}
  private muted():string {return themeColors(this.dark,this.tone).muted;}
  private surface():string {return themeColors(this.dark,this.tone).surface;}
  private tint():string {return themeColors(this.dark,this.tone).tint;}
  private teal():string {return themeColors(this.dark,this.tone).accent;}
  private title():string {return this.mode==='register'?'邮箱验证注册':this.mode==='bind'?'绑定邮箱':'找回密码';}
  private stopTimers():void {if(this.timer>=0){clearTimeout(this.timer);this.timer=-1;}if(this.countdown>=0){clearTimeout(this.countdown);this.countdown=-1;}}
  private setBusy(value:boolean):void {this.busy=value;this.onBusyState(value);}
  private validEmail():boolean {return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email.trim())&&this.email.trim().length<=254;}
  private changeEmail(value:string):void {this.email=value;this.epoch++;this.stopTimers();this.requestId='';this.receiptId='';this.deliveryStatus='';this.deliveryMessage='';this.retrySeconds=0;this.sending=false;this.canCheckDelivery=false;this.pollFailures=0;this.code='';this.ticket='';this.ticketUntil=0;}
  private tick():void {if(!this.active){return;}this.retrySeconds=Math.max(0,Math.ceil((this.retryAt-Date.now())/1000));if(this.retrySeconds>0){this.countdown=setTimeout(()=>{this.countdown=-1;this.tick();},1000);}}
  private updateReceipt(receipt:EmailReceipt):void {
    this.receiptId=receipt.id;this.deliveryStatus=receipt.status;this.canCheckDelivery=false;this.pollFailures=0;
    this.deliveryMessage=receipt.status==='accepted'?'发信服务已接收，尚未确认送达。请检查收件箱和垃圾邮件。':(receipt.message||(receipt.status==='unknown'?'投递结果未确认；若已收到，仍可输入验证码':receipt.status==='failed'?'发送未完成，请稍后重新获取验证码':'正在发送验证码…'));
    if(receipt.status==='queued'||receipt.status==='sending'){this.sending=true;this.timer=setTimeout(()=>{this.timer=-1;this.pollReceipt();},1600);}else{this.sending=false;}
  }
  private async sendCode():Promise<void> {
    if(this.busy||this.sending||this.retrySeconds>0){return;}if(!this.validEmail()){this.message='请填写有效邮箱地址';return;}
    const epoch=this.epoch;if(!this.requestId||['accepted','failed','unknown'].includes(this.deliveryStatus)){this.requestId=uid('email');this.deliveryStatus='';this.code='';this.ticket='';this.ticketUntil=0;}const requestId=this.requestId;this.sending=true;this.message='';this.deliveryMessage='正在提交发送请求…';
    try{const receipt=await this.cloud.emailSend(this.endpoint,this.email.trim(),this.mode,requestId);if(!this.active||epoch!==this.epoch||requestId!==this.requestId){return;}this.retryAt=Date.now()+Math.max(0,receipt.retryAfterSeconds)*1000;this.tick();this.updateReceipt(receipt);}
    catch(error){if(this.active&&epoch===this.epoch){this.sending=false;this.deliveryMessage=(error as Error).message||'发送结果未确认，请重试检查；不会自动重复发送';}}
  }
  private async pollReceipt():Promise<void> {
    if(!this.receiptId||!this.active){return;}if(this.timer>=0){clearTimeout(this.timer);this.timer=-1;}const epoch=this.epoch,id=this.receiptId;
    try{const receipt=await this.cloud.emailRequest(this.endpoint,id);if(!this.active||epoch!==this.epoch||id!==this.receiptId){return;}this.updateReceipt(receipt);}
    catch(error){if(!this.active||epoch!==this.epoch||id!==this.receiptId){return;}
      if(error instanceof CloudFailure&&[404,410].includes(error.status)){this.sending=false;this.canCheckDelivery=false;this.deliveryStatus='failed';this.receiptId='';this.deliveryMessage='这次发送记录已失效，可重新获取验证码；不会自动重发';return;}
      this.pollFailures++;
      if(this.pollFailures>=3||(error instanceof CloudFailure&&[401,403,503].includes(error.status))){this.sending=false;this.canCheckDelivery=true;this.deliveryMessage='状态检查已暂停，可稍后继续检查；收到邮件后仍可输入验证码';return;}
      this.deliveryMessage='状态暂时不可读取，正在等待重连；收到邮件后可直接验证';this.timer=setTimeout(()=>{this.timer=-1;this.pollReceipt();},6000);
    }
  }
  private resumeReceipt():void {if(this.busy||!this.receiptId){return;}this.pollFailures=0;this.canCheckDelivery=false;this.sending=true;this.pollReceipt();}
  private async submit():Promise<void> {
    if(this.busy){return;}if(!this.validEmail()||!/^\d{6}$/.test(this.code.trim())){this.message='请填写邮箱和6位验证码';return;}
    if(this.mode==='register'&&!/^[A-Za-z0-9_]{3,32}$/.test(this.username.trim())){this.message='用户名为3—32位字母、数字或下划线';return;}
    if(this.mode==='bind'){if(this.currentPassword.length<8){this.message='请输入当前账户密码';return;}}
    else if(this.password.length<8||this.password.length>200||this.password!==this.repeatedPassword){this.message=this.password!==this.repeatedPassword?'两次输入的密码不一致':'密码长度为8—200位';return;}
    this.getUIContext().getFocusController().clearFocus();this.setBusy(true);this.message='正在验证…';const epoch=this.epoch;
    try{if(!this.ticket||this.ticketUntil<=Date.now()){const proof=await this.cloud.emailVerify(this.endpoint,this.email.trim(),this.mode,this.code.trim());if(!this.active||epoch!==this.epoch){return;}this.ticket=proof.ticket;this.ticketUntil=Date.now()+proof.expiresInSeconds*1000;}
      if(this.mode==='register'){const session=await this.cloud.emailRegister(this.endpoint,this.username.trim(),this.email.trim(),this.password,this.ticket);if(!this.active||epoch!==this.epoch){return;}this.password='';this.repeatedPassword='';this.ticket='';this.onRegistered(session);}
      else if(this.mode==='bind'){await this.cloud.emailBind(this.email.trim(),this.ticket,this.currentPassword);if(!this.active||epoch!==this.epoch){return;}this.currentPassword='';this.ticket='';this.onBound();}
      else{await this.cloud.emailReset(this.endpoint,this.email.trim(),this.ticket,this.password);if(!this.active||epoch!==this.epoch){return;}this.password='';this.repeatedPassword='';this.ticket='';this.onReset();}
    }catch(error){if(this.active&&epoch===this.epoch){this.message=(error as Error).message||'操作未完成，请检查验证码后重试';}}
    finally{if(this.active&&epoch===this.epoch){this.setBusy(false);}}
  }
  @Builder
  private field(label:string) {Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.muted()).width('100%').margin({top:5})}
  build() {
    Column(){
      Row(){Button('‹').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(30).fontColor(this.teal()).backgroundColor(Color.Transparent).enabled(!this.busy).onClick(()=>this.onClose()).id('email-back');Text(this.title()).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1)}.width('100%').height(62).padding({left:8,right:22})
      Scroll(){Column({space:14}){
        this.field('邮箱地址')
        TextInput({text:this.email,placeholder:'name@example.com'}).type(InputType.Email).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.corners==='square'?0:12).maxLength(254).enabled(!this.busy&&!this.sending).onChange((value:string)=>this.changeEmail(value)).id('email-address')
        Row({space:10}){TextInput({text:this.code,placeholder:'6位验证码'}).type(InputType.Number).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.corners==='square'?0:12).maxLength(6).enabled(!this.busy).onChange((value:string)=>{this.code=value;this.ticket='';this.ticketUntil=0;}).layoutWeight(1).id('email-code');Button(this.sending?'正在发送…':this.retrySeconds>0?`${this.retrySeconds}s 后重发`:'获取验证码').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(12).height(44).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.corners==='square'?0:12).enabled(!this.busy&&!this.sending&&!this.canCheckDelivery&&this.retrySeconds===0).onClick(()=>{this.sendCode();}).id('email-send')}.width('100%')
        if(this.deliveryMessage){Text(this.deliveryMessage).fontSize(12).fontColor(this.muted()).lineHeight(21).width('100%').id('email-delivery-status')}
        if(this.canCheckDelivery){Button('继续检查发送状态').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.corners==='square'?0:12).enabled(!this.busy).onClick(()=>this.resumeReceipt()).id('email-check')}
        if(this.mode==='register'&&!this.sending){
          Button('收不到验证码？改用用户名注册').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).fontSize(12).fontColor(this.teal()).backgroundColor(Color.Transparent).enabled(!this.busy).onClick(()=>this.onUsernameRegistration(this.username.trim())).id('email-use-username')
        }
        if(this.mode==='register'){
          this.field('用户名')
          TextInput({text:this.username,placeholder:'3—32位字母、数字或下划线'}).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.corners==='square'?0:12).maxLength(32).enabled(!this.busy).onChange((value:string)=>this.username=value).id('email-username')
        }
        if(this.mode==='bind'){
          this.field('当前账户密码')
          TextInput({text:this.currentPassword,placeholder:'用于确认是你本人'}).type(InputType.Password).showPasswordIcon(false).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.corners==='square'?0:12).maxLength(200).enabled(!this.busy).onChange((value:string)=>this.currentPassword=value).id('email-current-password')
        }else{
          this.field(this.mode==='reset'?'新密码':'密码')
          TextInput({text:this.password,placeholder:'至少8位'}).type(InputType.Password).showPasswordIcon(false).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.corners==='square'?0:12).maxLength(200).enabled(!this.busy).onChange((value:string)=>this.password=value).id('email-password')
          this.field('再次输入密码')
          TextInput({text:this.repeatedPassword,placeholder:'再次输入相同密码'}).type(InputType.Password).showPasswordIcon(false).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.corners==='square'?0:12).maxLength(200).enabled(!this.busy).onChange((value:string)=>this.repeatedPassword=value).id('email-password-repeat')
        }
        Button(this.busy?'正在处理…':this.mode==='register'?'验证并注册':this.mode==='bind'?'验证并绑定':'重置密码').type(ButtonType.Normal).borderRadius(this.corners==='square'?0:12).width('100%').height(48).borderRadius(this.corners==='square'?0:12).fontColor(themeColors(this.dark,this.tone).onPrimary).backgroundColor(themeColors(this.dark,this.tone).primary).enabled(!this.busy).onClick(()=>{this.submit();}).id('email-submit')
        if(this.message){Text(this.message).fontSize(13).fontColor(this.muted()).lineHeight(22).width('100%').id('email-message')}
        Text(`验证码有效期${Math.max(1,Math.ceil(this.codeExpiresSeconds/60))}分钟`).fontSize(11).fontColor(this.muted()).lineHeight(21).width('100%')
        Blank().height(24)
      }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Auto).align(Alignment.Top)
    }.width('100%').height('100%')
  }
}
