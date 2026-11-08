import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { MobileData, clone, checkData, uid } from '../model/MobileModel';
import { SyncScope, checkScope, buildSyncPlan } from '../model/SyncPlan';
import { CourseCloud, CloudHead } from './CourseCloud';
export { SyncScope };
class SyncState {version:number=3;mode:string='manual';scope:SyncScope=new SyncScope();}
export class SyncResult {state:string='disabled';message:string='请选择同步范围和方式';changed:boolean=false;}
export class ManualSyncPreview {
  kind:string='';scope:SyncScope=new SyncScope();sourceRevision:number=0;cloudRevision:number=0;
  localTasks:number=0;localBlocks:number=0;localDiaries:number=0;
  cloudTasks:number=0;cloudBlocks:number=0;cloudDiaries:number=0;
  resultTasks:number=0;resultBlocks:number=0;resultDiaries:number=0;
  skippedBlocks:number=0;addedTasks:number=0;addedDiaries:number=0;
  owner:string='';localSignature:string='';generation:number=0;requestId:string='';attempted:boolean=false;
  candidate:MobileData=new MobileData();
}
function result(state:string,message:string,changed:boolean=false):SyncResult {const value=new SyncResult();value.state=state;value.message=message;value.changed=changed;return value;}

// Synchronization always starts with an explicit user choice, preview, then confirmation.
export class CloudSync {
  enabled:boolean=false;
  options:SyncScope=new SyncScope();
  private path:string='';
  private owner:string='guest';
  private generation:number=0;
  private running:boolean=false;
  init(context:common.Context,owner:string='guest'):void {
    if(owner!=='guest'&&!/^[a-f0-9-]{36}$/.test(owner)){throw new Error('账户标识无效');}
    this.generation++;this.owner=owner;this.path=`${context.getApplicationContext().filesDir}/whaletodo-sync-${owner}.json`;this.options=new SyncScope();this.enabled=false;
    if(fs.accessSync(this.path)){try{const saved=JSON.parse(fs.readTextSync(this.path)) as SyncState;if(saved.version===3&&saved.mode==='manual'){checkScope(saved.scope);this.options=saved.scope;}}catch{}}
    // Old automatic settings never start network activity or regain automatic sync.
  }
  private persist(scope:SyncScope):void {
    if(!this.path){throw new Error('同步尚未就绪');}const state=new SyncState();state.scope=scope;
    const bytes=new util.TextEncoder().encodeInto(JSON.stringify(state));const file=fs.openSync(`${this.path}.tmp`,fs.OpenMode.CREATE|fs.OpenMode.READ_WRITE|fs.OpenMode.TRUNC);
    try{let offset=0;while(offset<bytes.length){const count=fs.writeSync(file.fd,(bytes.buffer as ArrayBuffer).slice(offset));if(count<=0){throw new Error('同步偏好保存中断');}offset+=count;}fs.fsyncSync(file.fd);}finally{fs.closeSync(file);}fs.renameSync(`${this.path}.tmp`,this.path);
  }
  setOptions(scope:SyncScope):void {checkScope(scope);const next=JSON.parse(JSON.stringify(scope)) as SyncScope;this.persist(next);if(JSON.stringify(this.options)!==JSON.stringify(next)){this.generation++;}this.options=next;this.enabled=false;}
  setEnabled(value:boolean):void {if(value){throw new Error('请手动选择同步范围和方式');}this.persist(this.options);this.enabled=false;}
  acknowledge(_data:MobileData,_head:CloudHead):void {this.enabled=false;}
  // Retained defensively for old callers: no upload or download happens here.
  async synchronize(_cloud:CourseCloud,_read:()=>MobileData,_write:(data:MobileData)=>void):Promise<SyncResult> {return result('disabled','请手动选择同步范围和方式');}
  private valid(cloud:CourseCloud,preview:ManualSyncPreview):void {if(preview.owner!==this.owner||cloud.session.user.id!==this.owner||preview.generation!==this.generation||JSON.stringify(preview.scope)!==JSON.stringify(this.options)){throw new Error('账户或同步范围已变化，请重新预览');}}
  async preview(kind:string,scope:SyncScope,cloud:CourseCloud,data:MobileData,revision:number=0):Promise<ManualSyncPreview> {
    if(this.owner==='guest'||cloud.session.user.id!==this.owner){throw new Error('请先登录账户');}
    if(!['push','pull','merge'].includes(kind)||!Number.isSafeInteger(revision)||revision<0||(kind==='push'&&revision!==0)){throw new Error('同步方式或版本无效');}
    this.setOptions(scope);const p=new ManualSyncPreview();p.kind=kind;p.scope=JSON.parse(JSON.stringify(scope)) as SyncScope;p.owner=this.owner;p.generation=this.generation;p.requestId=uid('manual-sync');
    const local=checkData(clone(data));p.localSignature=JSON.stringify(local);const head=await cloud.head();this.valid(cloud,p);p.cloudRevision=head.revision;
    if(head.revision===0&&kind!=='push'){throw new Error('云端还没有备份，请先选择云端备份');}
    if(revision>head.revision){throw new Error('所选版本不存在');}p.sourceRevision=revision||head.revision;
    const remote=head.revision>0?(await cloud.download(p.sourceRevision)).snapshot:new MobileData();this.valid(cloud,p);
    const plan=buildSyncPlan(local,remote,kind,scope);p.candidate=plan.candidate;p.skippedBlocks=plan.skippedBlocks;p.addedTasks=plan.addedTasks;p.addedDiaries=plan.addedDiaries;
    p.localTasks=local.tasks.length;p.localBlocks=local.blocks.length;p.localDiaries=local.diaries.length;p.cloudTasks=remote.tasks.length;p.cloudBlocks=remote.blocks.length;p.cloudDiaries=remote.diaries.length;
    p.resultTasks=p.candidate.tasks.length;p.resultBlocks=p.candidate.blocks.length;p.resultDiaries=p.candidate.diaries.length;return p;
  }
  async apply(preview:ManualSyncPreview,cloud:CourseCloud,read:()=>MobileData,write:(data:MobileData)=>void):Promise<SyncResult> {
    if(this.running){throw new Error('正在处理，请稍后重试');}this.valid(cloud,preview);if(JSON.stringify(read())!==preview.localSignature){throw new Error('本机记录已变化，请重新预览');}
    this.running=true;
    try{
      const head=await cloud.head();this.valid(cloud,preview);if(JSON.stringify(read())!==preview.localSignature){throw new Error('本机记录已变化，请重新预览');}
      if(head.revision!==preview.cloudRevision&&!(preview.kind==='push'&&preview.attempted)){throw new Error('云端已有新版本，请重新预览后确认');}
      if(preview.kind==='push'){
        preview.attempted=true;const uploaded=await cloud.upload(clone(preview.candidate),preview.cloudRevision,preview.requestId);this.valid(cloud,preview);return result('applied',`所选内容已备份至云端 v${uploaded.revision}`);
      }
      const candidate=checkData(clone(preview.candidate));candidate.theme=read().theme;
      if(JSON.stringify(candidate)===JSON.stringify(read())){return result('applied','所选内容没有新的变化');}
      candidate.revision=read().revision+1;write(candidate);return result('applied',preview.kind==='merge'?`兼容同步完成${preview.skippedBlocks>0?`，${preview.skippedBlocks} 个冲突时段未导入，事项已保留待安排`:''}`:'所选范围已覆盖同步，未自动上传',true);
    }finally{this.running=false;}
  }
}
