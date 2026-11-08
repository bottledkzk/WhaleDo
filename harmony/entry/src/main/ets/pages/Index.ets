import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { ReminderOptions, ReminderItem, reminderPlan } from '../model/ReminderPlan';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { MobileData, MobileTask, Diary, Block, WorkHours, WorkDate, workHoursFor, workHoursOn, allDaySpan, allDayEvent, PlanProposal, proposePlan, acceptPlan, undoPlan, clone, uid, dayStart, addDays, dateKey, clock, localText, minuteText, upsertTask, finishTask, tasksOn, monthCells, activeTasks, trashTasks, deleteTask, restoreTask, taskStats } from '../model/MobileModel';
import { themeColors, toneIds, toneLabels } from '../model/AppTheme';
import { AppTime, zoneIds, zoneLabels } from '../model/AppTime';
import { changeTimeZone } from '../model/ZonePolicy';
import { AvatarPhoto } from '../services/AvatarPhoto';
import { MobileStore } from '../services/MobileStore';
import { CourseCloud, CloudSession, CloudHead, CloudFailure, AiTask, AiResult, AiReceipt, AiMessage, EmailStatus } from '../services/CourseCloud';
import { COURSE_ENDPOINT } from '../services/Endpoint';
import { ShareExport } from '../services/ShareExport';
import { MobileReminders } from '../services/MobileReminders';
import { CloudSync, SyncScope, ManualSyncPreview } from '../services/CloudSync';
import { SystemCalendar, CalendarImportRecord } from '../services/SystemCalendar';
import { calendarImport } from '../model/CalendarImport';
import { AssistantSession, AssistantRecord, AssistantPending, ConversationInfo } from '../services/AssistantSession';
import { ThemeWindow } from '../services/ThemeWindow';
import { EmailPanel } from '../components/EmailPanel';
import { assistantImage } from '../services/AssistantImage';
import { boundedHistory } from '../model/AiHistory';
import { applyAssistantPlan, planSize, TaskEdit, PlannedTime } from '../model/AssistantPlan';
import { FeedPending } from '../services/FeedPending';
import { FeedCard, FeedDraft, FeedPost } from '../services/CourseCloud';
import { TaskCaptureInput } from '../components/TaskCaptureInput';

interface SelectFieldOptions {
  labels:string[];
  selected:number;
  id:string;
  change:(index:number)=>void;
  enabled?:boolean;
}
interface PickerButtonOptions {
  label:string;
  id:string;
  action:()=>void;
  enabled?:boolean;
}
interface ChipOptions {label:string;active:boolean;action:()=>void;}
interface SectionOptions {title:string;detail?:string;}
interface EmptyOptions {title:string;subtitle?:string;}
interface ProfileRowOptions {icon:string;title:string;subtitle:string;action:()=>void;}
interface CountOptions {value:string;label:string;}
interface LabelOptions {label:string;}
interface TitleOptions {title:string;}
interface DateFieldOptions {label:string;id:string;reservation:boolean;}
interface StarOptions {
  value:number;
  id:string;
  change:(value:number)=>void;
}

@Entry
@Component
struct Index {
  @State data:MobileData=new MobileData();
  @State ready:boolean=false;
  @State failure:string='';
  @State tab:number=0;
  @State viewportWidth:number=360;
  @State viewportHeight:number=780;
  @State panel:string='';
  @State query:string='';
  @State showDone:boolean=false;
  @State agenda:boolean=false;
  @State selectedDay:number=dayStart(Date.now());
  @State month:number=dayStart(Date.now());
  @State calendarView:string='month';
  @State calendarRecords:CalendarImportRecord[]=[];
  @State selectedCalendarIds:string[]=[];
  @State calendarMessage:string='';
  @State calendarBusy:boolean=false;
  @State draftTitle:string='';
  @State draftNote:string='';
  @State draftMinutes:string='';
  @State durationUnit:number=0;
  @State draftDeadline:number=0;
  @State draftReservation:number=0;
  @State draftCategory:string='生活';
  @State draftPriority:number=3;
  @State draftRepeat:string='none';
  @State editId:string='';
  @State detail:boolean=false;
  @State ratingId:string='';
  @State rating:number=5;
  @State diary:string='';
  @State diaryDay:number=dayStart(Date.now());
  @State draftNickname:string='';
  @State draftMotto:string='';
  @State zoneChoice:string='Asia/Shanghai';
  @State zonePolicy:string='absolute';
  private parentPanels:Map<string,string>=new Map<string,string>();
  @State workDaily:WorkHours=new WorkHours(540,1320);
  @State workWeekdays:WorkHours[]=[];
  @State workWeek:WorkHours[]=[];
  @State workMode:number=0;
  @State workScope:string='default';
  @State workDate:number=dayStart(Date.now());
  @State avatarBusy:boolean=false;
  private workParent:string='';
  @State mode:string='聊天';
  @State chatDraft:string='';
  @State aiImages:string[]=[];
  @State aiPictureBusy:boolean=false;
  @State conversations:ConversationInfo[]=[];
  @State conversationTitle:string='新对话';
  @State conversationQuery:string='';
  @State showArchived:boolean=false;
  @State renameConversationId:string='';
  @State renameConversationTitle:string='';
  @State readAgenda:boolean=false;
  @State aiMessages:AiMessage[]=[];
  @State aiJob:AiReceipt=new AiReceipt();
  @State aiResult:AiResult=new AiResult();
  @State aiBusy:boolean=false;
  @State aiRejected:boolean=false;
  @State aiMessage:string='';
  @State aiApplied:boolean=false;
  @State canUndoAi:boolean=false;
  @State aiPending:AssistantPending=new AssistantPending();
  @State assistantReady:boolean=true;
  @State assistantStorageMessage:string='';
  @State reminderMessage:string='事项提醒已关闭';
  @State remindersEnabled:boolean=false;
  @State reminderBusy:boolean=false;
  @State reminderDraft:ReminderOptions=new ReminderOptions();
  @State feedItems:FeedPost[]=[];
  @State feedBusy:boolean=false;
  @State feedLikeBusy:string='';
  @State feedNext:number=0;
  @State feedMessage:string='';
  @State shareCaption:string='';
  @State captionStyle:number=0;
  @State publishPending:FeedDraft|undefined=undefined;
  private feedPending:FeedPending=new FeedPending();
  private captionCard:FeedCard|undefined=undefined;
  private publishOwner:string='';
  private feedEpoch:number=0;
  private chatScroller:Scroller=new Scroller();
  @State shareStyle:number=0;
  @State shareTitle:string='今天的进度';
  @State shareBody:string='';
  @State shareSource:number=0;
  @State shareBusy:boolean=false;
  @State shareStage:string='';
  private shareTaskId:string='';
  @State syncMessage:string='本机记录已保存';
  @State syncWorking:boolean=false;
  @State syncSchedule:boolean=true;
  @State syncDiaries:boolean=false;
  @State session:CloudSession=new CloudSession();
  @State username:string='';
  @State password:string='';
  @State registering:boolean=false;
  @State emailStatus:EmailStatus=new EmailStatus();
  @State emailStatusMessage:string='';
  @State emailMode:string='register';
  @State busy:boolean=false;
  @State cloudMessage:string='';
  @State cloudHead:CloudHead=new CloudHead();
  @State headReady:boolean=false;
  @State history:CloudHead[]=[];
  @State moreHistory:boolean=false;
  @State syncPreview:ManualSyncPreview=new ManualSyncPreview();
  @State proposal:PlanProposal=new PlanProposal();
  @State canUndo:boolean=false;
  @StorageLink('systemDark') @Watch('updateSystemBars') systemDark:boolean=false;
  @StorageLink('keyboardVisible') keyboardVisible:boolean=false;
  @StorageLink('appActive') @Watch('onActiveChanged') appActive:boolean=true;
  private store:MobileStore=new MobileStore();
  private cloud:CourseCloud=new CourseCloud();
  private undoBlocks:Block[]=[];
  private undoSignature:string='';
  private aiOwner:string='';
  private aiDisplayedId:string='';
  private aiSignature:string='';
  private aiUndo:MobileData=new MobileData();
  private aiUndoSignature:string='';
  private aiTimer:number=-1;
  private sync:CloudSync=new CloudSync();
  private reminderEpoch:number=0;
  private calendarEpoch:number=0;
  private calendarSignature:string='';
  private calendarOwner:string='';
  @State calendarExporting: boolean = false;
  private assistantStore:AssistantSession=new AssistantSession();
  private emailEpoch:number=0;
  private labels:string[]=['今日','待办','日历','助手','我的'];
  private readonly weekLabels:string[]=['星期一','星期二','星期三','星期四','星期五','星期六','星期日'];
  private readonly workModes:string[]=['每天相同','工作日 / 休息日','按星期'];
  private readonly durationUnits:string[]=['分钟','小时','天'];
  private readonly durationFactors:number[]=[1,60,1440];
  private readonly assistantModes:string[]=['聊天','拆解任务','计划建议','回顾','日记润色','分享配文'];
  private readonly repeatValues:string[]=['none','daily','weekdays','weekly'];
  private readonly calendarViews:string[]=['month','week','day'];
  private readonly themeValues:string[]=['light','dark','system'];
  private readonly themeLabels:string[]=['浅色','深色','跟随系统'];

  aboutToAppear():void {this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);this.load();}
  aboutToDisappear():void {this.clearAiTimer();}
  private load():void {this.loadSession();}
  private async loadSession():Promise<void> {this.ready=false;try{await this.cloud.load();this.session=this.cloud.session;this.data=this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext,this.session.user.id||'guest');this.selectedDay=dayStart(Date.now());this.month=this.selectedDay;this.prepareSync();this.ready=true;this.failure='';}catch{this.failure='无法读取本机记录或登录状态，原文件已保留，请重试。';}}
  private dark():boolean {return this.data.theme==='dark'||(this.data.theme==='system'&&this.systemDark);}
  private paper():string {return themeColors(this.dark(),this.data.tone).paper;}
  private surface():string {return themeColors(this.dark(),this.data.tone).surface;}
  private ink():string {return themeColors(this.dark(),this.data.tone).ink;}
  private muted():string {return themeColors(this.dark(),this.data.tone).muted;}
  private teal():string {return themeColors(this.dark(),this.data.tone).accent;}
  private tint():string {return themeColors(this.dark(),this.data.tone).tint;}
  private line():string {return themeColors(this.dark(),this.data.tone).line;}
  private primary():string {return themeColors(this.dark(),this.data.tone).primary;}
  private onPrimary():string {return themeColors(this.dark(),this.data.tone).onPrimary;}
  private radius(value:number):number {return this.data.corners==='square'?0:value;}
  private avatarSource():Resource|string {return this.data.avatar?AvatarPhoto.uri(this.getUIContext().getHostContext() as common.UIAbilityContext,this.data.avatar):$r('app.media.launcher_icon');}
  private avatarMenu():void {
    if(this.avatarBusy){return;}
    this.getUIContext().getPromptAction().showActionMenu({title:'更换头像',buttons:[{text:'拍照',color:this.teal()},{text:'从相册选择',color:this.teal()},{text:'恢复默认头像',color:this.muted()}]})
      .then((result)=>{if(result.index===2){const next=clone(this.data),old=next.avatar;next.avatar=undefined;if(this.save(next,'头像已更新')&&old){AvatarPhoto.remove(this.getUIContext().getHostContext() as common.UIAbilityContext,old);}}else if(result.index===0||result.index===1){this.changeAvatar(result.index===0);}}).catch(()=>{});
  }
  private async changeAvatar(takePhoto:boolean):Promise<void> {
    if(this.avatarBusy){return;}this.avatarBusy=true;
    const owner=this.session.user.id||'guest',context=this.getUIContext().getHostContext() as common.UIAbilityContext;
    try{const name=await AvatarPhoto.select(context,owner,takePhoto);if(!name){return;}
      if(owner!==(this.session.user.id||'guest')){AvatarPhoto.remove(context,name);return;}
      const next=clone(this.data),old=next.avatar;next.avatar=name;
      if(this.save(next,'头像已更新')){if(old){AvatarPhoto.remove(context,old);}}else{AvatarPhoto.remove(context,name);}
    }catch{this.toast(takePhoto?'未能使用相机，可从相册选择头像':'未能读取所选图片，请重试');}finally{this.avatarBusy=false;}
  }
  private updateSystemBars():void {const context=this.getUIContext().getHostContext() as common.UIAbilityContext;if(context){ThemeWindow.apply(context,this.dark(),this.data.tone).catch(()=>{});}}
  private navIcon(index:number):Resource {if(index===0){return $r('app.media.nav_today');}if(index===1){return $r('app.media.nav_tasks');}if(index===2){return $r('app.media.nav_calendar');}if(index===3){return $r('app.media.nav_assistant');}return $r('app.media.nav_profile');}
  private toast(message:string):void {this.getUIContext().getPromptAction().showToast({message:message,duration:2500});}
  private save(candidate:MobileData,message:string='已保存'):boolean {try{const next=clone(candidate);next.revision=this.data.revision+1;this.store.save(next);const changedTheme=this.data.theme!==next.theme||this.data.tone!==next.tone;this.data=next;AppTime.zone=next.timeZone||AppTime.systemZone;if(changedTheme){this.updateSystemBars();}this.canUndo=false;this.canUndoAi=false;if(this.remindersEnabled){this.refreshReminders();}if(message){this.toast(message);}return true;}catch{this.toast('保存失败，原记录保留，请检查空间后重试');return false;}}
  private pending():MobileTask[] {return activeTasks(this.data).filter((t:MobileTask)=>!t.done);}
  private completed():MobileTask[] {return activeTasks(this.data).filter((t:MobileTask)=>t.done);}
  private todayBlocks():Block[] {const start=dayStart(Date.now()),end=addDays(start,1);return this.data.blocks.filter((b:Block)=>b.start<end&&b.end>start).sort((a:Block,b:Block)=>a.start-b.start);}
  private taskName(id:string):string {return this.data.tasks.find((t:MobileTask)=>t.id===id)?.title||'事项';}
  private inbox():MobileTask[] {return this.pending().filter((t:MobileTask)=>t.minutes===0||t.deadline===0);}
  private rows():MobileTask[] {const source=this.agenda?tasksOn(this.data,this.selectedDay):activeTasks(this.data);return source.filter((t:MobileTask)=>(this.showDone||!t.done)&&(`${t.title} ${t.note}`.toLowerCase().includes(this.query.trim().toLowerCase())));}
  private newTask():void {this.editId='';this.draftTitle='';this.draftNote='';this.draftMinutes='';this.durationUnit=0;this.draftDeadline=0;this.draftReservation=0;this.draftCategory='生活';this.draftPriority=3;this.draftRepeat='none';this.detail=false;this.panel='capture';}
  private applyCapturedText(value: string): void {
    let note = value;
    if (!this.draftTitle.trim()) {
      const lineEnd = value.indexOf('\n');
      const titleLength = lineEnd < 0 ? 120 : Math.min(lineEnd, 120);
      this.draftTitle = value.slice(0, titleLength).replace(/[\uD800-\uDBFF]$/, '').trim();
      note = value.slice(this.draftTitle.length).trim();
    }
    if (note) {
      const combined = this.draftNote ? this.draftNote + '\n' + note : note;
      this.draftNote = combined.slice(0, 2000).replace(/[\uD800-\uDBFF]$/, '');
      this.detail = true;
      if (combined.length > 2000) {
        this.toast('备注已达上限，部分识别文字未填入。');
      }
    }
  }
  private editTask(task:MobileTask):void {
    this.editId=task.id;this.draftTitle=task.title;this.draftNote=task.note;
    this.durationUnit=task.minutes>0&&task.minutes%1440===0?2:task.minutes>0&&task.minutes%60===0?1:0;
    this.draftMinutes=task.minutes?String(task.minutes/this.durationFactors[this.durationUnit]):'';
    this.draftDeadline=task.deadline;this.draftReservation=0;this.draftCategory=task.category;
    this.draftPriority=task.priority;this.draftRepeat=task.repeat||'none';this.detail=true;this.panel='capture';
  }
  private stepDuration(change:number):void {
    const value=Number(this.draftMinutes)||0;
    const next=Math.max(0,Math.min(value+change,525600/this.durationFactors[this.durationUnit]));
    this.draftMinutes=next?String(Number(next.toFixed(10))):'';
  }
  private saveTask():void {
    try{const original=this.data.tasks.find((t:MobileTask)=>t.id===this.editId);const task=original===undefined?new MobileTask():JSON.parse(JSON.stringify(original)) as MobileTask;
      task.id=this.editId||uid('task');task.createdAt=original?.createdAt||Date.now();task.title=this.draftTitle;task.note=this.draftNote;task.category=this.draftCategory;task.priority=this.draftPriority;task.repeat=this.draftRepeat;task.timeZone=AppTime.zone;
      const duration=this.draftMinutes.trim();
      const minutes=Number(duration)*this.durationFactors[this.durationUnit];
      if((duration&&!/^\d+(?:\.\d+)?$/.test(duration))||!Number.isFinite(minutes)||minutes>525600||
        Math.abs(minutes-Math.round(minutes))>0.000001){throw new Error('预计用时须能换算成整分钟，最多 365 天');}
      task.minutes=Math.round(minutes);task.deadline=this.draftDeadline;
      if(this.save(upsertTask(this.data,task,this.draftReservation),'已保存')){this.panel='';}
    }catch(error){this.toast((error as Error).message||'请检查填写内容');}
  }
  private plan():void {try{this.proposal=proposePlan(this.data);this.panel='proposal';}catch{this.toast('暂时无法安排，请检查事项和行动时间');}}
  private applyPlan():void {try{const next=acceptPlan(this.data,this.proposal);const before=this.proposal.before;if(this.save(next,'计划已应用')){this.undoBlocks=before;this.undoSignature=JSON.stringify(this.data);this.canUndo=true;this.panel='';}}catch(error){this.toast((error as Error).message);}}
  private undo():void {try{this.save(undoPlan(this.data,this.undoBlocks,this.undoSignature),'已撤销本次安排');}catch(error){this.canUndo=false;this.toast((error as Error).message);}}
  private confirmUndo():void {
    this.getUIContext().showAlertDialog({title:'撤销刚才的安排？',message:'将恢复到本次自动安排前的时间安排。',
      primaryButton:{value:'保留安排',action:()=>{}},secondaryButton:{value:'确认撤销',action:()=>this.undo()}});
  }
  private repeatLabel(value:string):string {return value==='daily'?'每天':value==='weekdays'?'工作日':value==='weekly'?'每周':'不重复';}
  private categoryLabels():string[] {const labels:string[]=['生活','学习','工作','运动','其它'];for(const task of activeTasks(this.data)){if(task.category&&!labels.includes(task.category)){labels.push(task.category);}}return labels;}
  private async openCalendarImport():Promise<void> {
    const epoch=++this.calendarEpoch;this.calendarOwner=this.session.user.id||'guest';this.calendarSignature=JSON.stringify(this.data);this.calendarRecords=[];this.selectedCalendarIds=[];this.calendarMessage='正在读取未来30天的系统日历…';this.calendarBusy=true;this.panel='calendar-import';
    try{const records=await SystemCalendar.read(this.getUIContext().getHostContext() as common.UIAbilityContext);if(epoch!==this.calendarEpoch||this.calendarOwner!==(this.session.user.id||'guest')){return;}this.calendarRecords=records;this.calendarMessage=records.length>0?`找到 ${records.length} 条日程，请选择需要导入的项目`:'未来30天没有可导入的日程';}catch(error){if(epoch===this.calendarEpoch){this.calendarMessage=(error as Error).message||'系统日历暂时无法读取，请稍后重试';}}finally{if(epoch===this.calendarEpoch){this.calendarBusy=false;}}
  }
  private chooseCalendar(id:string,selected:boolean):void {this.selectedCalendarIds=selected?this.selectedCalendarIds.filter((item:string)=>item!==id).concat([id]):this.selectedCalendarIds.filter((item:string)=>item!==id);}
  private calendarRecordTime(record:CalendarImportRecord):string {if(!record.allDay){return `${localText(record.start)} — ${localText(record.end)}`;}const first=dateKey(record.start),last=dateKey(record.end-1);return first===last?`${first} · 全天`:`${first} — ${last} · 全天`;}
  private allDayBlock(block:Block):boolean {return allDayEvent(this.data,block);}
  private blockDateRange(block:Block):string {const task=this.data.tasks.find((item:MobileTask)=>item.id===block.taskId),span=task?allDaySpan(task):[];const first=span[0]||dateKey(block.start),last=span[1]||dateKey(block.end-1);return first===last?first:`${first} — ${last}`;}
  private blockDetail(block:Block):string {const state=block.done?'已完成':block.locked?'固定安排':'自动安排';if(this.allDayBlock(block)){return `${this.blockDateRange(block)} · ${dateKey(block.start)===dateKey(block.end-1)?'全天':'多日'} · ${state}`;}if(dateKey(block.start)!==dateKey(block.end)){return `${localText(block.start)} — ${localText(block.end)} · ${state}`;}return `${Math.round((block.end-block.start)/60000)}分钟 · ${state}`;}
  private taskDuration(task:MobileTask):string {const block=this.data.blocks.find((item:Block)=>item.taskId===task.id&&this.allDayBlock(item));if(block){return dateKey(block.start)===dateKey(block.end-1)?'全天日程':'多日日程';}if(task.category==='日历'&&task.note.startsWith('全天日程')){return '全天日程';}return task.minutes?`${task.minutes}分钟`:'待整理';}
  private taskDeadline(task:MobileTask):string {if(!task.deadline){return '';}const allDay=this.data.blocks.some((block:Block)=>block.taskId===task.id&&this.allDayBlock(block))||(task.category==='日历'&&task.note.startsWith('全天日程')),date=AppTime.view(task.deadline-(allDay?1:0));return ` · ${date.getMonth()+1}/${date.getDate()} ${allDay?'结束':'截止'}`;}
  private blockListLabel(block:Block):string {return this.allDayBlock(block)||dateKey(block.start)!==dateKey(block.end)?`◷ ${this.blockDetail(block)}`:`◷ ${localText(block.start)}–${clock(block.end)} · ${block.locked?'固定':'自动'}`;}
  private todayMinutes():number {const start=dayStart(Date.now()),end=addDays(start,1);return Math.round(this.todayBlocks().reduce((sum:number,block:Block)=>sum+(Math.min(block.end,end)-Math.max(block.start,start))/60000,0));}
  private applyCalendarImport():void {if(this.calendarBusy||this.selectedCalendarIds.length===0){return;}if(this.calendarOwner!==(this.session.user.id||'guest')){this.toast('账户已变化，请重新读取日历');return;}try{const selected=this.calendarRecords.filter((record:CalendarImportRecord)=>this.selectedCalendarIds.includes(record.id)),next=calendarImport(this.data,selected,this.calendarSignature),added=activeTasks(next).length-activeTasks(this.data).length;if(added===0){this.toast('所选日程已存在，不重复导入');return;}if(this.save(next,`已导入 ${added} 条日程`)){this.panel='';this.tab=2;}}catch(error){this.toast((error as Error).message||'导入未完成，原记录保持不变');}}
  private confirmDelete():void {
    if(!this.editId){return;}
    const id=this.editId;
    this.getUIContext().showAlertDialog({title:'移入回收站？',message:'事项与安排将从当前列表移除，之后可在回收站恢复事项。',primaryButton:{value:'取消',action:()=>{}},secondaryButton:{value:'移入回收站',action:()=>{try{if(this.save(deleteTask(this.data,id),'已移入回收站')){this.panel='';}}catch(error){this.toast((error as Error).message);}}}});
  }
  private recoverTask(id:string):void {try{this.save(restoreTask(this.data,id),'事项已恢复，可重新安排');}catch(error){this.toast((error as Error).message);}}
  private async share(calendar:boolean,taskId:string=''):Promise<void> {try{await ShareExport.share(this.getUIContext().getHostContext() as common.UIAbilityContext,this.data,calendar,taskId);}catch{this.toast('分享未完成，请稍后重试');}}
  private async addToSystemCalendar(): Promise<void> {
    if (this.calendarExporting) {
      return;
    }
    const task = this.data.tasks.find((item: MobileTask) => item.id === this.editId);
    if (!task) {
      return;
    }
    const first = this.data.blocks.filter((block: Block) => block.taskId === task.id)
      .sort((a: Block, b: Block) => a.start - b.start)[0];
    if (!first && !task.deadline) {
      this.toast('保存截止时间或安排后，就能添加到系统日历。');
      return;
    }
    const end = first ? first.end : task.deadline;
    const start = first ? first.start : end - (task.minutes || 30) * 60000;
    this.calendarExporting = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const saved = await SystemCalendar.openNewEvent(context, task.title, start, end);
      this.toast(saved ? '已添加到系统日历' : '未添加到系统日历');
    } catch {
      this.toast('未能打开或保存系统日历，可尝试导出 ICS。');
    } finally {
      this.calendarExporting = false;
    }
  }
  private async enableReminders():Promise<void> {
    if(this.reminderBusy){return;}this.reminderBusy=true;const epoch=this.reminderEpoch;
    try{await MobileReminders.configure(this.getUIContext().getHostContext() as common.UIAbilityContext,this.data,this.reminderDraft);const message=await MobileReminders.enable(this.getUIContext().getHostContext() as common.UIAbilityContext,this.data);if(epoch!==this.reminderEpoch){return;}this.reminderMessage=message;this.remindersEnabled=true;}catch(error){if(epoch===this.reminderEpoch){this.reminderMessage=(error as Error).message||'提醒未启用，请检查通知权限';this.remindersEnabled=false;}}finally{if(epoch===this.reminderEpoch){this.reminderBusy=false;}}
  }
  private async refreshReminders():Promise<void> {const epoch=this.reminderEpoch;try{const message=await MobileReminders.refresh(this.getUIContext().getHostContext() as common.UIAbilityContext,this.data);if(epoch===this.reminderEpoch){this.reminderMessage=message;}}catch(error){if(epoch===this.reminderEpoch){this.reminderMessage=(error as Error).message||'提醒更新未完成，请打开提醒页检查';}}finally{if(epoch===this.reminderEpoch){this.remindersEnabled=MobileReminders.isEnabled();}}}
  private async disableReminders():Promise<void> {if(this.reminderBusy){return;}this.reminderBusy=true;const epoch=this.reminderEpoch;try{await MobileReminders.disable();if(epoch!==this.reminderEpoch){return;}this.remindersEnabled=false;this.reminderMessage='已关闭本应用的系统提醒';}catch(error){if(epoch===this.reminderEpoch){this.reminderMessage=(error as Error).message||'关闭未完成，请重试';}}finally{if(epoch===this.reminderEpoch){this.reminderBusy=false;this.remindersEnabled=MobileReminders.isEnabled();}}}
  private async testReminder():Promise<void> {if(this.reminderBusy){return;}this.reminderBusy=true;const epoch=this.reminderEpoch;try{const message=await MobileReminders.test(this.getUIContext().getHostContext() as common.UIAbilityContext);if(epoch===this.reminderEpoch){this.reminderMessage=message;}}catch(error){if(epoch===this.reminderEpoch){this.reminderMessage=(error as Error).message||'测试提醒未发送，请检查通知权限';}}finally{if(epoch===this.reminderEpoch){this.reminderBusy=false;}}}
  private openReminders():void {this.reminderDraft=MobileReminders.options();this.showPanel('reminders');}
  private updateReminder(flag:string,value:boolean):void {const options=JSON.parse(JSON.stringify(this.reminderDraft)) as ReminderOptions;if(flag==='starts'){options.starts=value;}else if(flag==='deadlines'){options.deadlines=value;}else{options.quiet=value;}this.reminderDraft=options;}
  private pickQuiet(end:boolean):void {this.pickTime(end?this.reminderDraft.quietEnd:this.reminderDraft.quietStart,0,1439,(minute:number)=>{const options=JSON.parse(JSON.stringify(this.reminderDraft)) as ReminderOptions;if(end){options.quietEnd=minute;}else{options.quietStart=minute;}this.reminderDraft=options;});}
  private reminderPreview():ReminderItem[] {return reminderPlan(this.data,Date.now(),this.reminderDraft).slice(0,10);}
  private async saveReminderOptions():Promise<void> {
    if(this.reminderBusy){return;}this.reminderBusy=true;const epoch=this.reminderEpoch;
    try{const message=await MobileReminders.configure(this.getUIContext().getHostContext() as common.UIAbilityContext,this.data,this.reminderDraft);if(epoch===this.reminderEpoch){this.reminderMessage=message;this.toast(message);}}
    catch(error){if(epoch===this.reminderEpoch){this.toast((error as Error).message);}}finally{if(epoch===this.reminderEpoch){this.reminderBusy=false;this.remindersEnabled=MobileReminders.isEnabled();}}
  }
  private async testNotification():Promise<void> {if(this.reminderBusy){return;}this.reminderBusy=true;const epoch=this.reminderEpoch;try{const message=await MobileReminders.testNotification(this.getUIContext().getHostContext() as common.UIAbilityContext);if(epoch===this.reminderEpoch){this.reminderMessage=message;}}catch(error){if(epoch===this.reminderEpoch){this.reminderMessage=(error as Error).message;}}finally{if(epoch===this.reminderEpoch){this.reminderBusy=false;}}}
  private openShare(taskId:string=''):void {this.shareTaskId=taskId;this.shareSource=0;this.shareCaption='';this.shareTitle=taskId?this.taskName(taskId):'今天的进度';this.fillShareBody();this.showPanel('share');}
  private fillShareBody():void {
    const source=this.shareTaskId?activeTasks(this.data).filter((task:MobileTask)=>task.id===this.shareTaskId):this.shareSource===1?tasksOn(this.data,this.selectedDay):activeTasks(this.data).filter((task:MobileTask)=>this.shareSource===2?task.done:!task.done);
    this.shareBody=source.slice(0,5).map((task:MobileTask)=>(task.done?'✓ ':'○ ')+task.title).join('\n')||'每一步，都算数。';
  }
  private shareReply(value:string):void {const card=this.captionCard;this.openShare();if(this.mode==='分享配文'){if(card){this.shareStyle=card.style;this.shareTitle=card.title;this.shareBody=card.lines.join('\n');}this.shareCaption=value.slice(0,2000);}else{this.shareTitle='一点小想法';this.shareBody=value.split('\n').filter((line:string)=>line.trim()).slice(0,5).join('\n').slice(0,1000);}}
  private diaryReply():void {this.diaryDay=dayStart(Date.now());this.diary=this.aiResult.text.slice(0,800);this.showPanel('diary','');}
  private reviseProposal():void {this.chatDraft='请调整刚才的任务建议：';this.panel='';this.tab=3;this.persistAssistant();}
  private shareSnapshot():FeedCard {const card=new FeedCard();card.style=this.shareStyle;card.title=this.shareTitle.trim()||'今天的进度';card.lines=this.shareBody.split('\n').filter((line:string)=>line.trim()).slice(0,5).map((line:string)=>line.slice(0,200));card.date=dateKey(Date.now());card.footer=this.data.nickname||'鲸办 WhaleDo';return card;}
  private shareScale():number {return Math.max(0.3,Math.min(1,(this.viewportWidth-44)/360));}
  private shareArt(style:number):Resource {return style===1?$r('app.media.share_morning'):style===2?$r('app.media.share_night'):$r('app.media.share_ocean');}
  private async captureShare(card:FeedCard):Promise<image.PixelMap> {
    let active=true,timer:number=-1;
    const work=this.getUIContext().getComponentSnapshot().createFromBuilder(()=>this.shareCard(card),400,true,{scale:1});
    const checked=work.then((pixels:image.PixelMap)=>{if(!active){pixels.release().catch(()=>{});throw new Error('图片准备超时');}return pixels;});
    const timeout=new Promise<image.PixelMap>((resolve,reject)=>{timer=setTimeout(()=>reject(new Error('图片准备超时')),15000);});
    try{return await Promise.race([checked,timeout]);}finally{active=false;clearTimeout(timer);}
  }
  private async exportShare(savePhoto:boolean):Promise<void> {
    if(this.shareBusy){return;}this.shareBusy=true;this.shareStage='正在生成…';const snapshot=this.shareSnapshot(),context=this.getUIContext().getHostContext() as common.UIAbilityContext;let pixels:image.PixelMap|undefined;
    try{this.getUIContext().getFocusController().clearFocus();pixels=await this.captureShare(snapshot);const path=await ShareExport.imageFile(context,pixels);await pixels.release();pixels=undefined;this.shareStage=savePhoto?'正在保存…':'正在打开分享…';if(savePhoto){const saved=await ShareExport.saveImage(context,path);this.toast(saved?'分享图片已保存到相册':'未保存图片');}else{await ShareExport.shareImage(context,path);}}
    catch(error){this.toast((error as Error).message||'图片导出未完成，请重试');}finally{try{await pixels?.release();}catch{}this.shareBusy=false;this.shareStage='';}
  }
  private prepareSync():void {this.feedEpoch++;this.feedItems=[];this.feedBusy=false;this.feedLikeBusy='';this.publishPending=undefined;this.publishOwner='';this.shareCaption='';this.shareBody='';this.captionCard=undefined;this.sync.init(this.getUIContext().getHostContext() as common.UIAbilityContext,this.session.user.id||'guest');this.syncSchedule=this.sync.options.schedule;this.syncDiaries=this.sync.options.diaries;this.syncMessage=this.session.user.id?'手动同步':'访客';this.updateSystemBars();this.loadAssistant();this.prepareReminders();}
  private async prepareReminders():Promise<void> {const owner=this.session.user.id||'guest',epoch=++this.reminderEpoch;this.remindersEnabled=false;this.reminderBusy=true;try{const enabled=await MobileReminders.init(this.getUIContext().getHostContext() as common.UIAbilityContext,owner);if(epoch!==this.reminderEpoch||owner!==(this.session.user.id||'guest')){return;}this.remindersEnabled=enabled;this.reminderDraft=MobileReminders.options();this.reminderMessage=enabled?'正在检查事项提醒…':'允许通知后，可为已安排的事项设置系统提醒。';if(enabled){await this.refreshReminders();}}catch{if(epoch===this.reminderEpoch){this.remindersEnabled=false;this.reminderMessage='提醒状态未能恢复，请在此重新启用';}}finally{if(epoch===this.reminderEpoch){this.reminderBusy=false;}}}
  private onActiveChanged():void {if(this.appActive&&this.ready){if(this.remindersEnabled){this.refreshReminders();}if(this.aiBusy){this.pollAi();}}else{this.clearAiTimer();if(this.ready&&this.assistantReady&&!this.aiBusy&&!this.aiPending.id){this.persistAssistant();}}}
  private clearAiTimer():void {if(this.aiTimer>=0){clearTimeout(this.aiTimer);this.aiTimer=-1;}}
  private resetAssistant():void {this.clearAiTimer();this.aiMessages=[];this.aiJob=new AiReceipt();this.aiResult=new AiResult();this.aiBusy=false;this.aiRejected=false;this.aiMessage='';this.aiApplied=false;this.canUndoAi=false;this.aiOwner='';this.aiSignature='';this.aiDisplayedId='';this.aiPending=new AssistantPending();this.aiImages=[];this.chatDraft='';this.assistantReady=true;this.assistantStorageMessage='';}
  private assistantRecord():AssistantRecord {const record=new AssistantRecord();record.owner=this.session.user.id||'guest';record.messages=this.aiMessages;record.job=this.aiJob;record.pending=JSON.parse(JSON.stringify(this.aiPending)) as AssistantPending;if(!record.pending.id){record.pending.prompt=this.chatDraft;record.pending.images=this.aiImages.length?this.aiImages:undefined;}record.baseSignature=this.aiSignature;record.displayedJobId=this.aiDisplayedId;record.applied=this.aiApplied;record.mode=this.mode;record.readContext=this.readAgenda;return record;}
  private persistAssistant(required:boolean=false):void {try{if(!this.assistantReady){throw new Error('请先处理无法读取的会话文件');}this.assistantStore.save(this.assistantRecord());this.conversations=this.assistantStore.list();this.conversationTitle=this.assistantStore.current().title;this.assistantStorageMessage='';}catch{this.assistantStorageMessage='会话未能保存，原文件保留，请检查空间后重试';if(required){throw new Error(this.assistantStorageMessage);}}}
  private loadAssistant():void {
    this.resetAssistant();
    try{const record=this.assistantStore.init(this.getUIContext().getHostContext() as common.UIAbilityContext,this.session.user.id||'guest');this.aiMessages=record.messages;this.aiJob=record.job;this.aiPending=record.pending;this.chatDraft=record.pending.prompt;this.aiImages=record.pending.images||[];this.conversations=this.assistantStore.list();this.conversationTitle=this.assistantStore.current().title;this.aiResult=record.job.result;this.aiSignature=record.baseSignature;this.aiDisplayedId=record.displayedJobId;this.aiApplied=record.applied;this.mode=record.mode;this.readAgenda=record.readContext;this.aiOwner=this.session.user.id;this.aiBusy=['queued','running'].includes(record.job.status);
      if(this.aiPending.id){this.chatDraft=this.aiPending.prompt;this.aiMessage='上次请求是否被接收尚未确认；可沿用原请求继续检查';}
      if(record.job.id&&this.session.user.id){this.processAi();}
    }catch(error){this.assistantReady=false;this.assistantStorageMessage=(error as Error).message||'助手会话无法读取，原文件已保留';}
  }
  private aiKind():string {return this.mode==='拆解任务'?'tasks':this.mode==='计划建议'?'plan':this.mode==='回顾'?'review':'chat';}
  private aiPrompt():string {if(this.chatDraft.trim()){return (this.mode==='日记润色'?'请将下面的真实记录润色成日记，保留事实，不编造经历。\n':this.mode==='分享配文'?'请根据下列内容和指定风格撰写简短自然的分享配文，不编造完成情况。\n':'')+this.chatDraft.trim();}if(this.aiImages.length){return '请理解图片内容，并根据我的需要提供帮助。';}return this.mode==='日记润色'?'请先询问我今天想记录的经历。':this.mode==='分享配文'?'请先询问我想分享的具体内容。':this.mode==='回顾'?'请根据记录回顾完成情况，给出具体且温和的改进建议。':this.mode==='计划建议'?'请根据我的事项给出可执行的计划建议，明确冲突与需要补充的信息。':'';}
  private async sendAi():Promise<void> {
    if(this.aiBusy){return;}if(!this.session.user.id){this.openAccount();this.cloudMessage='登录后即可使用智能助手';return;}
    if(!this.assistantReady){this.toast('请先开始新对话，原会话文件会另存保留');return;}
    if(this.aiPending.id){await this.submitPendingAi();return;}
    const prompt=this.aiPrompt();if(!prompt){this.toast('先写下想法，或者需要拆解的目标');return;}
    this.getUIContext().getFocusController().clearFocus();this.aiBusy=true;this.aiRejected=false;this.aiMessage='正在连接助手…';this.aiOwner=this.session.user.id;this.aiSignature=JSON.stringify(this.data);this.aiApplied=false;this.aiResult=new AiResult();this.aiJob=new AiReceipt();
    const owner=this.aiOwner,pending=new AssistantPending();pending.id=uid('ai');pending.kind=this.aiKind();pending.prompt=prompt;pending.history=[];pending.clock.now=Date.now();pending.clock.timezoneOffsetMinutes=-AppTime.offset(pending.clock.now)/60000;pending.images=this.aiImages.length?this.aiImages.slice():undefined;if(this.readAgenda){pending.context=clone(this.data);}
    try{pending.history=boundedHistory(this.aiMessages,JSON.stringify(pending));this.aiPending=pending;this.persistAssistant(true);const status=await this.cloud.aiStatus();if(!status.enabled){this.aiRejected=true;throw new Error('智能助手暂未开放，已保留本次内容；可修改或稍后继续');}
      if(owner!==this.session.user.id||owner!==this.aiOwner){return;}await this.submitPendingAi();
    }catch(error){if(owner===this.aiOwner){this.aiBusy=false;this.aiMessage=(error as Error).message||'请求未完成，请稍后重试';}}
  }
  private async submitPendingAi():Promise<void> {
    if(!this.aiPending.id){return;}const pending=this.aiPending,owner=this.aiOwner,id=pending.id;this.aiBusy=true;this.aiMessage='正在确认请求…';
    try{this.persistAssistant(true);const receipt=await this.cloud.aiCreate(pending.kind,pending.prompt,pending.id,pending.context,pending.history,pending.clock,pending.images);if(owner!==this.aiOwner||owner!==this.session.user.id||id!==this.aiPending.id){return;}const message=new AiMessage();message.role='user';message.content=pending.prompt;message.images=pending.images;this.aiMessages=this.aiMessages.concat([message]);this.aiJob=receipt;this.aiPending=new AssistantPending();this.aiImages=[];this.chatDraft='';this.persistAssistant();this.processAi();}
    catch(error){if(owner===this.aiOwner&&id===this.aiPending.id){this.aiBusy=false;this.aiRejected=error instanceof CloudFailure&&[400,413].includes(error.status);this.aiMessage=(error as Error).message||'接收结果未确认，请继续检查；原请求会被复用';}}
  }
  private editRejectedAiRequest():void {if(!this.aiRejected||!this.aiPending.id||this.aiBusy){return;}const previous=this.aiPending,draft=new AssistantPending();draft.kind=previous.kind;draft.prompt=previous.prompt;draft.images=previous.images;this.aiImages=previous.images||[];this.aiPending=draft;try{this.persistAssistant(true);this.chatDraft=previous.prompt;this.aiRejected=false;this.aiMessage='请求内容未被接收，请修改后重新发送';}catch{this.aiPending=previous;this.toast('修改状态未能保存，原请求保持不变');}}
  private processAi():void {
    if(this.aiOwner!==this.session.user.id){this.resetAssistant();return;}
    if(this.aiJob.status==='completed'){
      this.aiBusy=false;this.aiResult=this.aiJob.result;if(this.aiDisplayedId!==this.aiJob.id){const message=new AiMessage();message.role='assistant';message.content=this.aiResult.text;this.aiMessages=this.aiMessages.concat([message]);this.aiDisplayedId=this.aiJob.id;}this.aiMessage=planSize(this.aiResult)>0?`已准备 ${planSize(this.aiResult)} 项建议，确认后才会加入待办`:'回复已完成';this.persistAssistant();setTimeout(()=>this.scrollChatBottom(),100);return;
    }
    if(this.aiJob.status==='failed'||this.aiJob.status==='cancelled'){this.aiBusy=false;this.aiMessage=this.aiJob.status==='cancelled'?'已停止本次请求':this.aiJob.error.message||'助手暂时无法完成，请稍后再试';this.persistAssistant();return;}
    this.aiMessage=this.aiJob.status==='queued'?'请求已排队，可继续使用其它功能':'正在整理想法，可继续使用其它功能';this.clearAiTimer();if(this.appActive){this.aiTimer=setTimeout(()=>{this.aiTimer=-1;this.pollAi();},1800);}
  }
  private async pollAi():Promise<void> {if(!this.aiBusy||!this.aiJob.id){return;}const owner=this.aiOwner,id=this.aiJob.id;try{const receipt=await this.cloud.aiGet(id);if(owner!==this.aiOwner||owner!==this.session.user.id||id!==this.aiJob.id){return;}this.aiJob=receipt;this.processAi();}catch{if(owner===this.aiOwner&&id===this.aiJob.id){this.aiMessage='连接中断，正在等待重连；请求不会重复发送';this.clearAiTimer();if(this.appActive){this.aiTimer=setTimeout(()=>{this.aiTimer=-1;this.pollAi();},6000);}}}}
  private async cancelAi():Promise<void> {if(!this.aiBusy){return;}if(!this.aiJob.id){this.toast('请求正在提交，请稍候再停止');return;}const owner=this.aiOwner,id=this.aiJob.id;this.clearAiTimer();try{const receipt=await this.cloud.aiCancel(id);if(owner!==this.aiOwner||owner!==this.session.user.id||id!==this.aiJob.id){return;}this.aiJob=receipt;this.processAi();}catch{if(owner!==this.aiOwner||owner!==this.session.user.id||id!==this.aiJob.id){return;}this.aiMessage='停止尚未确认，请稍后重试';this.processAi();}}
  private newConversation():void {
    if(this.aiBusy||this.aiPending.id||this.aiPictureBusy){this.toast('请先完成或停止当前请求，再开始新对话');return;}
    try{this.persistAssistant(true);this.assistantStore.create();this.loadAssistant();this.panel='';this.tab=3;this.toast('已开始新对话');}catch(error){this.toast((error as Error).message);}
  }
  private openConversation(id:string):void {
    if(this.aiBusy||this.aiPending.id||this.aiPictureBusy){this.toast('请先完成或停止当前请求，再切换对话');return;}
    try{this.persistAssistant(true);this.assistantStore.open(id);this.loadAssistant();this.panel='';this.tab=3;}catch(error){this.toast((error as Error).message);}
  }
  private conversationRows():ConversationInfo[] {return this.conversations.filter((row:ConversationInfo)=>row.archived===this.showArchived&&row.title.toLowerCase().includes(this.conversationQuery.trim().toLowerCase()));}
  private conversationHistory():void {this.conversations=this.assistantStore.list();this.conversationQuery='';this.showArchived=false;this.showPanel('assistant-history','');}
  private editConversation(row:ConversationInfo,archive:boolean=false,pin:boolean=false):void {
    try{this.assistantStore.edit(row.id,row.title,archive?!row.archived:row.archived,pin?!row.pinned:row.pinned);this.conversations=this.assistantStore.list();}catch(error){this.toast((error as Error).message);}
  }
  private renameConversation(row:ConversationInfo):void {this.renameConversationId=row.id;this.renameConversationTitle=row.title;this.showPanel('assistant-rename');}
  private saveConversationName():void {
    const row=this.conversations.find((item:ConversationInfo)=>item.id===this.renameConversationId);if(!row){return;}
    try{this.assistantStore.edit(row.id,this.renameConversationTitle,row.archived,row.pinned);this.conversations=this.assistantStore.list();this.conversationTitle=this.assistantStore.current().title;this.back();}catch(error){this.toast((error as Error).message);}
  }
  private assistantPhotoMenu():void {
    if(this.aiBusy||this.aiPending.id||this.aiPictureBusy){return;}if(this.aiImages.length>=4){this.toast('每次可附加4张图片');return;}
    this.getUIContext().getPromptAction().showActionMenu({title:'添加图片',buttons:[{text:'拍照',color:this.teal()},{text:'从相册选择',color:this.teal()}]}).then((result)=>{if(result.index===0||result.index===1){this.addAssistantPhoto(result.index===0);}}).catch(()=>{});
  }
  private async addAssistantPhoto(takePhoto:boolean):Promise<void> {
    const owner=this.session.user.id||'guest',conversation=this.assistantStore.current().id;this.aiPictureBusy=true;
    try{const photo=await assistantImage(this.getUIContext().getHostContext() as common.UIAbilityContext,owner,takePhoto);
      if(photo&&owner===(this.session.user.id||'guest')&&conversation===this.assistantStore.current().id){this.aiImages=this.aiImages.concat([photo]);this.persistAssistant();}
    }catch(error){this.toast(takePhoto?'未能使用相机，可从相册选择图片':(error as Error).message||'图片读取失败');}finally{this.aiPictureBusy=false;}
  }
  private assistantCaptured(value:string):void {if(this.aiBusy||this.aiPending.id){return;}this.chatDraft=(this.chatDraft?this.chatDraft+'\n':'')+value;this.persistAssistant();}
  private selectedLooseTasks():MobileTask[] {const ids=new Set<string>(this.selectedBlocks().map((block:Block)=>block.taskId));return tasksOn(this.data,this.selectedDay).filter((task:MobileTask)=>!ids.has(task.id));}
  private scrollChatBottom():void {if(this.tab!==3||this.panel!==''){return;}try{this.chatScroller.scrollEdge(Edge.Bottom);}catch{}}
  private planTaskLabel(id:string):string {return /^new:\d+$/.test(id)?this.aiResult.tasks[Number(id.slice(4))]?.title||'新增事项':this.taskName(id);}
  private acceptAiTasks():void {
    if(this.aiApplied||planSize(this.aiResult)===0){return;}if(this.aiOwner!==this.session.user.id||this.aiSignature!==JSON.stringify(this.data)){this.toast('事项已变化，请重新生成提案');return;}
    try{const next=applyAssistantPlan(this.data,this.aiResult);const before=clone(this.data);
      if(this.save(next,`已加入 ${planSize(this.aiResult)} 项调整`)){this.aiApplied=true;this.aiUndo=before;this.aiUndoSignature=JSON.stringify(this.data);this.canUndoAi=true;this.persistAssistant();this.panel='';this.tab=1;}
    }catch(error){this.toast((error as Error).message||'提案内容无效，原事项保持不变');}
  }
  private undoAiTasks():void {if(this.aiUndoSignature!==JSON.stringify(this.data)){this.canUndoAi=false;this.toast('已有其它修改，不能直接撤销');return;}if(this.save(this.aiUndo,'已撤销本次提案')){this.aiApplied=false;this.aiMessage='本次提案已撤销';this.persistAssistant();}}
  private async login():Promise<void> {
    if(this.busy||this.syncWorking){return;}this.busy=true;this.cloudMessage='正在连接…';
    try{const next=await this.cloud.login(COURSE_ENDPOINT,this.username,this.password,this.registering);this.password='';this.registering=false;this.session=next;this.data=this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext,next.user.id);this.canUndo=false;this.headReady=false;this.history=[];this.query='';this.diary='';this.resetAssistant();this.prepareSync();this.cloudMessage='已登录；访客记录保留在本机，账户记录单独保存';this.toast('登录成功');}
    catch(error){this.cloudMessage=(error as Error).message||'连接失败，请稍后重试';if(this.session.user.id){this.ready=false;this.failure='账户本机文件无法读取，原文件已保留，请重试。';}}finally{this.busy=false;}
  }
  private openAccount():void {this.parentPanels.set('account',this.panel==='settings'?'settings':'');this.panel='account';this.emailStatus=new EmailStatus();this.emailStatusMessage='正在检查邮箱功能…';this.checkEmailStatus();}
  private async checkEmailStatus():Promise<void> {const epoch=++this.emailEpoch;try{const status=await this.cloud.emailStatus(COURSE_ENDPOINT);if(epoch!==this.emailEpoch||this.panel!=='account'){return;}this.emailStatus=status;this.emailStatusMessage=status.enabled?'':'邮箱功能暂未开放，用户名注册登录仍可用。';}catch{if(epoch===this.emailEpoch&&this.panel==='account'){this.emailStatus=new EmailStatus();this.emailStatusMessage='暂时无法检查邮箱功能，可继续使用用户名注册登录。';}}}
  private emailAvailable(purpose:string):boolean {return this.emailStatus.enabled&&Array.isArray(this.emailStatus.purposes)&&this.emailStatus.purposes.includes(purpose);}
  private openEmail(mode:string):void {if(!this.emailAvailable(mode)){this.toast('邮箱功能暂不可用');return;}if((mode==='bind')!==Boolean(this.session.user.id)){this.toast('账户状态已变化，请重新打开账户页');return;}this.password='';this.emailMode=mode;this.panel='email';}
  private useUsernameRegistration(username:string):void {this.getUIContext().getFocusController().clearFocus();this.username=username||this.username;this.password='';this.registering=true;this.cloudMessage='可先创建用户名账户，之后在账户页绑定邮箱。';this.panel='account';}
  private emailRegistered(next:CloudSession):void {try{this.session=next;this.username=next.user.username;this.registering=false;this.data=this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext,next.user.id);this.canUndo=false;this.headReady=false;this.history=[];this.query='';this.diary='';this.resetAssistant();this.prepareSync();this.cloudMessage='邮箱验证与注册完成；访客记录仍保留在本机';this.panel='account';this.toast('注册成功');}catch{this.ready=false;this.failure='账户记录暂时无法读取，原文件已保留，请重试。';}}
  private emailDone(mode:string):void {this.session=this.cloud.session;this.cloudMessage=mode==='bind'?'邮箱已绑定，可用于找回密码':'密码已重置，请使用原用户名和新密码登录';this.password='';this.registering=false;this.panel='account';this.toast(mode==='bind'?'邮箱绑定成功':'密码重置成功');}
  private async logout():Promise<void> {
    if(this.busy||this.syncWorking){return;}if(this.aiBusy){this.toast('请先在助手页停止当前请求，再退出账户');return;}this.busy=true;
    try{if(this.remindersEnabled){await MobileReminders.disable();this.remindersEnabled=false;}const revoked=await this.cloud.logout();this.session=new CloudSession();this.data=this.store.init(this.getUIContext().getHostContext() as common.UIAbilityContext);this.canUndo=false;this.headReady=false;this.history=[];this.syncPreview=new ManualSyncPreview();this.query='';this.diary='';this.resetAssistant();this.prepareSync();this.cloudMessage=revoked?'已退出，回到本机访客记录':'已清除本机登录；网络异常，服务端会话尚未确认退出';this.toast(this.cloudMessage);}
    catch{this.cloudMessage='退出未完成，请重试；本机记录保持原样';this.ready=false;this.failure=this.cloudMessage;}finally{this.busy=false;}
  }
  private openCloud():void {this.parentPanels.set('cloud',this.panel==='settings'?'settings':this.panel==='account'?'account':'');if(!this.session.user.id){this.openAccount();return;}this.panel='cloud';this.refreshCloud();}
  private async refreshCloud(older:boolean=false):Promise<void> {
    if(this.busy){return;}this.busy=true;this.cloudMessage='正在读取备份…';
    try{if(!older){this.cloudHead=await this.cloud.head();this.headReady=true;}const before=older&&this.history.length>0?this.history[this.history.length-1].revision:Number.MAX_SAFE_INTEGER;const page=await this.cloud.history(before);this.history=older?this.history.concat(page.items):page.items;this.moreHistory=page.items.length===20;this.session=this.cloud.session;this.cloudMessage=this.cloudHead.revision>0?`云端最新 v${this.cloudHead.revision}`:'还没有云端备份';}
    catch(error){this.cloudMessage=(error as Error).message||'暂时无法读取云端，请保留本机记录';}finally{this.busy=false;}
  }
  private selectedSyncScope():SyncScope {const scope=new SyncScope();scope.schedule=this.syncSchedule;scope.diaries=this.syncDiaries;return scope;}
  private syncKindLabel(kind:string):string {return kind==='push'?'云端备份':kind==='pull'?'覆盖同步':'兼容同步';}
  private async beginManualSync(kind:string,revision?:number):Promise<void> {
    if(this.busy||this.syncWorking){return;}if(!this.syncSchedule&&!this.syncDiaries){this.toast('请至少选择日程或日记');return;}this.busy=true;this.syncWorking=true;this.cloudMessage='正在准备预览…';const owner=this.session.user.id;
    try{const scope=this.selectedSyncScope(),preview=await this.sync.preview(kind,scope,this.cloud,clone(this.data),revision);if(owner!==this.session.user.id){return;}this.syncPreview=preview;this.session=this.cloud.session;this.panel='sync-preview';this.cloudMessage='';}catch(error){this.cloudMessage=(error as Error).message||'预览未能完成，本机与云端记录保持不变';}finally{this.busy=false;this.syncWorking=false;}
  }
  private async applyManualSync():Promise<void> {
    if(this.busy||this.syncWorking){return;}this.busy=true;this.syncWorking=true;
    try{const result=await this.sync.apply(this.syncPreview,this.cloud,()=>this.data,(next:MobileData)=>{this.store.restore(next);this.data=next;this.canUndo=false;this.canUndoAi=false;this.updateSystemBars();});this.session=this.cloud.session;this.syncMessage=result.message;this.cloudMessage=result.message;if(result.changed&&this.remindersEnabled){this.refreshReminders();}if(result.state==='applied'){this.panel='cloud';}this.toast(result.message);}catch(error){this.cloudMessage=(error as Error).message||'同步未完成，请重新预览后再试';this.toast(this.cloudMessage);}finally{this.busy=false;this.syncWorking=false;}
    if(this.panel==='cloud'){await this.refreshCloud();}
  }
  private complete(task:MobileTask):void {if(task.done){this.save(finishTask(this.data,task.id,5),'已恢复为待办');}else{this.ratingId=task.id;this.rating=5;this.panel='rating';}}
  private done():void {if(this.save(finishTask(this.data,this.ratingId,this.rating),'完成了一件事，辛苦了')){this.panel='';}}
  private showPanel(name:string,parent:string=this.panel):void {this.parentPanels.set(name,parent);this.panel=name;}
  private diaryOpen():void {this.diaryDay=dayStart(Date.now());this.readDiary();this.panel='diary';}
  private readDiary():void {this.diary=this.data.diaries.find((d:Diary)=>d.day===dateKey(this.diaryDay))?.text||'';}
  private pickDiaryDay():void {
    this.getUIContext().getFocusController().clearFocus();
    CalendarPickerDialog.show({selected:AppTime.view(this.diaryDay),onAccept:(result:Date)=>{
      const selected=dayStart(AppTime.fromView(result));if(selected===this.diaryDay){return;}
      const original=this.data.diaries.find((d:Diary)=>d.day===dateKey(this.diaryDay))?.text||'';
      const change=()=>{this.diaryDay=selected;this.readDiary();};
      if(this.diary!==original){this.getUIContext().showAlertDialog({title:'保存当前日记？',message:'切换日期前，可以先保存当前内容。',primaryButton:{value:'暂不切换',action:()=>{}},secondaryButton:{value:'保存并切换',action:()=>{if(this.writeDiary()){change();}}}});}else{change();}
    }});
  }
  private writeDiary():boolean {const next=clone(this.data),key=dateKey(this.diaryDay),found=next.diaries.find((d:Diary)=>d.day===key);if(found){found.text=this.diary;}else{const d=new Diary();d.day=key;d.text=this.diary;d.timeZone=AppTime.zone;next.diaries.push(d);}return this.save(next,'日记已保存');}
  private saveDiary():void {if(this.writeDiary()){this.panel='';}}
  private editProfile():void {this.draftNickname=this.data.nickname||'';this.draftMotto=this.data.motto||'';this.showPanel('profile-edit');}
  private saveProfile():void {const next=clone(this.data);next.nickname=this.draftNickname.trim();next.motto=this.draftMotto.trim();if(this.save(next,'个人资料已保存')){this.back();}}
  private openZone():void {this.zoneChoice=this.data.timeZone||AppTime.systemZone;this.zonePolicy=this.data.zonePolicy||'absolute';this.showPanel('timezone');}
  private zones():string[] {return zoneIds.includes(AppTime.systemZone)?zoneIds:[AppTime.systemZone,...zoneIds];}
  private zoneNames():string[] {return zoneIds.includes(AppTime.systemZone)?zoneLabels:['设备时区',...zoneLabels];}
  private saveZone():void {
    const signature=JSON.stringify(this.data),zone=this.zoneChoice,policy=this.zonePolicy;
    this.getUIContext().showAlertDialog({title:'应用时区设置？',message:policy==='absolute'?'保留事项和安排的实际时刻，按照所选时区显示。':'未完成事项的未来截止与安排将保持钟面时间。已完成记录保留实际时刻。',primaryButton:{value:'取消',action:()=>{}},secondaryButton:{value:'应用',action:()=>{
      if(JSON.stringify(this.data)!==signature){this.toast('记录已有变化，请重新确认');return;}
      try{const next=changeTimeZone(this.data,zone,policy);if(this.save(next,'时区已更新')){this.selectedDay=dayStart(Date.now());this.month=this.selectedDay;this.back();}}catch(error){this.toast((error as Error).message||'时区未改变');}
    }}});
  }
  private openTodayWork():void {
    this.workParent='';this.workScope='today';this.workDate=dayStart(Date.now());
    const hours=workHoursOn(this.data,this.workDate);
    this.workDaily=new WorkHours(hours.start,hours.end);this.panel='work';
  }
  private workOpen():void {
    this.workParent=this.panel;this.workScope='default';
    this.workDaily=new WorkHours(this.data.workStart,this.data.workEnd);
    this.workWeek=[0,1,2,3,4,5,6].map((day:number)=>workHoursFor(this.data,day));
    this.workWeekdays=[this.workWeek[1],this.workWeek[6]];
    this.workMode=this.data.workWindows?.length===7?2:this.data.workWindows?.length===2?1:0;
    this.panel='work';
  }
  private workRows():number[] {return this.workScope==='today'||this.workMode===0?[0]:this.workMode===1?[0,1]:[0,1,2,3,4,5,6];}
  private workRowLabel(group:number):string {return this.workScope==='today'?'今天':this.workMode===2?this.weekLabels[group]:this.workMode===1?['工作日','休息日'][group]:'每天';}
  private workDraft(group:number=0):WorkHours {
    if(this.workScope==='today'){return this.workDaily;}
    if(this.workMode===2){return this.workWeek[(group+1)%7];}
    if(this.workMode===1){return this.workWeekdays[group];}
    return this.workDaily;
  }
  private updateWorkDraft(hours:WorkHours,group:number):void {
    if(this.workScope==='today'){this.workDaily=hours;}
    else if(this.workMode===2){const week=this.workWeek.slice();week[(group+1)%7]=hours;this.workWeek=week;}
    else if(this.workMode===1){const days=this.workWeekdays.slice();days[group]=hours;this.workWeekdays=days;}
    else {this.workDaily=hours;}
  }
  private workLabel():string {
    const hours=workHoursOn(this.data,Date.now());
    return `${minuteText(hours.start)}–${minuteText(hours.end)}`;
  }
  private pickWorkTime(isEnd:boolean,group:number=0):void {
    const hours=this.workDraft(group);
    if(isEnd){
      if(hours.start===1439){return;}
      this.pickTime(hours.start+1,hours.start+1,1439,(end:number)=>this.updateWorkDraft(new WorkHours(hours.start,end),group),this.workDate);
      return;
    }
    this.pickTime(hours.start,0,1438,(start:number)=>this.updateWorkDraft(new WorkHours(start,Math.max(hours.end,start+1)),group),this.workDate);
  }
  private saveWork():void {
    const next=clone(this.data);
    if(this.workScope==='today'){
      const entry=new WorkDate();entry.day=dateKey(this.workDate);entry.start=this.workDaily.start;entry.end=this.workDaily.end;
      next.workDates=(next.workDates||[]).filter((item:WorkDate)=>item.day>entry.day);next.workDates.push(entry);
    }else{
      next.workStart=this.workDaily.start;next.workEnd=this.workDaily.end;
      next.workWindows=this.workMode===2?this.workWeek:this.workMode===1?this.workWeekdays:undefined;
    }
    if(this.save(next,this.workScope==='today'?'今天的行动时间已保存':'默认行动时间已保存')){this.panel=this.workParent==='settings'?'settings':'';}
  }
  private resetTodayWork():void {
    const next=clone(this.data);next.workDates=(next.workDates||[]).filter((entry:WorkDate)=>entry.day!==dateKey(this.workDate));
    if(this.save(next,'已恢复默认行动时间')){this.panel='';}
  }
  private dateLabel():string {const d=AppTime.view(Date.now());return `${d.getMonth()+1}月${d.getDate()}日 星期${['日','一','二','三','四','五','六'][d.getDay()]}`;}
  private shiftMonth(delta:number):void {const d=AppTime.view(this.month);d.setDate(1);d.setMonth(d.getMonth()+delta);this.month=AppTime.fromView(d);}
  private monthLabel():string {const d=AppTime.view(this.month);return `${d.getFullYear()}年${d.getMonth()+1}月`;}
  private weekDays():number[] {const start=addDays(dayStart(this.selectedDay),-((AppTime.view(this.selectedDay).getDay()+6)%7));return [0,1,2,3,4,5,6].map((offset:number)=>addDays(start,offset));}
  private selectedBlocks():Block[] {const start=dayStart(this.selectedDay),end=addDays(start,1);return this.data.blocks.filter((b:Block)=>b.start<end&&b.end>start).sort((a:Block,b:Block)=>a.start-b.start);}
  private dayCount(day:number,status:number):number {return tasksOn(this.data,day).filter((t:MobileTask)=>status===0?t.done:status===1?(!t.done&&t.deadline>0&&t.deadline<Date.now()):(!t.done&&!(t.deadline>0&&t.deadline<Date.now()))).length;}
  private timeAt(minute:number,day:number):Date {
    const date=AppTime.view(day);
    date.setHours(Math.floor(minute/60),minute%60,0,0);
    return date;
  }
  private pickTime(selected:number,start:number,end:number,accept:(value:number)=>void,day:number=Date.now()):void {
    this.getUIContext().getFocusController().clearFocus();
    this.getUIContext().showTimePickerDialog({
      selected:this.timeAt(Math.min(end,Math.max(selected,start)),day),start:this.timeAt(start,day),end:this.timeAt(end,day),
      useMilitaryTime:true,onAccept:(result:TimePickerResult)=>{
        const minute=(result.hour??0)*60+(result.minute??0);
        if(minute>=start&&minute<=end){accept(minute);}
      }
    });
  }
  private setTaskDateTime(reservation:boolean,value:number):void {
    if(reservation){this.draftReservation=value;}else{this.draftDeadline=value;}
  }
  private taskDateValue(reservation:boolean):number {return reservation?this.draftReservation:this.draftDeadline;}
  private pickTaskDate(reservation:boolean):void {
    const value=reservation?this.draftReservation:this.draftDeadline;
    const selected=value|| (reservation?Date.now():addDays(Date.now(),1));
    this.getUIContext().getFocusController().clearFocus();
    CalendarPickerDialog.show({selected:AppTime.view(selected),onAccept:(result:Date)=>{
      const previous=AppTime.view(selected);
      const minutes=value?previous.getHours()*60+previous.getMinutes():
        reservation?workHoursOn(this.data,AppTime.fromView(result)).start:18*60;
      result.setHours(Math.floor(minutes/60),minutes%60,0,0);
      try{this.setTaskDateTime(reservation,AppTime.fromView(result));}catch(error){this.toast((error as Error).message);}
    }});
  }
  private pickTaskTime(reservation:boolean):void {
    const date=AppTime.view(reservation?this.draftReservation:this.draftDeadline);
    this.pickTime(date.getHours()*60+date.getMinutes(),0,1439,(value:number)=>{
      date.setHours(Math.floor(value/60),value%60,0,0);
      if(date.getHours()*60+date.getMinutes()===value){try{this.setTaskDateTime(reservation,AppTime.fromView(date));}catch(error){this.toast((error as Error).message);}}
      else {this.toast('请选择该日期可用的时间');}
    },AppTime.fromView(date));
  }
  private back():void {if(this.busy){this.toast('正在处理，请稍候');return;}this.password='';this.panel=this.panel==='work'?this.workParent:this.panel==='sync-preview'?'cloud':this.panel==='email'?'account':this.parentPanels.get(this.panel)||'';this.data=clone(this.data);}
  onBackPress():boolean {if(this.keyboardVisible){this.getUIContext().getFocusController().clearFocus();return true;}if(this.panel!==''){this.back();return true;}if(this.tab!==0){this.tab=0;return true;}return false;}

  private captionStyles():string[] {return this.shareStyle===1?['温暖鼓励','生活随笔','轻快可爱']:this.shareStyle===2?['安静诗意','晚间回顾','简短晚安']:['清新自然','元气可爱','简洁记录'];}
  private generateCaption():void {
    if(this.aiBusy||this.aiPending.id){this.toast('请先完成当前助手请求');return;}
    if(!this.session.user.id){this.openAccount();return;}
    const card=this.shareSnapshot(),style=this.captionStyles()[this.captionStyle];
    try{this.persistAssistant(true);this.assistantStore.create();this.loadAssistant();}catch(error){this.toast((error as Error).message);return;}this.panel='';this.tab=3;this.captionCard=card;this.mode='分享配文';this.readAgenda=false;this.aiImages=[];
    this.chatDraft=`请只给出一段可直接编辑的分享配文，最多120字，不要列出多个版本。图片是蓝色鲸鱼娘与${['清新海面','温暖晨光','静谧星夜'][card.style]}，配文风格为「${style}」。只依据下面的卡片事实，不虚构完成、排名或经历。标题：${card.title}。卡片内容：${card.lines.join('；')}。`;
    this.persistAssistant();this.sendAi();
  }
  private openFeed():void {this.showPanel('feed','');this.feedItems=[];this.feedNext=0;this.refreshFeed();}
  private async refreshFeed(more:boolean=false):Promise<void> {
    if(this.feedBusy){return;}this.feedBusy=true;this.feedMessage='';const owner=this.session.user.id,epoch=this.feedEpoch;
    try{const page=await this.cloud.feedPage(more?this.feedNext:0);if(owner!==this.session.user.id||epoch!==this.feedEpoch){return;}
      this.feedItems=more?this.feedItems.concat(page.items.filter((row:FeedPost)=>!this.feedItems.some((old:FeedPost)=>old.id===row.id))):page.items;this.feedNext=page.nextBefore;
      if(this.feedItems.length===0){this.feedMessage='还没有分享，写下今天的小进步吧。';}
    }catch(error){if(epoch===this.feedEpoch){this.feedMessage=(error as Error).message||'暂时无法读取分享';}}finally{if(epoch===this.feedEpoch){this.feedBusy=false;}}
  }
  private async likePost(post:FeedPost):Promise<void> {
    if(!this.session.user.id){this.openAccount();return;}if(this.feedLikeBusy){return;}this.feedLikeBusy=post.id;const owner=this.session.user.id;
    try{const next=await this.cloud.feedLike(post.id,!post.liked);if(owner===this.session.user.id){this.feedItems=this.feedItems.map((item:FeedPost)=>item.id===next.id?next:item);}}
    catch(error){this.toast((error as Error).message);}finally{this.feedLikeBusy='';}
  }
  private deletePost(post:FeedPost):void {
    this.getUIContext().showAlertDialog({title:'删除这条分享？',message:post.card.title,primaryButton:{value:'取消',action:()=>{}},secondaryButton:{value:'删除',action:()=>this.removePost(post.id)}});
  }
  private async removePost(id:string):Promise<void> {const owner=this.session.user.id;try{await this.cloud.feedDelete(id);if(owner===this.session.user.id){this.feedItems=this.feedItems.filter((item:FeedPost)=>item.id!==id);this.toast('分享已删除');}}catch(error){this.toast((error as Error).message);}}
  private previewFeedPost():void {
    if(!this.session.user.id){this.openAccount();return;}
    try{const old=this.feedPending.init(this.getUIContext().getHostContext() as common.UIAbilityContext,this.session.user.id);
      if(old){this.publishPending=old;}else{const draft=new FeedDraft();draft.requestId=uid('feed');draft.author=this.data.nickname||'鲸友';draft.card=this.shareSnapshot();draft.caption=this.shareCaption.trim();this.publishPending=draft;}
      this.publishOwner=this.session.user.id;this.showPanel('feed-publish','share');
    }catch(error){this.toast((error as Error).message);}
  }
  private async publishFeed():Promise<void> {
    if(this.shareBusy||!this.publishPending){return;}if(this.publishOwner!==this.session.user.id){this.toast('账户已变化，请重新预览分享');return;}const draft=this.publishPending,owner=this.session.user.id;this.shareBusy=true;
    try{this.feedPending.save(draft);const post=await this.cloud.feedPublish(draft);if(owner!==this.session.user.id){return;}
      this.feedPending.clear();this.publishPending=undefined;this.feedItems=[post];this.feedNext=0;this.panel='feed';this.parentPanels.set('feed','');this.feedMessage='已发布';this.toast('已分享到鲸日分享');this.refreshFeed();
    }catch(error){this.toast((error as Error).message||'结果未确认，可重试同一次发布');}finally{this.shareBusy=false;}
  }
  @Builder
  private chip(options:ChipOptions) {
    Button(options.label).type(ButtonType.Normal).fontSize(13).fontWeight(options.active?FontWeight.Medium:FontWeight.Normal).fontColor(options.active?this.teal():this.muted()).backgroundColor(options.active?this.tint():this.surface()).borderRadius(this.radius(12)).height(38).padding({left:15,right:15}).onClick(()=>options.action())
  }
  @Builder
  private section(options:SectionOptions) {
    Row(){Text(options.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1);Text(options.detail||'').fontSize(12).fontColor(this.muted()).maxLines(2).textAlign(TextAlign.End)}.width('100%').margin({top:10,bottom:3})
  }
  @Builder
  private empty(options:EmptyOptions) {
    Column({space:7}){
      Text(options.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.ink())
      if(options.subtitle){Text(options.subtitle).fontSize(12).fontColor(this.muted()).lineHeight(20)}
    }.alignItems(HorizontalAlign.Start).width('100%').padding(18).backgroundColor(this.surface()).borderRadius(this.radius(16)).border({width:1,color:this.line(),radius:this.radius(12)})
  }
  @Builder
  private stat(value:string,label:string) {Column({space:5}){Text(value).fontSize(27).fontWeight(FontWeight.Bold).fontColor(this.ink());Text(label).fontSize(12).fontColor(this.muted())}.alignItems(HorizontalAlign.Start).layoutWeight(1)}
  private selectOptions(labels:string[]):SelectOption[] {
    return labels.map((label:string):SelectOption=>({value:label}));
  }
  @Builder
  private selectField(options:SelectFieldOptions) {
    Select(this.selectOptions(options.labels)).selected(Math.max(0,options.selected)).value(options.labels[Math.max(0,options.selected)])
      .height(44).width('100%').borderRadius(this.radius(12)).backgroundColor(this.surface()).border({width:1,color:this.line(),radius:this.radius(12)})
      .font({size:14,weight:FontWeight.Medium}).fontColor(this.ink()).optionFontColor(this.ink())
      .optionBgColor(this.surface()).selectedOptionBgColor(this.tint()).selectedOptionFontColor(this.ink())
      .menuBackgroundColor(this.surface()).enabled(options.enabled??true).onSelect((index:number)=>options.change(index)).id(options.id)
  }
  @Builder
  private header() {
    Row({space:12}){
      Column({space:4}){Text('鲸办 WhaleDo').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.ink());Text(this.dateLabel()).fontSize(11).fontColor(this.muted())}.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Column({space:4}){Text('行动时间').fontSize(11).fontColor(this.teal());Text(this.workLabel()).fontSize(11).fontColor(this.muted())}
        .padding({left:12,right:12,top:8,bottom:8}).backgroundColor(this.surface()).borderRadius(this.radius(12))
        .border({width:1,color:this.line(),radius:this.radius(12)}).onClick(()=>this.openTodayWork()).id('worktime')
    }.width('100%').padding({top:14,bottom:14,left:22,right:22})
  }
  @Builder
  private taskCard(task:MobileTask) {
    Row({space:12}){
      Checkbox({name:task.id}).select(task.done).selectedColor(this.teal()).width(22).height(22).onChange((value:boolean)=>{if(value!==task.done){this.complete(task);}}).id(`complete-${task.id}`)
      Column({space:7}){
        Text(task.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(task.done?this.muted():this.ink()).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis})
        Text(`${task.category} · ${this.taskDuration(task)}${this.taskDeadline(task)}${task.repeat&&task.repeat!=='none'?` · ${this.repeatLabel(task.repeat)}`:''}`).fontSize(11).fontColor(!task.done&&task.deadline>0&&task.deadline<Date.now()?'#BE4D4A':this.muted()).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(()=>this.editTask(task))
      if(task.priority>=4&&!task.done){Text('重要').fontSize(10).fontColor(this.dark()?'#E5B899':'#9B6446').padding({left:7,right:7,top:5,bottom:5}).backgroundColor(this.dark()?'#4D3C32':'#F5EADF').borderRadius(this.radius(7)).onClick(()=>this.editTask(task))}
    }.width('100%').padding(17).backgroundColor(this.surface()).borderRadius(this.radius(18)).border({width:1,color:this.line(),radius:this.radius(12)})
  }
  @Builder
  private timeCard(block:Block) {
    Row({space:12}){
      Column({space:5}){Text(this.allDayBlock(block)?'全天':clock(block.start)).fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.ink());Text(this.allDayBlock(block)?`${AppTime.view(block.start).getMonth()+1}/${AppTime.view(block.start).getDate()}`:dateKey(block.start)!==dateKey(block.end)?'跨日':clock(block.end)).fontSize(11).fontColor(this.muted())}.width(44)
      Row(){Column({space:7}){Text(this.taskName(block.taskId)).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.ink());Text(this.blockDetail(block)).fontSize(12).fontColor(this.muted()).lineHeight(19)}.alignItems(HorizontalAlign.Start).layoutWeight(1);Text(block.done?'✓':'●').fontColor(this.teal())}.layoutWeight(1).padding(17).backgroundColor(this.tint()).borderRadius(this.radius(16))
    }.width('100%').onClick(()=>{const t=this.data.tasks.find((item:MobileTask)=>item.id===block.taskId);if(t){this.editTask(t);}})
  }
  @Builder
  private today() {
    Scroll(){Column({space:14}){
      Stack({alignContent:Alignment.TopEnd}){
        Image($r('app.media.whaledo_mascot')).sourceSize({width:512,height:512}).width(124).height(150).objectFit(ImageFit.Contain).opacity(0.98).margin({top:8,right:0})
        Column({space:18}){
          Row({space:14}){
            Column({space:7}){Text('给今天，\n留一点从容').fontSize(24).lineHeight(34).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');Text('一件一件，慢慢完成。').fontSize(12).fontColor('#DDEDF3')}.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }.width('100%')
          Row({space:9}){Image(this.avatarSource()).sourceSize({width:256,height:256}).width(28).height(28).objectFit(ImageFit.Cover).borderRadius(14).border({width:1,color:'#66FFFFFF',radius:14}).onClick(()=>this.avatarMenu()).accessibilityText('更换头像').id('today-avatar');Text('今日概览').fontSize(12).fontColor('#DDEDF3')}.width('100%')
          Row(){this.heroStat({value:String(this.pending().length),label:'待办事项'});this.heroStat({value:String(this.todayBlocks().length),label:'今日时段'});this.heroStat({value:String(this.completed().length),label:'累计完成'})}.width('100%')
          if(activeTasks(this.data).length>0){Progress({value:this.completed().length,total:activeTasks(this.data).length,type:ProgressType.Linear}).color('#FFFFFF').backgroundColor('#33FFFFFF').width('100%')}
        }.width('100%').padding(22)
      }.width('100%').backgroundColor(themeColors(this.dark(),this.data.tone).hero).borderRadius(this.radius(24)).clip(true).id('today-hero')
      Row({space:10}){Button('＋ 快速记下').type(ButtonType.Normal).layoutWeight(1).height(44).borderRadius(this.radius(12)).backgroundColor(this.primary()).fontColor(this.onPrimary()).fontSize(14).onClick(()=>this.newTask()).id('quick-capture');Button('自动安排').type(ButtonType.Normal).layoutWeight(1).height(44).borderRadius(this.radius(12)).backgroundColor(this.tint()).border({width:1,color:this.line(),radius:this.radius(12)}).fontColor(this.ink()).fontSize(14).onClick(()=>this.plan()).id('arrange')}.width('100%')
      if(this.canUndo){Button('撤销刚才的安排').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.confirmUndo()).id('plan-undo')}
      if(this.canUndoAi){Button('撤销刚才的 AI 提案').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.undoAiTasks()).id('ai-undo-today')}
      this.section({title:'今日安排',detail:`${this.todayMinutes()} 分钟`})
      if(this.todayBlocks().length===0){this.empty({title:'暂无安排'})}
      ForEach(this.todayBlocks(),(block:Block)=>{this.timeCard(block)},(block:Block)=>block.id)
      this.section({title:'收集箱',detail:`${this.inbox().length} 项待整理`})
      if(this.inbox().length===0){this.empty({title:'暂无待整理事项'})}
      ForEach(this.inbox().slice(0,5),(task:MobileTask)=>{this.taskCard(task)},(task:MobileTask)=>task.id)
      Row({space:12}){Image($r('app.media.whaledo_mascot')).sourceSize({width:512,height:512}).width(50).height(55).objectFit(ImageFit.Contain);Column({space:5}){Text('鲸日分享').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.ink());Text('看看彼此的小进步').fontSize(12).fontColor(this.muted())}.alignItems(HorizontalAlign.Start).layoutWeight(1);Text('›').fontSize(24).fontColor(this.teal())}.width('100%').padding(17).backgroundColor(this.surface()).borderRadius(this.radius(18)).onClick(()=>this.openFeed()).id('feed-open')
      Blank().height(76)
    }.width('100%').padding({left:22,right:22})}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private todo() {
    Column({space:12}){
      Row(){Text('待办').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1);this.chip({label:'自动安排',active:true,action:()=>this.plan()})}.width('100%')
      TextInput({placeholder:'搜索标题或备注',text:this.query}).borderRadius(this.radius(12)).fontSize(14).height(44).backgroundColor(this.surface()).fontColor(this.ink()).placeholderColor(this.muted()).onChange((text:string)=>this.query=text).id('task-search')
      Row({space:8}){Column(){this.selectField({labels:['清单','日程'],selected:this.agenda?1:0,id:'todo-view',change:(index:number)=>this.agenda=index===1})}.width(112);Blank();Text('已完成').fontSize(12).fontColor(this.muted());Toggle({type:ToggleType.Switch,isOn:this.showDone}).selectedColor(this.teal()).onChange((value:boolean)=>this.showDone=value).id('show-done')}.width('100%')
      if(this.agenda){this.dayBar()}
      Text(`${this.rows().length} 件事`).fontSize(12).fontColor(this.muted()).width('100%').id('task-count')
      if(this.canUndoAi){Button('撤销刚才的 AI 提案').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.undoAiTasks()).id('ai-undo-todo')}
      Scroll(){Column({space:10}){if(this.rows().length===0){this.empty({title:this.query?'无搜索结果':'暂无事项'})}ForEach(this.rows(),(task:MobileTask)=>{this.taskCard(task);ForEach(this.data.blocks.filter((b:Block)=>b.taskId===task.id).slice(0,4),(block:Block)=>{Text(this.blockListLabel(block)).fontSize(12).fontColor(this.teal()).width('100%').padding({left:14,bottom:2})},(block:Block)=>block.id)},(task:MobileTask)=>task.id);Blank().height(80)}.width('100%')}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
    }.width('100%').layoutWeight(1).padding({left:20,right:20})
  }
  private pickCalendarDay():void {
    CalendarPickerDialog.show({selected:AppTime.view(this.selectedDay),onAccept:(date:Date)=>{
      this.selectedDay=dayStart(AppTime.fromView(date));this.month=this.selectedDay;
    }});
  }
  @Builder
  private dayBar() {Row(){Button('‹').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(23).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.selectedDay=addDays(this.selectedDay,-1));Button(dateKey(this.selectedDay)).type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(14).fontColor(this.ink()).layoutWeight(1).backgroundColor(this.surface()).onClick(()=>this.pickCalendarDay()).id('pick-calendar-day');Button('›').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(23).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.selectedDay=addDays(this.selectedDay,1));Button('今天').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.selectedDay=dayStart(Date.now()))}.width('100%')}
  @Builder
  private calendar() {
    Scroll(){Column({space:14}){
      this.section({title:'日历'})
      Row({space:12}){
        Column(){this.selectField({labels:['月历','一周','日程'],selected:this.calendarViews.indexOf(this.calendarView),id:'calendar-view',change:(index:number)=>this.calendarView=this.calendarViews[index]})}.layoutWeight(1)
        Button('导入系统日历').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).height(44)
          .borderRadius(this.radius(12)).onClick(()=>{this.openCalendarImport();}).id('calendar-import-open')
      }.width('100%')
      if(this.calendarView==='month'){
      Row(){Button('‹').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(26).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.shiftMonth(-1));Button(this.monthLabel()).type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1).backgroundColor(Color.Transparent).onClick(()=>this.pickCalendarDay());Button('›').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(26).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.shiftMonth(1))}.width('100%')
      Row(){ForEach(['一','二','三','四','五','六','日'],(day:string)=>{Text(day).layoutWeight(1).fontSize(12).fontColor(this.muted()).textAlign(TextAlign.Center)},(day:string)=>day)}.width('100%')
      Grid(){ForEach(monthCells(this.month),(day:number)=>{
        GridItem(){Column({space:5}){Text(String(AppTime.view(day).getDate())).fontSize(14).fontColor(dateKey(day)===dateKey(this.selectedDay)?this.onPrimary():AppTime.view(day).getMonth()===AppTime.view(this.month).getMonth()?this.ink():this.muted());Row({space:3}){if(this.dayCount(day,0)>0){Circle().width(4).height(4).fill('#27845B')}if(this.dayCount(day,1)>0){Circle().width(4).height(4).fill('#BE4D4A')}if(this.dayCount(day,2)>0){Circle().width(4).height(4).fill('#B98515')}}.height(5)}.width('100%').height(43).justifyContent(FlexAlign.Center).borderRadius(this.radius(12)).backgroundColor(dateKey(day)===dateKey(this.selectedDay)?this.primary():Color.Transparent).onClick(()=>this.selectedDay=day).id(`date-${dateKey(day)}`)}
      },(day:number)=>String(day))}.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(3).height(274).width('100%')
      Row({space:16}){Text('● 完成').fontSize(12).fontColor('#27845B');Text('● 逾期').fontSize(12).fontColor('#BE4D4A');Text('● 待办').fontSize(12).fontColor('#B98515')}.width('100%').justifyContent(FlexAlign.Center)
      }else if(this.calendarView==='week'){
        Row(){Button('‹').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.selectedDay=addDays(this.selectedDay,-7));Text(`${dateKey(this.weekDays()[0])} 起`).fontSize(14).fontColor(this.ink()).layoutWeight(1).textAlign(TextAlign.Center);Button('›').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.selectedDay=addDays(this.selectedDay,7))}.width('100%')
        Row({space:4}){ForEach(this.weekDays(),(day:number,index:number)=>{Column({space:9}){Text(['一','二','三','四','五','六','日'][index]).fontSize(11).fontColor(dateKey(day)===dateKey(this.selectedDay)?this.onPrimary():this.muted());Text(String(AppTime.view(day).getDate())).fontSize(17).fontWeight(FontWeight.Medium).fontColor(dateKey(day)===dateKey(this.selectedDay)?this.onPrimary():this.ink());Text(String(tasksOn(this.data,day).length)).fontSize(10).fontColor(dateKey(day)===dateKey(this.selectedDay)?this.onPrimary():this.muted())}.layoutWeight(1).height(92).justifyContent(FlexAlign.Center).borderRadius(this.radius(13)).backgroundColor(dateKey(day)===dateKey(this.selectedDay)?this.primary():this.surface()).onClick(()=>this.selectedDay=day)},(day:number)=>String(day))}.width('100%')
      }else{this.dayBar()}
      this.section({title:dateKey(this.selectedDay),detail:`${tasksOn(this.data,this.selectedDay).length} 件事`})
      ForEach(this.selectedBlocks(),(block:Block)=>{this.timeCard(block)},(block:Block)=>`${block.id}:${block.start}:${block.end}:${block.done}`)
      if(tasksOn(this.data,this.selectedDay).length===0){this.empty({title:'当天暂无日程'})}
      ForEach(this.selectedLooseTasks(),(task:MobileTask)=>{this.taskCard(task)},(task:MobileTask)=>`${task.id}:${task.title}:${task.done}:${task.minutes}:${task.deadline}`)
      Blank().height(80)
    }.width('100%').padding({left:20,right:20})}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private assistant() {
    this.assistantContent()
  }
  @Builder
  private assistantContent() {
    Column({space:this.keyboardVisible&&this.viewportHeight<400?4:12}){
      Row(){Button('历史').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(this.tint()).height(40).fontSize(13).onClick(()=>this.conversationHistory()).id('assistant-history');Text(this.conversationTitle).fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.ink()).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).layoutWeight(1).margin({left:10});Button('新对话').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(this.surface()).fontSize(13).height(40).onClick(()=>this.newConversation()).id('assistant-new')}.width('100%').padding({top:this.keyboardVisible&&this.viewportHeight<400?4:22,bottom:5})
      Scroll(this.chatScroller){Column({space:14}){
        if(this.assistantStorageMessage){Text(this.assistantStorageMessage).fontSize(12).fontColor(this.dark()?'#E8A9A2':'#B65C55').lineHeight(21).width('100%');Button('重试读取或保存').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>{if(this.assistantReady){this.persistAssistant();}else{this.loadAssistant();}})}
        if(this.aiMessages.length===0&&!this.aiPending.id&&this.viewportHeight>=550){
          Text('开始新对话').fontSize(21).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%').margin({top:22,bottom:10})
          Row({space:9}){Button('拆解一个目标').type(ButtonType.Normal).layoutWeight(1).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(13)).height(45).onClick(()=>{this.mode='拆解任务';this.chatDraft='帮我把这个目标拆成可执行的小任务：';});Button('预览本地安排').type(ButtonType.Normal).layoutWeight(1).fontSize(12).fontColor(this.teal()).backgroundColor(this.surface()).borderRadius(this.radius(13)).height(45).onClick(()=>this.plan()).id('assistant-local-plan')}.width('100%')
        }
        ForEach(this.aiMessages,(message:AiMessage,index:number)=>{
          Column({space:8}){Text(message.role==='user'?'我':'鲸办助手').fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.teal());if(message.images?.length){Row({space:8}){ForEach(message.images,(photo:string)=>{Image(photo).width(80).height(80).objectFit(ImageFit.Cover).borderRadius(this.radius(12))},(photo:string,index:number)=>`${index}:${photo.slice(-128)}`)}.width('100%')}Text(message.content).fontSize(15).fontColor(this.ink()).lineHeight(25).copyOption(CopyOptions.LocalDevice).width('100%');if(message.role==='assistant'){Button(this.mode==='分享配文'?'使用这段配文':'做成分享卡片').type(ButtonType.Normal).height(32).fontSize(11).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(8)).onClick(()=>this.shareReply(message.content)).id(`assistant-share-${index}`)}}.width('100%').alignItems(HorizontalAlign.Start).padding(18).backgroundColor(message.role==='user'?this.tint():this.surface()).borderRadius(this.radius(19)).border({width:1,color:message.role==='user'?this.tint():this.line()})
        },(message:AiMessage,index:number)=>`${index}-${message.role}`)
        if(this.aiMessage){Text(this.aiMessage).fontSize(12).fontColor(this.muted()).lineHeight(21).width('100%').id('assistant-status')}
        if(this.aiRejected&&!this.aiBusy){Button('修改本次请求').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.editRejectedAiRequest()).id('assistant-edit-rejected')}
        if(this.mode==='日记润色'&&this.aiJob.status==='completed'){Button('编辑为日记').type(ButtonType.Normal).height(40).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(10)).onClick(()=>this.diaryReply()).id('assistant-diary')}
        if(planSize(this.aiResult)>0&&!this.aiApplied){Button(`查看 ${planSize(this.aiResult)} 项提案`).type(ButtonType.Normal).borderRadius(this.radius(12)).height(45).width('100%').fontColor(this.onPrimary()).backgroundColor(this.primary()).onClick(()=>this.panel='ai-proposal').id('ai-preview')}
        if(this.canUndoAi){Button('撤销刚才的提案').type(ButtonType.Normal).borderRadius(this.radius(12)).height(40).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.undoAiTasks()).id('ai-undo-assistant')}
        if(this.aiBusy){Button('停止本次请求').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(this.surface()).onClick(()=>{this.cancelAi();}).id('assistant-cancel')}
        Blank().height(6)
      }.width('100%')}.layoutWeight(1).constraintSize({minHeight:0}).scrollBar(BarState.Off).align(Alignment.Top).id('assistant-thread').onAppear(()=>{setTimeout(()=>this.scrollChatBottom(),100);})
      Column({space:10}){
      if(this.aiImages.length&&!this.keyboardVisible){Row({space:8}){ForEach(this.aiImages,(photo:string,index:number)=>{
        Column({space:3}){Image(photo).width(56).height(56).objectFit(ImageFit.Cover).borderRadius(this.radius(8));Button('移除').type(ButtonType.Normal).fontSize(11).fontColor(this.muted()).backgroundColor(Color.Transparent).enabled(!this.aiBusy&&!this.aiPending.id).onClick(()=>{this.aiImages=this.aiImages.filter((item:string,i:number)=>i!==index);this.persistAssistant();}).id(`assistant-remove-image-${index}`)}
      },(photo:string,index:number)=>String(index))}.width('100%')}
      Row({space:12}){
        Column(){this.selectField({labels:this.assistantModes,selected:this.assistantModes.indexOf(this.mode),id:'assistant-mode',change:(index:number)=>this.mode=this.assistantModes[index],enabled:!this.aiBusy&&!this.aiPending.id})}.width(136)
        Text('附带日程与日记').fontSize(11).fontColor(this.muted()).layoutWeight(1).textAlign(TextAlign.End)
        Toggle({type:ToggleType.Switch,isOn:this.readAgenda}).scale({x:0.8,y:0.8}).selectedColor(this.teal()).enabled(!this.aiBusy&&!this.aiPending.id).onChange((v:boolean)=>this.readAgenda=v).id('assistant-context')
      }.width('100%').height(this.keyboardVisible&&this.viewportHeight<500?0:44).visibility(this.keyboardVisible&&this.viewportHeight<500?Visibility.Hidden:Visibility.Visible).clip(true)
      TextArea({placeholder:this.mode==='拆解任务'?'写下目标，鲸办会准备任务提案…':'想聊些什么，或者一起理一理计划…',text:this.chatDraft}).height(this.keyboardVisible?(this.viewportHeight<400?48:64):84).fontSize(14).fontColor(this.ink()).placeholderColor(this.muted()).backgroundColor(this.surface()).borderRadius(this.radius(18)).maxLength(200000).enabled(!this.aiPending.id).onChange((text:string)=>this.chatDraft=text).onBlur(()=>this.persistAssistant()).id('assistant-input')
      TaskCaptureInput({assistantMode:true,applyLabel:'填入对话',dark:this.dark(),tone:this.data.tone||'whale',corners:this.data.corners||'round',blocked:this.aiBusy||!!this.aiPending.id||this.aiPictureBusy,sendEnabled:!this.aiBusy&&!this.aiPictureBusy,sendLabel:this.aiBusy?'处理中…':this.aiPending.id?'继续检查':'发送',imageLabel:this.aiPictureBusy?'正在读取…':'添加图片',onAddImage:()=>this.assistantPhotoMenu(),onSend:()=>{this.sendAi();},onApply:(value:string)=>this.assistantCaptured(value)})
      }.width('100%').padding({top:this.keyboardVisible&&this.viewportHeight<400?6:10,bottom:this.keyboardVisible&&this.viewportHeight<400?6:12}).flexShrink(0).backgroundColor(this.paper()).id('assistant-composer')
    }.width('100%').padding({left:22,right:22}).layoutWeight(1).id('assistant-layout')
  }
  @Builder
  private profileRow(options:ProfileRowOptions) {
    Row({space:12}){Text(options.icon).fontSize(21).fontColor(this.teal()).width(26);Text(options.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.ink()).layoutWeight(1);if(options.subtitle){Text(options.subtitle).fontSize(12).fontColor(this.muted()).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).constraintSize({maxWidth:'42%'})}Text('›').fontSize(22).fontColor(this.muted())}.width('100%').padding(15).backgroundColor(this.surface()).borderRadius(this.radius(13)).border({width:1,color:this.line(),radius:this.radius(12)}).onClick(()=>options.action()).id('profile-row-'+options.title)
  }
  @Builder
  private profile() {
    Scroll(){Column({space:13}){
      Text('我的').fontSize(30).fontWeight(FontWeight.Bold).fontColor(this.ink()).width('100%').margin({top:24,bottom:3})
      Column({space:20}){Row({space:16}){Image(this.avatarSource()).sourceSize({width:256,height:256}).width(68).height(68).objectFit(ImageFit.Cover).borderRadius(34).onClick(()=>this.avatarMenu()).accessibilityText('更换头像').id('profile-avatar');Column({space:7}){Text(this.data.nickname||(this.session.user.id?this.session.user.username:'登录 / 注册')).fontSize(21).fontWeight(FontWeight.Bold).fontColor(this.ink());Text(this.data.motto||(this.session.user.id?'个人账户':'访客')).fontSize(12).fontColor(this.muted())}.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(()=>this.openAccount()).id('account-open');Text('›').fontSize(26).fontColor(this.teal()).onClick(()=>this.openAccount())}.width('100%');Row(){Column({space:5}){Text(String(this.completed().length)).fontSize(23).fontWeight(FontWeight.Bold).fontColor(this.teal());Text('已完成').fontSize(12).fontColor(this.muted())}.layoutWeight(1);Column({space:5}){Text(String(this.pending().length)).fontSize(23).fontWeight(FontWeight.Bold).fontColor(this.teal());Text('待办').fontSize(12).fontColor(this.muted())}.layoutWeight(1);Column({space:5}){Text(String(this.data.diaries.length)).fontSize(23).fontWeight(FontWeight.Bold).fontColor(this.teal());Text('日记').fontSize(12).fontColor(this.muted())}.layoutWeight(1)}.width('100%')}.padding(20).backgroundColor(this.tint()).borderRadius(this.radius(24)).width('100%')
      this.section({title:'记录与回顾'})
      this.profileRow({icon:'▥',title:'行动统计',subtitle:'',action:()=>this.panel='statistics'})
      this.profileRow({icon:'▤',title:'日记',subtitle:'',action:()=>this.diaryOpen()})
      this.section({title:'数据与工具'})
      this.profileRow({icon:'☁',title:'同步与备份',subtitle:this.syncMessage,action:()=>this.openCloud()})
      this.profileRow({icon:'◷',title:'事项提醒',subtitle:this.remindersEnabled?'已开启':'已关闭',action:()=>this.openReminders()})
      this.profileRow({icon:'↗',title:'分享与导出',subtitle:'',action:()=>this.openShare()})
      this.profileRow({icon:'↺',title:'回收站',subtitle:`${trashTasks(this.data).length} 项可恢复`,action:()=>this.panel='trash'})
      this.profileRow({icon:'⚙',title:'设置',subtitle:'',action:()=>this.panel='settings'})
      Blank().height(24)
    }.width('100%').padding({left:20,right:20})}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private field(options:LabelOptions) {Text(options.label).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.muted()).width('100%').margin({top:6})}
  @Builder
  private panelHeader(options:TitleOptions) {Row(){Button('‹').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(30).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.back()).id('back-panel');Text(options.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1)}.width('100%').height(62).padding({left:8,right:20})}
  @Builder
  private pickerButton(options:PickerButtonOptions) {
    Button(options.label).type(ButtonType.Normal).fontSize(14).fontColor((options.enabled??true)?this.ink():this.muted())
      .width('100%').height(44).backgroundColor(this.surface()).borderRadius(this.radius(12)).border({width:1,color:this.line(),radius:this.radius(12)})
      .enabled(options.enabled??true).onClick(()=>options.action()).id(options.id)
  }
  @Builder
  private dateTimeFields(options:DateFieldOptions) {
    this.field({label:options.label})
    Row({space:8}){
      Column(){this.pickerButton({label:this.taskDateValue(options.reservation)?dateKey(this.taskDateValue(options.reservation)):'选择日期',id:options.id,action:()=>this.pickTaskDate(options.reservation)})}.layoutWeight(1)
      Column(){this.pickerButton({label:this.taskDateValue(options.reservation)?clock(this.taskDateValue(options.reservation)):'时间',id:`${options.id}-time`,action:()=>this.pickTaskTime(options.reservation),enabled:this.taskDateValue(options.reservation)>0})}.width(96)
      if(this.taskDateValue(options.reservation)){Button('×').type(ButtonType.Normal).width(44).height(44).fontSize(20).fontColor(this.muted())
        .backgroundColor(Color.Transparent).accessibilityText(`清除${options.label}`).onClick(()=>this.setTaskDateTime(options.reservation,0)).id(`${options.id}-clear`)}
    }.width('100%')
  }
  @Builder
  private workEditor() {
    Row(){
      Button('‹').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(30).fontColor(this.teal()).backgroundColor(Color.Transparent).onClick(()=>this.back()).id('back-panel')
      Text(this.workScope==='today'?'今日行动时间':'默认行动时间').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.ink()).layoutWeight(1)
      if(this.workScope==='today'){
        Button(){Image($r('app.media.icon_settings')).width(22).height(22).fillColor(this.teal())}.type(ButtonType.Normal)
          .width(44).height(44).padding(0).backgroundColor(this.tint()).borderRadius(this.radius(12))
          .accessibilityText('设置默认行动时间').onClick(()=>{this.panel='settings';this.workOpen();}).id('work-settings')
      }
    }.width('100%').height(62).padding({left:8,right:22})
    Scroll(){Column({space:16}){
      if(this.workScope==='today'){
        Text(dateKey(this.workDate)).fontSize(14).fontColor(this.muted()).width('100%')
      }else{
        this.field({label:'默认规则'})
        this.selectField({labels:this.workModes,selected:this.workMode,id:'work-mode',change:(index:number)=>this.workMode=index})
      }
      ForEach(this.workRows(),(group:number)=>{
        Row({space:8}){
          Text(this.workRowLabel(group)).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.ink()).width(56)
          Column(){this.pickerButton({label:minuteText(this.workDraft(group).start),id:`work-start-${group}`,action:()=>this.pickWorkTime(false,group)})}.layoutWeight(1)
          Text('～').fontSize(13).fontColor(this.muted())
          Column(){this.pickerButton({label:minuteText(this.workDraft(group).end),id:`work-end-${group}`,action:()=>this.pickWorkTime(true,group),enabled:this.workDraft(group).start<1439})}.layoutWeight(1)
        }.width('100%').padding({top:8,bottom:8}).id(`work-row-${group}`)
      },(group:number)=>String(group))
      Button('保存行动时间').type(ButtonType.Normal).width('100%').height(48).borderRadius(this.radius(12))
        .backgroundColor(this.primary()).fontColor(this.onPrimary()).onClick(()=>this.saveWork()).id('work-save').margin({top:6})
      if(this.workScope==='today'){
        Button('恢复默认时间').type(ButtonType.Normal).width('100%').height(44).borderRadius(this.radius(12)).backgroundColor(this.tint()).fontColor(this.teal()).onClick(()=>this.resetTodayWork()).id('work-reset')
      }
    }.width('100%').padding({left:22,right:22,bottom:22})}.layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
  }
  @Builder
  private heroStat(options:CountOptions) {Column({space:6}){Text(options.value).fontSize(29).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');Text(options.label).fontSize(11).fontColor('#DDEDF3')}.alignItems(HorizontalAlign.Start).layoutWeight(1)}
  @Builder
  private stars(options:StarOptions) {
    Row({space:8}){
      ForEach([1,2,3,4,5],(star:number)=>{
        Button(){Image(star<=options.value?$r('app.media.star_filled'):$r('app.media.star_outline')).width(28).height(28).fillColor(star<=options.value?this.teal():this.muted())}.type(ButtonType.Normal).borderRadius(this.radius(12))
          .type(ButtonType.Normal).padding(0).width(44).height(48).borderRadius(this.radius(12)).backgroundColor(star<=options.value?this.tint():Color.Transparent)
          .accessibilityText(`${star} 星${star<=options.value?'，已选':''}`).onClick(()=>options.change(star)).id(`${options.id}-${star}`)
      },(star:number)=>String(star))
    }.width('100%').id(options.id)
  }
  @Builder
  private editor() {
    this.panelHeader({title:this.editId?'整理事项':'快速记下'})
    Scroll(){Column({space:13}){
      this.field({label:'想做什么？'})
      TextInput({placeholder:'一句话，记下想做的事',text:this.draftTitle}).borderRadius(this.radius(12)).fontSize(17).height(54).fontColor(this.ink()).backgroundColor(this.surface()).maxLength(120).onChange((v:string)=>this.draftTitle=v).id('capture-title')
      if (!this.editId) {
        TaskCaptureInput({ dark: this.dark(), tone: this.data.tone||'whale', corners: this.data.corners||'round', onApply: (value: string) => this.applyCapturedText(value) })
      }
      if (this.editId && !this.editId.startsWith('calendar-')) {
        Button('添加到系统日历').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(13).fontColor(this.teal()).backgroundColor(Color.Transparent)
          .enabled(!this.calendarExporting).onClick(() => this.addToSystemCalendar()).id('task-add-calendar')
      }
      Button(this.detail?'收起详细整理  ⌃':'详细整理  ⌄').type(ButtonType.Normal).width('100%').height(46)
        .fontSize(14).fontColor(this.ink()).backgroundColor(this.tint()).borderRadius(this.radius(12))
        .onClick(()=>this.detail=!this.detail).id('capture-details')
      if(this.detail){
        this.field({label:'预计用时'})
        Row({space:8}){
          TextInput({placeholder:'可选',text:this.draftMinutes}).borderRadius(this.radius(12)).type(InputType.NUMBER_DECIMAL).height(44).layoutWeight(1)
            .fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).border({width:1,color:this.line(),radius:this.radius(12)})
            .maxLength(15).onChange((value:string)=>this.draftMinutes=value).id('capture-minutes')
          Button(){Image($r('app.media.chevron_up')).width(18).height(18).fillColor(this.ink())}.type(ButtonType.Normal).padding(0).width(40).height(44).borderRadius(this.radius(12)).backgroundColor(this.tint())
            .fontColor(this.ink()).accessibilityText('增加预计用时').onClick(()=>this.stepDuration(1)).id('duration-up')
          Button(){Image($r('app.media.chevron_down')).width(18).height(18).fillColor(this.ink())}.type(ButtonType.Normal).padding(0).width(40).height(44).borderRadius(this.radius(12)).backgroundColor(this.tint())
            .fontColor(this.ink()).accessibilityText('减少预计用时').onClick(()=>this.stepDuration(-1)).id('duration-down')
          Column(){this.selectField({labels:this.durationUnits,selected:this.durationUnit,id:'duration-unit',change:(index:number)=>this.durationUnit=index})}.width(94)
        }.width('100%')
        this.dateTimeFields({label:'截止时间',id:'capture-deadline',reservation:false})
        this.field({label:'分类'})
        this.selectField({labels:this.categoryLabels(),selected:this.categoryLabels().indexOf(this.draftCategory),id:'capture-category',change:(index:number)=>this.draftCategory=this.categoryLabels()[index]})
        this.field({label:'重要度'})
        this.stars({value:this.draftPriority,id:'capture-priority',change:(value:number)=>this.draftPriority=value})
        this.field({label:'重复'})
        this.selectField({labels:this.repeatValues.map((value:string)=>this.repeatLabel(value)),selected:this.repeatValues.indexOf(this.draftRepeat),id:'capture-repeat',change:(index:number)=>this.draftRepeat=this.repeatValues[index]})
        this.dateTimeFields({label:'手动预约',id:'capture-reservation',reservation:true})
        this.field({label:'备注'})
        TextArea({placeholder:'还有什么想补充的？',text:this.draftNote}).borderRadius(this.radius(12)).height(88).fontColor(this.ink()).backgroundColor(this.surface()).maxLength(2000).onChange((v:string)=>this.draftNote=v)
      }
      Button(this.editId?'保存整理':'记下这件事').type(ButtonType.Normal).fontSize(16).fontColor(this.onPrimary()).backgroundColor(this.primary()).borderRadius(this.radius(12)).width('100%').height(48).onClick(()=>this.saveTask()).id('capture-save')
      if(this.editId){Row({space:10}){Button('分享事项').type(ButtonType.Normal).borderRadius(this.radius(12)).layoutWeight(1).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.openShare(this.editId)).id('task-share');Button('移入回收站').type(ButtonType.Normal).borderRadius(this.radius(12)).layoutWeight(1).fontSize(13).fontColor(this.dark()?'#E8A9A2':'#B65C55').backgroundColor(this.surface()).onClick(()=>this.confirmDelete()).id('task-delete')}.width('100%')}
      Blank().height(24)
    }.width('100%').padding({left:22,right:22})}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private subpage() {
    if(this.panel==='feed'){this.feedPanel()}else if(this.panel==='feed-publish'){this.publishPanel()}else if(this.panel==='capture'){this.editor()}
    else if(this.panel==='rating'){
      this.panelHeader({title:'完成与自评'})
      Column({space:16}){Text(this.taskName(this.ratingId)).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%');this.stars({value:this.rating,id:'rating-value',change:(value:number)=>this.rating=value});Button('完成并保存').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).backgroundColor(this.primary()).fontColor(this.onPrimary()).onClick(()=>this.done()).id('complete-save')}.width('100%').padding(22)
    }else if(this.panel==='diary'){
      this.panelHeader({title:'日记'})
      Column({space:16}){this.pickerButton({label:dateKey(this.diaryDay)+'  ▾',id:'diary-date',action:()=>this.pickDiaryDay()});TextArea({placeholder:'写日记…',text:this.diary}).borderRadius(this.radius(12)).height(300).fontSize(16).fontColor(this.ink()).backgroundColor(this.surface()).maxLength(800).onChange((v:string)=>this.diary=v).id('diary-input');Button('保存日记').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).backgroundColor(this.primary()).fontColor(this.onPrimary()).onClick(()=>this.saveDiary()).id('diary-save')}.padding(22).width('100%')
    }else if(this.panel==='work'){
      this.workEditor()
    }else if(this.panel==='settings'){
      this.panelHeader({title:'设置'})
      Scroll(){Column({space:13}){this.section({title:'账户'});this.profileRow({icon:'○',title:'账户信息',subtitle:'',action:()=>this.openAccount()});this.profileRow({icon:'☁',title:'同步与备份',subtitle:'',action:()=>this.openCloud()});this.section({title:'偏好'});this.profileRow({icon:'◐',title:'外观设定',subtitle:this.themeLabels[this.themeValues.indexOf(this.data.theme)],action:()=>this.showPanel('appearance')});this.profileRow({icon:'◷',title:'行动时间',subtitle:this.workModes[this.data.workWindows?.length===7?2:this.data.workWindows?.length===2?1:0],action:()=>this.workOpen()});this.profileRow({icon:'♧',title:'事项提醒',subtitle:this.remindersEnabled?'已开启':'已关闭',action:()=>this.openReminders()});this.profileRow({icon:'◷',title:'日期与时区',subtitle:this.data.timeZone||AppTime.systemZone,action:()=>this.openZone()});this.profileRow({icon:'◇',title:'个人资料',subtitle:this.data.nickname||'',action:()=>this.editProfile()});this.profileRow({icon:'ⓘ',title:'关于',subtitle:'',action:()=>this.showPanel('about')})}.width('100%').padding(22).justifyContent(FlexAlign.Start)}.layoutWeight(1).align(Alignment.Top).scrollBar(BarState.Off)
    }else if(this.panel==='assistant-history'){
      this.panelHeader({title:'对话管理'})
      Column({space:12}){
        TextInput({text:this.conversationQuery,placeholder:'搜索对话'}).height(44).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).onChange((value:string)=>this.conversationQuery=value).id('conversation-search')
        this.selectField({labels:['最近对话','已归档'],selected:this.showArchived?1:0,id:'conversation-view',change:(index:number)=>this.showArchived=index===1})
        Scroll(){Column({space:12}){ForEach(this.conversationRows(),(row:ConversationInfo)=>{
          Column({space:12}){Text((row.pinned?'置顶 · ':'')+row.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%').onClick(()=>this.openConversation(row.id)).id(`conversation-open-${row.id}`)
            Row({space:10}){Button('重命名').type(ButtonType.Normal).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(8)).onClick(()=>this.renameConversation(row)).id(`conversation-rename-${row.id}`);Button(row.pinned?'取消置顶':'置顶').type(ButtonType.Normal).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(8)).onClick(()=>this.editConversation(row,false,true));Button(row.archived?'恢复':'归档').type(ButtonType.Normal).fontSize(12).fontColor(this.muted()).backgroundColor(this.surface()).borderRadius(this.radius(8)).onClick(()=>this.editConversation(row,true,false)).id(`conversation-archive-${row.id}`)}.width('100%')
          }.padding(16).width('100%').backgroundColor(this.surface()).borderRadius(this.radius(16))
        },(row:ConversationInfo)=>`${row.id}:${row.title}:${row.pinned}:${row.archived}`)}.width('100%')}.layoutWeight(1).align(Alignment.Top)
        Button('开始新对话').type(ButtonType.Normal).height(44).width('100%').fontColor(this.onPrimary()).backgroundColor(this.primary()).borderRadius(this.radius(12)).onClick(()=>this.newConversation()).id('conversation-new')
      }.width('100%').padding({left:22,right:22,bottom:22}).layoutWeight(1)
    }else if(this.panel==='assistant-rename'){
      this.panelHeader({title:'重命名对话'})
      Column({space:18}){TextInput({text:this.renameConversationTitle,placeholder:'对话名称'}).maxLength(80).height(48).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).onChange((value:string)=>this.renameConversationTitle=value).id('conversation-title');Button('保存名称').type(ButtonType.Normal).height(48).width('100%').fontColor(this.onPrimary()).backgroundColor(this.primary()).borderRadius(this.radius(12)).onClick(()=>this.saveConversationName()).id('conversation-name-save')}.width('100%').padding(22)
    }else if(this.panel==='profile-edit'){
      this.panelHeader({title:'个人资料'})
      Scroll(){Column({space:16}){
        this.field({label:'昵称'})
        TextInput({text:this.draftNickname,placeholder:'怎么称呼你？'}).height(48).maxLength(40).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).onChange((value:string)=>this.draftNickname=value).id('profile-nickname')
        this.field({label:'Motto'})
        TextArea({text:this.draftMotto,placeholder:'写一句喜欢的话'}).height(110).maxLength(160).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).onChange((value:string)=>this.draftMotto=value).id('profile-motto')
        Button('保存个人资料').type(ButtonType.Normal).height(48).width('100%').borderRadius(this.radius(12)).fontColor(this.onPrimary()).backgroundColor(this.primary()).onClick(()=>this.saveProfile()).id('profile-save')
      }.padding(22).width('100%')}.layoutWeight(1).align(Alignment.Top)
    }else if(this.panel==='timezone'){
      this.panelHeader({title:'日期与时区'})
      Scroll(){Column({space:16}){
        Text(localText(Date.now())).fontSize(23).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%').id('timezone-clock')
        this.field({label:'时区'})
        this.selectField({labels:this.zoneNames(),selected:this.zones().indexOf(this.zoneChoice),id:'timezone-select',change:(index:number)=>this.zoneChoice=this.zones()[index]})
        this.field({label:'同步方式'})
        this.selectField({labels:['绝对同步 · 保留实际时刻','相对同步 · 保留计划钟面时间'],selected:this.zonePolicy==='relative'?1:0,id:'timezone-policy',change:(index:number)=>this.zonePolicy=index===1?'relative':'absolute'})
        Text(this.zonePolicy==='absolute'?'事项与安排按新时区换算显示。':'未来未完成计划保持钟面时间；已完成记录保留实际时刻。').fontSize(13).lineHeight(22).fontColor(this.muted()).width('100%')
        Text('新时区当前时间：'+AppTime.dateKey(Date.now(),this.zoneChoice)+' '+AppTime.clock(Date.now(),this.zoneChoice)).fontSize(14).fontColor(this.teal()).width('100%').id('timezone-preview')
        Button('应用时区设置').type(ButtonType.Normal).height(48).width('100%').borderRadius(this.radius(12)).fontColor(this.onPrimary()).backgroundColor(this.primary()).onClick(()=>this.saveZone()).id('timezone-save')
      }.padding(22).width('100%')}.layoutWeight(1).align(Alignment.Top)
    }else if(this.panel==='appearance'){
      this.panelHeader({title:'外观设定'})
      Scroll(){Column({space:16}){
        this.field({label:'显示模式'})
        this.selectField({labels:this.themeLabels,selected:this.themeValues.indexOf(this.data.theme),id:'theme-select',change:(index:number)=>{const next=clone(this.data);next.theme=this.themeValues[index];this.save(next);}})
        this.field({label:'色调'})
        this.selectField({labels:toneLabels,selected:toneIds.indexOf(this.data.tone||'whale'),id:'tone-select',change:(index:number)=>{const next=clone(this.data);next.tone=toneIds[index];this.save(next);}})
        Row({space:8}){ForEach(toneIds,(tone:string)=>{Circle().width(22).height(22).fill(themeColors(false,tone).hero).onClick(()=>{const next=clone(this.data);next.tone=tone;this.save(next);}).accessibilityText(toneLabels[toneIds.indexOf(tone)])},(tone:string)=>tone)}.width('100%')
        this.field({label:'界面形状'})
        this.selectField({labels:['圆角','方角'],selected:this.data.corners==='square'?1:0,id:'corners-select',change:(index:number)=>{const next=clone(this.data);next.corners=index===1?'square':'round';this.save(next);}})
        this.field({label:'头像'})
        Row({space:16}){Image(this.avatarSource()).sourceSize({width:256,height:256}).width(64).height(64).objectFit(ImageFit.Cover).borderRadius(32);Button(this.avatarBusy?'正在处理…':'更换头像').type(ButtonType.Normal).height(44).layoutWeight(1).backgroundColor(this.tint()).fontColor(this.teal()).borderRadius(this.radius(12)).enabled(!this.avatarBusy).onClick(()=>this.avatarMenu()).id('avatar-change')}.width('100%')
      }.width('100%').padding(22)}.layoutWeight(1).align(Alignment.Top)
    }else if(this.panel==='account'){
      this.accountPanel()
    }else if(this.panel==='email'){
      EmailPanel({cloud:this.cloud,endpoint:COURSE_ENDPOINT,mode:this.emailMode,dark:this.dark(),tone:this.data.tone||'whale',corners:this.data.corners||'round',codeExpiresSeconds:this.emailStatus.codeExpiresSeconds,onClose:()=>{this.panel='account';},onUsernameRegistration:(username:string)=>this.useUsernameRegistration(username),onRegistered:(next:CloudSession)=>this.emailRegistered(next),onBound:()=>this.emailDone('bind'),onReset:()=>this.emailDone('reset'),onBusyState:(value:boolean)=>this.busy=value})
    }else if(this.panel==='cloud'){
      this.cloudPanel()
    }else if(this.panel==='ai-proposal'){
      this.aiProposalPanel()
    }else if(this.panel==='calendar-import'){
      this.calendarImportPanel()
    }else if(this.panel==='statistics'){
      this.statisticsPanel()
    }else if(this.panel==='trash'){
      this.trashPanel()
    }else if(this.panel==='share'){
      this.sharePanel()
    }else if(this.panel==='reminders'){
      this.remindersPanel()
    }else if(this.panel==='sync-preview'){
      this.manualSyncPanel()
    }else if(this.panel==='proposal'){
      this.panelHeader({title:'计划提案'})
      Scroll(){Column({space:16}){this.empty({title:`${this.proposal.added} 个新时段 · ${this.proposal.preserved} 个时段保留`,subtitle:`${this.proposal.moved} 个旧时段将重新安排 · ${this.proposal.skipped} 项需补齐用时或截止`});if(this.proposal.missing>0){Text(`${this.proposal.missing} 分钟未排入`).fontSize(14).fontColor('#BE4D4A')}ForEach(this.proposal.after,(block:Block)=>{this.timeCard(block)},(block:Block)=>block.id);if(this.proposal.after.length===0){this.empty({title:'暂无可安排事项'})}Button('接受并应用').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).backgroundColor(this.primary()).fontColor(this.onPrimary()).onClick(()=>this.applyPlan()).id('plan-accept');Button('调整行动时间').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.workOpen());Blank().height(24)}.width('100%').padding(22)}.layoutWeight(1).align(Alignment.Top)
    }else{
      this.panelHeader({title:'关于鲸办'})
      Column({space:20}){Image($r('app.media.launcher_icon')).width(90).height(90).borderRadius(this.radius(28));Text('鲸办 WhaleDo').fontSize(27).fontWeight(FontWeight.Bold).fontColor(this.ink());Text('HarmonyOS · 0.4.0').fontSize(12).fontColor(this.muted())}.width('100%').padding(32)
    }
  }
  @Builder
  private manualSyncPanel() {
    this.panelHeader({title:`${this.syncKindLabel(this.syncPreview.kind)}预览`})
    Scroll(){Column({space:16}){
      this.empty({title:this.syncPreview.scope.schedule&&this.syncPreview.scope.diaries?'日程与日记':this.syncPreview.scope.schedule?'仅日程':'仅日记',subtitle:this.syncPreview.kind==='pull'?'确认后将覆盖本机所选内容。':''})
      if(this.syncPreview.scope.schedule){Text(`默认行动时间 ${minuteText(this.syncPreview.candidate.workStart)}–${minuteText(this.syncPreview.candidate.workEnd)}`).fontSize(12).fontColor(this.muted()).width('100%')}
      this.section({title:'当前本机'})
      Text(`${this.syncPreview.localTasks} 项事项 · ${this.syncPreview.localBlocks} 个时段 · ${this.syncPreview.localDiaries} 篇日记`).fontSize(14).fontColor(this.ink()).lineHeight(23).width('100%')
      this.section({title:this.syncPreview.sourceRevision>0?`云端来源 v${this.syncPreview.sourceRevision}`:'云端暂无备份',detail:this.syncPreview.cloudRevision!==this.syncPreview.sourceRevision?`最新 v${this.syncPreview.cloudRevision}`:''})
      Text(`${this.syncPreview.cloudTasks} 项事项 · ${this.syncPreview.cloudBlocks} 个时段 · ${this.syncPreview.cloudDiaries} 篇日记`).fontSize(14).fontColor(this.ink()).lineHeight(23).width('100%')
      this.section({title:this.syncPreview.kind==='push'?'备份后云端':'确认后本机'})
      this.empty({title:`${this.syncPreview.resultTasks} 项事项 · ${this.syncPreview.resultBlocks} 个时段`,subtitle:`${this.syncPreview.resultDiaries} 篇日记`})
      if(this.syncPreview.kind==='merge'){Text(`新增 ${this.syncPreview.addedTasks} 项事项、${this.syncPreview.addedDiaries} 篇日记。`).fontSize(13).fontColor(this.muted()).lineHeight(22).width('100%')}
      if(this.syncPreview.skippedBlocks>0){Text(`${this.syncPreview.skippedBlocks} 个云端时段与本机安排冲突，将跳过这些时段，事项仍会保留供重新安排。`).fontSize(13).fontColor(this.dark()?'#E5B899':'#9B6446').lineHeight(23).width('100%').id('sync-conflict-count')}
      Button(this.busy?'正在处理…':`确认${this.syncKindLabel(this.syncPreview.kind)}`).type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).backgroundColor(this.primary()).fontColor(this.onPrimary()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.applyManualSync();}).id('sync-confirm')
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private calendarImportPanel() {
    this.panelHeader({title:'导入系统日历'})
    Scroll(){Column({space:14}){
      this.section({title:'未来 30 天'})
      Text(this.calendarMessage).fontSize(13).fontColor(this.muted()).lineHeight(22).width('100%').id('calendar-import-status')
      if(this.calendarRecords.length>0){Row(){Text(`已选 ${this.selectedCalendarIds.length} 项`).fontSize(13).fontColor(this.ink()).layoutWeight(1);Button(this.selectedCalendarIds.length===this.calendarRecords.length?'取消全选':'全选').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(12).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.selectedCalendarIds=this.selectedCalendarIds.length===this.calendarRecords.length?[]:this.calendarRecords.map((record:CalendarImportRecord)=>record.id)).id('calendar-select-all')}.width('100%')}
      ForEach(this.calendarRecords,(record:CalendarImportRecord)=>{Row({space:12}){Checkbox({name:record.id}).select(this.selectedCalendarIds.includes(record.id)).selectedColor(this.teal()).width(22).height(22).onChange((selected:boolean)=>this.chooseCalendar(record.id,selected));Column({space:7}){Text(record.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%');Text(this.calendarRecordTime(record)).fontSize(11).fontColor(this.muted()).lineHeight(18).width('100%');if(record.location){Text(record.location).fontSize(12).fontColor(this.muted()).width('100%')}}.layoutWeight(1)}.width('100%').padding(17).backgroundColor(this.surface()).borderRadius(this.radius(18))},(record:CalendarImportRecord)=>record.id)
      Button(`确认导入 ${this.selectedCalendarIds.length} 项`).type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).fontColor(this.onPrimary()).backgroundColor(this.primary()).enabled(!this.calendarBusy&&this.selectedCalendarIds.length>0).onClick(()=>this.applyCalendarImport()).id('calendar-import-confirm')
      if(!this.calendarBusy){Button('重新读取').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>{this.openCalendarImport();})}
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private aiProposalPanel() {
    this.panelHeader({title:'计划提案'})
    Scroll(){Column({space:15}){
      this.section({title:`${planSize(this.aiResult)} 项建议`})
      ForEach(this.aiResult.warnings,(message:string)=>{Text(message).fontSize(13).fontColor(this.dark()?'#E5B899':'#9B6446').lineHeight(22).width('100%')},(message:string,index:number)=>String(index))
      ForEach(this.aiResult.tasks,(task:AiTask,index:number)=>{
        Column({space:9}){Text(`${index+1}. ${task.title}`).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.ink()).width('100%');Text(`${task.category} · ${task.minutes?`${task.minutes} 分钟`:'用时待定'} · 重要度 ${task.priority}`).fontSize(12).fontColor(this.teal()).width('100%');if(task.deadline>0){Text(`截止 ${localText(task.deadline)}`).fontSize(12).fontColor(this.muted()).width('100%')}if(task.note){Text(task.note).fontSize(14).fontColor(this.muted()).lineHeight(23).width('100%')}}.width('100%').padding(19).backgroundColor(this.surface()).borderRadius(this.radius(19)).border({width:1,color:this.line(),radius:this.radius(12)})
      },(task:AiTask,index:number)=>String(index))
      if(this.aiSignature!==JSON.stringify(this.data)){Text('事项已经变化，请返回助手重新生成提案。').fontSize(13).fontColor('#BE4D4A').lineHeight(22).width('100%')}
      ForEach(this.aiResult.edits||[],(item:TaskEdit)=>{Column({space:7}){Text('编辑 · '+this.taskName(item.taskId)).fontSize(13).fontColor(this.muted());Text(item.title).fontSize(17).fontColor(this.ink());Text(`${item.minutes} 分钟 · ${item.deadline?localText(item.deadline):'无截止时间'}`).fontSize(12).fontColor(this.muted())}.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(this.surface()).borderRadius(this.radius(16))},(item:TaskEdit)=>item.taskId)
      ForEach(this.aiResult.schedule||[],(item:PlannedTime)=>{Column({space:7}){Text('安排 · '+this.planTaskLabel(item.taskId)).fontSize(16).fontColor(this.ink());Text(`${localText(item.start)} — ${localText(item.end)}`).fontSize(12).fontColor(this.muted())}.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(this.tint()).borderRadius(this.radius(16))},(item:PlannedTime)=>item.taskId)
      Button(this.aiApplied?'已应用':'同意并应用提案').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).fontColor(this.onPrimary()).backgroundColor(this.primary()).enabled(!this.aiApplied&&this.aiSignature===JSON.stringify(this.data)&&planSize(this.aiResult)>0).onClick(()=>this.acceptAiTasks()).id('ai-accept')
      Button('提出修改意见').type(ButtonType.Normal).height(44).width('100%').fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(12)).onClick(()=>this.reviseProposal()).id('ai-revise')
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private metric(options:CountOptions) {Column({space:6}){Text(options.value).fontSize(27).fontWeight(FontWeight.Bold).fontColor(this.teal());Text(options.label).fontSize(12).fontColor(this.muted())}.layoutWeight(1).alignItems(HorizontalAlign.Start).padding(18).backgroundColor(this.surface()).borderRadius(this.radius(18))}
  @Builder
  private statisticsPanel() {
    this.panelHeader({title:'行动统计'})
    Scroll(){Column({space:14}){
      Row({space:12}){this.metric({value:String(taskStats(this.data).completed),label:'累计完成'});this.metric({value:String(taskStats(this.data).completedWeek),label:'近七天完成'})}.width('100%')
      Row({space:12}){this.metric({value:String(taskStats(this.data).pending),label:'待办事项'});this.metric({value:String(taskStats(this.data).overdue),label:'已过截止时间'})}.width('100%')
      this.section({title:'完成进度',detail:`${taskStats(this.data).total>0?Math.round(taskStats(this.data).completed/taskStats(this.data).total*100):0}%`})
      Progress({value:taskStats(this.data).completed,total:Math.max(1,taskStats(this.data).total),type:ProgressType.Linear}).color(this.teal()).backgroundColor(this.tint()).width('100%')
      this.section({title:'时间记录'})
      Row({space:12}){this.metric({value:String(Math.round(taskStats(this.data).plannedMinutes)),label:'已安排分钟'});this.metric({value:String(taskStats(this.data).completedMinutes),label:'完成预计分钟'})}.width('100%')
      this.section({title:'分类分布'})
      ForEach(this.categoryLabels(),(category:string)=>{Row({space:12}){Text(category).fontSize(14).fontColor(this.ink()).width(56).maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis});Progress({value:activeTasks(this.data).filter((task:MobileTask)=>task.category===category).length,total:Math.max(1,activeTasks(this.data).length),type:ProgressType.Linear}).color(this.teal()).backgroundColor(this.tint()).layoutWeight(1);Text(String(activeTasks(this.data).filter((task:MobileTask)=>task.category===category).length)).fontSize(12).fontColor(this.muted()).width(25).textAlign(TextAlign.End)}.width('100%').padding({top:7,bottom:7})},(category:string)=>category)
      Button('和助手一起回顾').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(46).fontColor(this.onPrimary()).backgroundColor(this.primary()).onClick(()=>{this.mode='回顾';this.readAgenda=true;this.panel='';this.tab=3;})
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private trashPanel() {
    this.panelHeader({title:'回收站'})
    Scroll(){Column({space:13}){
      if(trashTasks(this.data).length===0){this.empty({title:'回收站为空'})}
      ForEach(trashTasks(this.data),(task:MobileTask)=>{Row({space:13}){Column({space:7}){Text(task.title).fontSize(16).fontColor(this.ink());Text(`${task.category} · ${localText(task.deletedAt)}`).fontSize(11).fontColor(this.muted())}.alignItems(HorizontalAlign.Start).layoutWeight(1);Button('恢复').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).onClick(()=>this.recoverTask(task.id)).id(`restore-task-${task.id}`)}.width('100%').padding(17).backgroundColor(this.surface()).borderRadius(this.radius(18))},(task:MobileTask)=>task.id)
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private feedPanel() {
    this.panelHeader({title:'鲸日分享'})
    Row(){Text('把小小的进步，分享给彼此。').fontSize(12).fontColor(this.muted()).layoutWeight(1);Button('写分享').type(ButtonType.Normal).fontSize(13).height(38).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(10)).onClick(()=>this.openShare()).id('feed-compose');Button('刷新').type(ButtonType.Normal).fontSize(12).height(38).fontColor(this.teal()).backgroundColor(Color.Transparent).enabled(!this.feedBusy).onClick(()=>this.refreshFeed()).id('feed-refresh')}.width('100%').padding({left:22,right:22,bottom:10})
    List({space:16}){
      if(this.feedMessage){ListItem(){Text(this.feedMessage).fontSize(13).fontColor(this.muted()).padding(12).width('100%').id('feed-status')}}
      ForEach(this.feedItems,(post:FeedPost)=>{
        ListItem(){Column({space:13}){
          Row({space:10}){Image($r('app.media.whaledo_mascot')).sourceSize({width:512,height:512}).width(36).height(36).objectFit(ImageFit.Cover).borderRadius(18);Column({space:4}){Text(post.author).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.ink());Text(localText(post.createdAt)).fontSize(10).fontColor(this.muted())}.alignItems(HorizontalAlign.Start).layoutWeight(1);if(post.mine){Button('删除').type(ButtonType.Normal).fontSize(11).height(30).backgroundColor(Color.Transparent).fontColor(this.muted()).onClick(()=>this.deletePost(post)).id('feed-delete-'+post.id)}}.width('100%')
          if(post.caption){Text(post.caption).fontSize(14).lineHeight(23).fontColor(this.ink()).width('100%')}
          Row(){Stack(){this.shareCard(post.card)}.width(360).height(480).flexShrink(0).scale({x:Math.min(1,(this.viewportWidth-88)/360),y:Math.min(1,(this.viewportWidth-88)/360)})}.height(480*Math.min(1,(this.viewportWidth-88)/360)).width('100%').justifyContent(FlexAlign.Center).clip(true)
          Row(){Blank();Button((post.liked?'♥ ':'♡ ')+post.likes).type(ButtonType.Normal).height(37).fontSize(14).fontColor(post.liked?this.teal():this.muted()).backgroundColor(post.liked?this.tint():Color.Transparent).borderRadius(this.radius(10)).enabled(!this.feedLikeBusy).onClick(()=>this.likePost(post)).id('feed-like-'+post.id)}.width('100%')
        }.width('100%').padding(16).backgroundColor(this.surface()).borderRadius(this.radius(20))}
      },(post:FeedPost)=>`${post.id}:${post.likes}:${post.liked}`)
      if(this.feedNext){ListItem(){Button(this.feedBusy?'正在读取…':'查看更多').type(ButtonType.Normal).width('100%').height(46).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(12)).enabled(!this.feedBusy).onClick(()=>this.refreshFeed(true)).id('feed-more')}}
      ListItem(){Row().height(24)}
    }.width('100%').layoutWeight(1).padding({left:22,right:22}).scrollBar(BarState.Off)
  }
  @Builder
  private publishPanel() {
    this.panelHeader({title:'发布预览'})
    if(this.publishPending){Scroll(){Column({space:16}){
      Text('发布后，其他人可以看到这张卡片与配文。').fontSize(13).lineHeight(22).fontColor(this.muted()).width('100%')
      Text(this.publishPending.author).fontSize(14).fontColor(this.ink()).width('100%')
      if(this.publishPending.caption){Text(this.publishPending.caption).fontSize(15).lineHeight(24).fontColor(this.ink()).width('100%')}
      Row(){Stack(){this.shareCard(this.publishPending.card)}.width(360).height(480).flexShrink(0).scale({x:this.shareScale(),y:this.shareScale()})}.height(480*this.shareScale()).width('100%').justifyContent(FlexAlign.Center).clip(true)
      Button(this.shareBusy?'正在发布…':'确认发布').type(ButtonType.Normal).width('100%').height(48).fontColor(this.onPrimary()).backgroundColor(this.primary()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onClick(()=>this.publishFeed()).id('feed-publish-confirm')
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off)}
  }
  @Builder
  private shareCard(card:FeedCard) {
    Stack({alignContent:Alignment.TopStart}){
      Image(this.shareArt(card.style)).width('100%').height('100%').objectFit(ImageFit.Cover)
      Image($r('app.media.whaledo_mascot')).sourceSize({width:512,height:512}).width(124).height(144).objectFit(ImageFit.Contain).position({x:205,y:315}).opacity(0.95)
      Column({space:17}){
        Text('WHALEDO · '+card.date).fontSize(10).letterSpacing(1).fontColor(card.style===2?'#CAD4EF':'#52747C').width('100%')
        Text(card.title).fontSize(26).lineHeight(34).fontWeight(FontWeight.Bold).fontColor(card.style===2?'#FFFFFF':'#263D45').maxLines(2).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')
        Column({space:12}){ForEach(card.lines,(line:string,index:number)=>{Text(line).fontSize(14).lineHeight(22).fontColor(card.style===2?'#E6EBF7':'#354D55').maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis}).width('100%')},(line:string,index:number)=>String(index))}.width('100%')
        Blank()
        Text(card.footer).fontSize(11).fontColor(card.style===2?'#DDE7F7':'#365860').width(175).maxLines(1).textOverflow({overflow:TextOverflow.Ellipsis})
      }.padding(28).width('100%').height('100%').alignItems(HorizontalAlign.Start)
    }.width(360).height(480).clip(true)
  }
  @Builder
  private sharePanel() {
    this.panelHeader({title:'分享与导出'})
    Scroll(){Column({space:16}){
      if(!this.shareTaskId){this.selectField({labels:['待办清单','所选日期','已完成'],selected:this.shareSource,id:'share-source',change:(index:number)=>{this.shareSource=index;this.fillShareBody();},enabled:!this.shareBusy})}
      this.selectField({labels:['鲸海','晨光','星夜'],selected:this.shareStyle,id:'share-style',change:(index:number)=>{this.shareStyle=index;this.captionStyle=0;},enabled:!this.shareBusy})
      this.field({label:'卡片标题'})
      TextInput({text:this.shareTitle,placeholder:'今天的进度'}).maxLength(60).height(44).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onChange((value:string)=>this.shareTitle=value).id('share-title')
      this.field({label:'卡片内容（最多5行）'})
      TextArea({text:this.shareBody}).height(110).maxLength(1000).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onChange((value:string)=>this.shareBody=value.split('\n').slice(0,5).join('\n')).id('share-body')
      this.selectField({labels:this.captionStyles(),selected:this.captionStyle,id:'caption-style',change:(index:number)=>this.captionStyle=index,enabled:!this.shareBusy})
      TextArea({text:this.shareCaption,placeholder:'写一段配文…'}).height(90).maxLength(2000).fontColor(this.ink()).backgroundColor(this.surface()).borderRadius(this.radius(12)).onChange((value:string)=>this.shareCaption=value).id('share-caption')
      Button('AI 帮我写配文').type(ButtonType.Normal).width('100%').height(42).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(12)).enabled(!this.aiBusy&&!this.aiPending.id&&!this.shareBusy).onClick(()=>this.generateCaption()).id('share-ai-caption')
      Row(){Stack(){this.shareCard(this.shareSnapshot())}.width(360).height(480).flexShrink(0).scale({x:this.shareScale(),y:this.shareScale()})}.height(480*this.shareScale()).width('100%').justifyContent(FlexAlign.Center).clip(true).id('share-card-preview')
      Row({space:10}){
        Button('保存图片').type(ButtonType.Normal).height(46).layoutWeight(1).fontColor(this.teal()).backgroundColor(this.tint()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onClick(()=>this.exportShare(true)).id('share-save-image')
        Button(this.shareBusy?this.shareStage:'分享图片').type(ButtonType.Normal).height(46).layoutWeight(1).fontColor(this.onPrimary()).backgroundColor(this.primary()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onClick(()=>this.exportShare(false)).id('share-image')
      }.width('100%')
      Button('分享到鲸日分享').type(ButtonType.Normal).width('100%').height(46).fontColor(this.onPrimary()).backgroundColor(this.primary()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onClick(()=>this.previewFeedPost()).id('share-to-feed')
      Row({space:10}){Button('分享文本清单').type(ButtonType.Normal).height(44).layoutWeight(1).fontColor(this.teal()).backgroundColor(this.surface()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onClick(()=>{this.share(false,this.shareTaskId);}).id('share-text');Button('导出日历文件').type(ButtonType.Normal).height(44).layoutWeight(1).fontColor(this.teal()).backgroundColor(this.surface()).borderRadius(this.radius(12)).enabled(!this.shareBusy).onClick(()=>{this.share(true,this.shareTaskId);}).id('share-ics')}.width('100%')
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private remindersPanel() {
    this.panelHeader({title:'事项提醒'})
    Scroll(){Column({space:16}){
      Text(this.reminderMessage).fontSize(14).fontColor(this.ink()).lineHeight(24).width('100%').id('reminder-status')
      Row(){Text('事项开始').fontSize(15).fontColor(this.ink()).layoutWeight(1);Toggle({type:ToggleType.Switch,isOn:this.reminderDraft.starts}).selectedColor(this.teal()).onChange((value:boolean)=>this.updateReminder('starts',value)).id('reminder-starts')}.width('100%')
      Row(){Text('事项截止').fontSize(15).fontColor(this.ink()).layoutWeight(1);Toggle({type:ToggleType.Switch,isOn:this.reminderDraft.deadlines}).selectedColor(this.teal()).onChange((value:boolean)=>this.updateReminder('deadlines',value)).id('reminder-deadlines')}.width('100%')
      this.field({label:'提前提醒'})
      this.selectField({labels:['准时','提前5分钟','提前10分钟','提前15分钟','提前30分钟','提前1小时','提前1天'],selected:[0,5,10,15,30,60,1440].indexOf(this.reminderDraft.leadMinutes),id:'reminder-lead',change:(index:number)=>{const next=JSON.parse(JSON.stringify(this.reminderDraft)) as ReminderOptions;next.leadMinutes=[0,5,10,15,30,60,1440][index];this.reminderDraft=next;}})
      this.field({label:'提醒方式'})
      this.selectField({labels:['静音','通知提示音','闹钟铃声'],selected:['silent','notification','alarm'].indexOf(this.reminderDraft.sound),id:'reminder-sound',change:(index:number)=>{const next=JSON.parse(JSON.stringify(this.reminderDraft)) as ReminderOptions;next.sound=['silent','notification','alarm'][index];this.reminderDraft=next;}})
      Row(){Text('免打扰').fontSize(15).fontColor(this.ink()).layoutWeight(1);Toggle({type:ToggleType.Switch,isOn:this.reminderDraft.quiet}).selectedColor(this.teal()).onChange((value:boolean)=>this.updateReminder('quiet',value)).id('reminder-quiet')}.width('100%')
      if(this.reminderDraft.quiet){Row({space:12}){Column(){this.pickerButton({label:minuteText(this.reminderDraft.quietStart),id:'quiet-start',action:()=>this.pickQuiet(false)})}.layoutWeight(1);Text('～').fontColor(this.muted());Column(){this.pickerButton({label:minuteText(this.reminderDraft.quietEnd),id:'quiet-end',action:()=>this.pickQuiet(true)})}.layoutWeight(1)}.width('100%')}
      Button('保存提醒设置').type(ButtonType.Normal).width('100%').height(46).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.reminderBusy).onClick(()=>this.saveReminderOptions()).id('reminder-save-options')
      this.section({title:'接下来提醒'})
      if(this.reminderPreview().length===0){Text('暂无符合设置的提醒').fontSize(13).fontColor(this.muted()).width('100%')}
      ForEach(this.reminderPreview(),(item:ReminderItem)=>{Column({space:5}){Text(item.title).fontSize(14).fontColor(this.ink()).width('100%');Text(localText(item.at)+' · '+item.kind).fontSize(12).fontColor(this.muted()).width('100%')}.padding(12).width('100%').backgroundColor(this.surface()).borderRadius(this.radius(12))},(item:ReminderItem)=>item.taskId+'-'+item.at+'-'+item.kind)
      Button(this.reminderBusy?'正在设置…':this.remindersEnabled?'更新后台提醒':'启用后台提醒').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).fontColor(this.onPrimary()).backgroundColor(this.primary()).enabled(!this.reminderBusy).onClick(()=>{this.enableReminders();}).id('reminder-enable')
      Row({space:10}){Button('测试通知').type(ButtonType.Normal).borderRadius(this.radius(12)).layoutWeight(1).height(44).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.reminderBusy).onClick(()=>this.testNotification()).id('notification-test');Button('测试后台提醒').type(ButtonType.Normal).borderRadius(this.radius(12)).layoutWeight(1).height(44).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.reminderBusy).onClick(()=>this.testReminder()).id('reminder-test')}.width('100%')
      if(this.remindersEnabled){Button('关闭事项提醒').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(44).fontColor(this.muted()).backgroundColor(this.surface()).enabled(!this.reminderBusy).onClick(()=>this.disableReminders()).id('reminder-disable')}
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).scrollBar(BarState.Off).align(Alignment.Top)
  }
  @Builder
  private accountPanel() {
    this.panelHeader({title:'账户'})
    Scroll(){Column({space:14}){
      if(this.session.user.id){
        this.section({title:this.session.user.username,detail:'个人账户'})
        Button('云端备份与恢复').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).fontColor(this.onPrimary()).backgroundColor(this.primary()).enabled(!this.busy).onClick(()=>this.openCloud()).id('cloud-open')
        if(this.emailAvailable('bind')){Button('绑定 / 更换邮箱').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(44).fontColor(this.teal()).backgroundColor(this.surface()).enabled(!this.busy).onClick(()=>this.openEmail('bind')).id('email-bind-open')}
        Button('退出账户').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.getUIContext().showAlertDialog({title:'退出当前账户？',message:'账户记录留在本机，下次登录可继续使用。',primaryButton:{value:'取消',action:()=>{}},secondaryButton:{value:'退出',action:()=>{this.logout();}}});}).id('account-logout')
      }else{
        this.field({label:'用户名（3—32位字母、数字或下划线）'})
        TextInput({text:this.username,placeholder:'用户名'}).borderRadius(this.radius(12)).fontColor(this.ink()).backgroundColor(this.surface()).maxLength(32).enabled(!this.busy).onChange((v:string)=>this.username=v).id('account-username')
        this.field({label:'密码（至少8位）'})
        TextInput({text:this.password,placeholder:'密码'}).borderRadius(this.radius(12)).type(InputType.Password).showPasswordIcon(false).fontColor(this.ink()).backgroundColor(this.surface()).maxLength(200).enabled(!this.busy).onChange((v:string)=>this.password=v).id('account-password')
        Button(this.busy?'正在连接…':this.registering?'注册并登录':'登录').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(48).fontColor(this.onPrimary()).backgroundColor(this.primary()).enabled(!this.busy).onClick(()=>{this.getUIContext().getFocusController().clearFocus();this.login();}).id('account-submit')
        Button(this.registering?'已有账户，去登录':'创建新账户').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(Color.Transparent).enabled(!this.busy).onClick(()=>this.registering=!this.registering).id('account-toggle')
        if(this.emailAvailable('register')){Button('使用邮箱验证注册').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(43).fontSize(13).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.busy).onClick(()=>this.openEmail('register')).id('email-register-open')}
        if(this.emailAvailable('reset')){Button('通过已绑定邮箱找回密码').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(12).fontColor(this.teal()).backgroundColor(Color.Transparent).enabled(!this.busy).onClick(()=>this.openEmail('reset')).id('email-reset-open')}
      }
      if(this.emailStatusMessage){Text(this.emailStatusMessage).fontSize(12).fontColor(this.muted()).lineHeight(20).width('100%').id('email-availability')}
      Text(this.cloudMessage).fontSize(13).fontColor(this.muted()).lineHeight(22).width('100%').id('account-message')
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).align(Alignment.Top)
  }
  @Builder
  private cloudPanel() {
    this.panelHeader({title:'同步与备份'})
    Scroll(){Column({space:15}){
      this.section({title:this.session.user.username,detail:'个人数据'})
      this.field({label:'同步内容'})
      this.selectField({labels:['日程','日记','日程与日记'],selected:this.syncSchedule?(this.syncDiaries?2:0):1,id:'sync-scope',change:(index:number)=>{
        this.syncSchedule=index!==1;this.syncDiaries=index!==0;
      },enabled:!this.busy&&!this.syncWorking})
      Text(this.syncMessage).fontSize(12).fontColor(this.muted()).lineHeight(21).width('100%').id('sync-status')
      Text(this.cloudMessage).fontSize(14).fontColor(this.muted()).lineHeight(23).width('100%').id('cloud-message')
      Button('云端备份  ↑').type(ButtonType.Normal).borderRadius(this.radius(12)).width('100%').height(46).fontColor(this.onPrimary()).backgroundColor(this.primary()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.beginManualSync('push');}).id('cloud-upload')
      Row({space:10}){Button('覆盖同步 ↓').type(ButtonType.Normal).borderRadius(this.radius(12)).layoutWeight(1).height(43).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.beginManualSync('pull');}).id('cloud-pull');Button('兼容同步 ⇄').type(ButtonType.Normal).borderRadius(this.radius(12)).layoutWeight(1).height(43).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.beginManualSync('merge');}).id('cloud-merge')}.width('100%')
      this.section({title:'备份历史'})
      Button('刷新版本').type(ButtonType.Normal).borderRadius(this.radius(12)).fontSize(12).fontColor(this.teal()).backgroundColor(this.surface()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.refreshCloud();}).id('cloud-refresh')
      if(this.history.length===0){this.empty({title:'暂无备份'})}
      ForEach(this.history,(item:CloudHead)=>{Button(`v${item.revision} · ${localText(item.updatedAt)}  ›`).type(ButtonType.Normal).height(55).width('100%').borderRadius(this.radius(16)).fontColor(this.ink()).backgroundColor(this.surface()).enabled(!this.busy&&!this.syncWorking).onClick(()=>{this.beginManualSync('pull',item.revision);}).id(`cloud-version-${item.revision}`)},(item:CloudHead)=>String(item.revision))
      if(this.moreHistory){Button('更早的版本').type(ButtonType.Normal).borderRadius(this.radius(12)).fontColor(this.teal()).backgroundColor(this.tint()).enabled(!this.busy).onClick(()=>{this.refreshCloud(true);}).id('cloud-older')}
      Blank().height(24)
    }.width('100%').padding(22)}.layoutWeight(1).align(Alignment.Top)
  }
  @Builder
  private navigation() {
    Row(){ForEach(this.labels,(label:string,index:number)=>{
      Column({space:5}){Row(){Image(this.navIcon(index)).width(23).height(23).fillColor(this.tab===index?this.teal():this.muted())}.width(52).height(32).justifyContent(FlexAlign.Center).borderRadius(this.radius(12)).backgroundColor(this.tab===index?this.tint():Color.Transparent);Text(label).fontSize(11).fontWeight(this.tab===index?FontWeight.Medium:FontWeight.Normal).fontColor(this.tab===index?this.teal():this.muted())}.layoutWeight(1).height(65).justifyContent(FlexAlign.Center).accessibilityText(label).onClick(()=>this.tab=index).id(`nav-${index}`)
    },(label:string)=>label)}.width('100%').height(this.tab===3&&this.keyboardVisible?0:75).visibility(this.tab===3&&this.keyboardVisible?Visibility.Hidden:Visibility.Visible).clip(true).backgroundColor(this.surface()).padding({bottom:5,top:5}).border({width:{top:1},color:this.line()})
  }
  build() {
    Column(){Stack({alignContent:Alignment.BottomEnd}){
      Column(){
        if(!this.ready){Column({space:20}){Text(this.failure||'正在读取本机记录…').fontColor(this.ink());Button('重试').type(ButtonType.Normal).borderRadius(this.radius(12)).onClick(()=>this.load())}.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)}
        else if(this.panel!==''){this.subpage()}
        else{if(this.tab<3){this.header()}if(this.tab===0){this.today()}else if(this.tab===1){this.todo()}else if(this.tab===2){this.calendar()}else if(this.tab===3){this.assistant()}else{this.profile()}this.navigation()}
      }.width('100%').height('100%').backgroundColor(this.paper())
      if(this.ready&&this.panel===''&&this.tab>0&&this.tab<3){Button(){Image($r('app.media.icon_plus')).width(24).height(24).fillColor(this.onPrimary())}.type(ButtonType.Normal).padding(0).width(54).height(54).backgroundColor(this.primary()).fontColor(this.onPrimary()).borderRadius(this.radius(18)).shadow({radius:10,color:'#25264C48',offsetY:4}).margin({right:22,bottom:88}).accessibilityText('快速记下事项').onClick(()=>this.newTask()).id('floating-capture')}
    }.width('100%').height('100%').constraintSize({maxWidth:840}).onAreaChange((oldArea:Area,newArea:Area)=>{this.viewportWidth=Number(newArea.width);this.viewportHeight=Number(newArea.height);})}.width('100%').height('100%').backgroundColor(this.paper())
  }
}
