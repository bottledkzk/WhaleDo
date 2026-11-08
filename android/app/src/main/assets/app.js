'use strict';
const C=window.WhaleCore,M=C.MobileModel,T=C.AppTime.AppTime;
const Screens={};
const S={owner:'guest',user:{id:'',username:''},epoch:0,data:new M.MobileData(),tab:0,panel:'',parents:[],ready:false,systemDark:false,systemZone:'UTC',selected:Date.now(),month:Date.now(),calendarView:'month',query:'',showDone:false,agenda:false,busy:false,undo:null,aiUndo:null,library:null,aiBusy:false,aiStatus:'',photos:[],mode:0,readAgenda:false,share:null,pendingFeed:null,reminderOptions:new C.ReminderPlan.ReminderOptions(),remindersEnabled:false};
let sequence=0,toastTimer,libraryTimer,writeQueue=Promise.resolve();const waiting=new Map();
function native(command,params={}){
  const id='n_'+Date.now()+'_'+(++sequence),owner=S.owner,epoch=S.epoch;
  return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{waiting.delete(id);reject(new Error('操作尚未确认，可稍后重试'));},90000);waiting.set(id,{resolve,reject,timer,epoch,command});
    try{window.WhaleNative.postMessage(JSON.stringify({id,command,params:{owner,...params}}));}catch(e){clearTimeout(timer);waiting.delete(id);reject(e);}
  });
}
function setupBridge(){
  window.WhaleNative.onmessage=event=>{let result;try{result=JSON.parse(event.data);}catch{return;}const pending=waiting.get(result.id);if(!pending)return;waiting.delete(result.id);clearTimeout(pending.timer);
    if(pending.epoch!==S.epoch&&!['login','logout','bootstrap'].includes(pending.command)){pending.reject(new Error('账户已切换，请重试'));return;}
    if(result.ok)pending.resolve(result.data);else{const error=new Error(result.error||'操作未完成，请重试');error.status=result.status;pending.reject(error);}
  };
}
function h(tag,props,...children){const element=document.createElement(tag);for(const [key,value] of Object.entries(props||{})){if(value===undefined||value===null)continue;if(key==='class')element.className=value;else if(key==='style')Object.assign(element.style,value);else if(key.startsWith('on'))element.addEventListener(key.slice(2).toLowerCase(),event=>{try{Promise.resolve(value(event)).catch(fail);}catch(error){fail(error);}});else if(key in element)element[key]=value;else element.setAttribute(key,value);}for(const child of children.flat(Infinity)){if(child===null||child===undefined||child===false)continue;element.append(child instanceof Node?child:document.createTextNode(String(child)));}return element;}
function button(text,action,id='',className=''){return h('button',{type:'button',id,class:className,onClick:action},text);}
function row(...children){return h('div',{class:'row'},...children);}function stack(...children){return h('div',{class:'stack'},...children);}function grow(...children){return h('div',{class:'grow'},...children);}
function field(text){return h('div',{class:'field'},text);}function section(text,detail=''){return h('div',{class:'section'},h('strong',{},text),h('small',{},detail));}function empty(text){return h('div',{class:'empty'},text);}
function input(value,onInput,props={}){return h('input',{value,onInput:event=>onInput(event.target.value),...props});}function textarea(value,onInput,props={}){return h('textarea',{value,onInput:event=>onInput(event.target.value),...props});}
function select(labels,selected,onChange,id=''){return h('select',{id,onChange:event=>onChange(Number(event.target.value))},labels.map((text,index)=>h('option',{value:String(index),selected:index===Math.max(0,selected)},text)));}
function toggle(label,checked,onChange,id=''){return row(grow(label),h('input',{type:'checkbox',class:'switch',id,checked,onChange:event=>onChange(event.target.checked)}));}
function toast(text){const node=document.getElementById('toast');node.textContent=text;node.classList.add('visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>node.classList.remove('visible'),3000);}function fail(error){toast(error.message||'操作未完成，请重试');}
function dialog(title,content,actions){const root=document.getElementById('modal');root.replaceChildren(h('div',{class:'modal-cover'},h('div',{class:'dialog',role:'dialog','aria-label':title},h('h2',{},title),typeof content==='string'?h('p',{},content):content,h('div',{class:'actions'},...actions))));}
function closeDialog(){document.getElementById('modal').replaceChildren();}
function confirmAction(title,text,accept,label='确认'){dialog(title,text,[button('取消',closeDialog),button(label,async()=>{closeDialog();await accept();},'confirm-action','primary')]);}
function menu(title,items){dialog(title,h('div',{class:'choices'},items.map(item=>button(item.label,async()=>{closeDialog();await item.action();}))),[button('取消',closeDialog)]);}
function read(name){return native('read',{name});}function write(name,value){return native('write',{name,value});}
async function save(candidate,message='已保存'){
  const owner=S.owner,epoch=S.epoch,next=M.checkData(M.clone(candidate));next.revision=S.data.revision+1;
  await write('data',next);if(owner!==S.owner||epoch!==S.epoch)throw new Error('账户已切换，请重试');S.data=next;T.zone=next.timeZone||S.systemZone;S.undo=null;S.aiUndo=null;applyTheme();if(message)toast(message);if(S.remindersEnabled)await syncReminders();return next;
}
function applyTheme(){const dark=S.data.theme==='dark'||S.data.theme==='system'&&S.systemDark;const colors=C.AppTheme.themeColors(dark,S.data.tone||'whale');for(const [key,value] of Object.entries(colors))document.documentElement.style.setProperty('--'+key,value);document.documentElement.style.setProperty('--r',S.data.corners==='square'?'0':'1');native('appearance',{dark,paper:colors.paper,ink:colors.ink,accent:colors.accent}).catch(()=>{});}
function offset(zone,at){if(zone==='system')return -new Date(at).getTimezoneOffset()*60000;const parts=new Intl.DateTimeFormat('en-GB',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(new Date(at));const p=Object.fromEntries(parts.map(x=>[x.type,x.value]));return Date.UTC(+p.year,+p.month-1,+p.day,+p.hour,+p.minute,+p.second)-Math.floor(at/1000)*1000;}
async function loadOwner(){
  S.epoch++;S.panel='';S.parents=[];S.photos=[];S.share=null;S.pendingFeed=null;S.undo=null;S.aiUndo=null;S.aiBusy=false;S.aiStatus='';
  const values=await Promise.all([read('data'),read('library'),read('reminders'),read('pending-feed')]);
  S.data=values[0]?M.checkData(values[0]):new M.MobileData();T.zone=S.data.timeZone||S.systemZone;
  S.library=values[1]||newLibrary();validateLibrary(S.library);const reminders=values[2];S.reminderOptions=reminders?.options||new C.ReminderPlan.ReminderOptions();S.remindersEnabled=!!reminders?.enabled;S.pendingFeed=values[3];
  S.selected=T.dayStart(Date.now());S.month=S.selected;S.ready=true;applyTheme();render();
}
function newConversationValue(){return {id:M.uid('conversation'),title:'新对话',manualTitle:false,pinned:false,archived:false,updatedAt:Date.now(),messages:[],draft:'',pending:null,result:null};}
function newLibrary(){const item=newConversationValue();return {version:1,owner:S.owner,current:item.id,items:[item]};}
function validateLibrary(value){if(value.version!==1||value.owner!==S.owner||!Array.isArray(value.items)||!value.items.length||value.items.length>1000||!value.items.some(c=>c.id===value.current)||value.items.some(c=>typeof c.id!=='string'||!Array.isArray(c.messages)||typeof c.draft!=='string'||typeof c.title!=='string'))throw new Error('助手会话无法读取，原记录已保留');}
function conversation(){return S.library.items.find(item=>item.id===S.library.current);}
function persistLibrary(){clearTimeout(libraryTimer);const captured=JSON.parse(JSON.stringify(S.library)),owner=S.owner;writeQueue=writeQueue.catch(()=>{}).then(()=>{if(owner!==S.owner)throw new Error('账户已切换');return write('library',captured);});return writeQueue;}
function draftLibrary(){clearTimeout(libraryTimer);libraryTimer=setTimeout(()=>persistLibrary().catch(fail),400);}
function panel(name){S.parents.push(S.panel);S.panel=name;render(true);}function back(){if(document.getElementById('modal').childNodes.length){closeDialog();return;}if(S.panel){S.panel=S.parents.pop()||'';render(true);}else if(S.tab!==0){S.tab=0;render(true);}else native('closeApp').catch(fail);}
function header(){const date=T.civil(Date.now());const hours=M.workHoursOn(S.data,Date.now());return h('header',{class:'header'},grow(h('div',{class:'brand'},'鲸办 WhaleDo'),h('div',{class:'date'},`${date.getUTCMonth()+1}月${date.getUTCDate()}日 星期${['日','一','二','三','四','五','六'][date.getUTCDay()]}`)),button(h('span',{},'行动时间',h('small',{},M.minuteText(hours.start)+'–'+M.minuteText(hours.end))),()=>openWork(true),'worktime','worktime'));}
function panelHeader(title){return h('header',{class:'panel-header'},button('‹',back,'back-panel'),h('h1',{class:'grow'},title));}
function navigation(){return h('nav',{class:'navigation','aria-label':'主导航'},['今日','待办','日历','助手','我的'].map((label,i)=>button([h('span',{class:'nav-icon'},h('i',{style:{maskImage:`url(media/nav_${['today','tasks','calendar','assistant','profile'][i]}.svg)`,webkitMaskImage:`url(media/nav_${['today','tasks','calendar','assistant','profile'][i]}.svg)`}})),h('span',{},label)],()=>{S.tab=i;S.panel='';S.parents=[];render(true);},'nav-'+i,S.tab===i?'active':'')));}
function render(force=false){
  if(!S.ready)return;
  if(!force&&!S.panel&&S.tab===3&&document.getElementById('assistant-input')){refreshAssistant();return;}
  const root=document.getElementById('app');let content;
  try{content=S.panel?Screens[S.panel]?.():[Screens.today,Screens.todo,Screens.calendar,Screens.assistant,Screens.profile][S.tab]?.();if(!content)throw new Error('页面尚未就绪');}
  catch(error){root.replaceChildren(h('div',{class:'content top stack'},h('h2',{},'暂时无法打开'),h('p',{},error.message),button('返回',()=>{S.panel='';S.tab=0;render(true);})));return;}
  root.replaceChildren(...(!S.panel&&S.tab<3?[header()]:[]),...Array.isArray(content)?content:[content],...(!S.panel?[navigation()]:[]));
  if(!S.panel&&S.tab>0&&S.tab<3)root.append(button('+',()=>openTask(),'floating-capture','floating'));
  if(!S.panel&&S.tab===3)refreshAssistant();
}
function content(...children){return h('section',{class:'content stack'},...children);}function page(title,...children){return [panelHeader(title),content(...children)];}
function avatar(){return S.data.avatar?'https://appassets.androidplatform.net/avatar/'+S.data.avatar:'media/launcher_icon.png';}
function categories(){return [...new Set(['生活','学习','工作','运动','其它',...M.activeTasks(S.data).map(t=>t.category)])];}
function planned(day){const start=T.dayStart(day),end=T.addDays(start,1);return S.data.blocks.filter(b=>b.start<end&&b.end>start).sort((a,b)=>a.start-b.start);}
function taskName(id){return S.data.tasks.find(t=>t.id===id)?.title||'事项';}
function taskCard(task){return h('div',{class:'card task'},h('input',{type:'checkbox',id:'complete-'+task.id,checked:task.done,'aria-label':task.title,onChange:()=>completeTask(task)}),h('div',{class:'grow',onClick:()=>openTask(task)},h('div',{class:'task-title'+(task.done?' done':'')},task.title),h('div',{class:'task-meta'},`${task.category} · ${task.minutes?task.minutes+'分钟':'待整理'}${task.deadline?' · '+M.localText(task.deadline):''}${task.repeat!=='none'?' · '+repeatLabel(task.repeat):''}`)),task.priority>=4&&!task.done?h('span',{class:'badge',onClick:()=>openTask(task)},'重要'):null);}
function timeCard(block){const allDay=M.allDayEvent(S.data,block);return h('div',{class:'timecard',onClick:()=>openTask(S.data.tasks.find(t=>t.id===block.taskId))},h('div',{class:'times'},h('b',{},allDay?'全天':T.clock(block.start)),h('small',{},allDay?T.dateKey(block.start).slice(5):T.clock(block.end))),h('div',{class:'block'},row(grow(h('h3',{},taskName(block.taskId)),h('p',{},allDay?'系统日历':block.locked?'固定安排':'行动安排')),h('span',{style:{color:'var(--accent)'}},block.done?'✓':'●'))));}
function repeatLabel(value){return {none:'不重复',daily:'每天',weekdays:'工作日',weekly:'每周'}[value]||'不重复';}
function stars(value,onChange,id){const node=h('div',{class:'stars',id});for(let n=1;n<=5;n++)node.append(button('★',()=>{onChange(n);for(let i=0;i<5;i++)node.children[i].classList.toggle('on',i<n);},id+'-'+n,n<=value?'on':''));return node;}
async function completeTask(task){if(task.done){await save(M.finishTask(S.data,task.id,task.rating||3));render();return;}let rating=3;dialog('完成自评',stars(rating,v=>rating=v,'complete-rating'),[button('取消',()=>{closeDialog();render(true);}),button('完成',async()=>{closeDialog();await save(M.finishTask(S.data,task.id,rating),'已完成');render(true);},'complete-confirm','primary')]);}
function captureTools(apply){return h('div',{class:'capture-tools'},button('图片识字',async()=>{const text=await native('ocr');if(text)previewCapture(text,apply);},'capture-ocr'),button('语音输入',()=>startVoice(apply),'capture-voice'),button('音频转写',async()=>{toast('正在读取音频…');const text=await native('audioImport');if(text)previewCapture(text,apply);},'capture-audio'));}
function previewCapture(text,apply){let value=text;dialog('识别内容',textarea(value,v=>value=v,{id:'capture-result'}),[button('取消',closeDialog),button('填入草稿',()=>{closeDialog();apply(value);},'capture-apply','primary')]);}
let voiceApply=null;
async function startVoice(apply){voiceApply=apply;await native('speechStart');voiceDialog('正在准备…');}
function voiceDialog(text){dialog('语音输入',h('p',{id:'voice-preview'},text),[button('取消',async()=>{await native('speechStop',{cancel:true});closeDialog();}),button('结束听写',()=>native('speechStop',{cancel:false}),'voice-finish','primary')]);}
window.__nativeEvent=(type,p)=>{
  if(type==='keyboard')document.body.classList.toggle('keyboard',p.visible);
  else if(type==='back')back();
  else if(type==='configuration'){S.systemDark=matchMedia('(prefers-color-scheme:dark)').matches;applyTheme();}
  else if(type==='speech'&&p.owner===S.owner){if(p.state==='complete'){closeDialog();if(p.text)previewCapture(p.text,voiceApply||(()=>{}));else if(p.error)toast(p.error);}else if(p.state==='error'){closeDialog();toast(p.error);}else if(p.state==='cancelled')closeDialog();else{const preview=document.getElementById('voice-preview');if(preview)preview.textContent=p.text||(p.state==='listening'?'正在听写…':'正在准备…');}}
};
document.addEventListener('DOMContentLoaded',async()=>{try{setupBridge();const boot=await native('bootstrap');S.owner=boot.owner;S.user=boot.user;S.systemZone=boot.systemZone;S.systemDark=boot.systemDark;T.configure(offset,boot.systemZone);await loadOwner();}catch(error){document.getElementById('app').replaceChildren(h('div',{class:'content top stack'},h('h1',{},'鲸办 WhaleDo'),h('p',{},error.message),button('重试',()=>location.reload())));}});
