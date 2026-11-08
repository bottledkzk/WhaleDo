'use strict';
const assistantModes=['聊天','拆解任务','计划建议','回顾','日记润色','分享配文'];
Screens.assistant=()=>{
  const c=conversation();
  return h('section',{class:'assistant-page'},
    h('div',{class:'assistant-head'},button('历史',()=>panel('conversations'),'assistant-history','small'),h('h2',{class:'grow',id:'conversation-title'},c.title),button('新对话',newConversation,'assistant-new','small surface')),
    h('div',{class:'thread',id:'assistant-thread'}),
    h('div',{class:'assistant-composer',id:'assistant-composer'},
      h('div',{id:'assistant-photos',class:'photos'}),
      h('div',{class:'row assistant-context-row'},select(assistantModes,S.mode,i=>{S.mode=i;c.mode=i;draftLibrary();},'assistant-mode'),grow(h('span',{class:'note'},'附带日程与日记')),h('input',{type:'checkbox',class:'switch',checked:S.readAgenda,onChange:e=>S.readAgenda=e.target.checked,id:'assistant-context'})),
      textarea(c.draft,value=>{c.draft=value;draftLibrary();},{id:'assistant-input',class:'assistant-input',placeholder:'想聊些什么，或者一起理一理计划…',maxLength:200000}),
      h('div',{class:'assistant-tools',id:'assistant-tools'},
        button('添加图片',assistantPhoto,'assistant-add-image'),
        button('语音输入',()=>startVoice(assistantCaptured),'capture-voice'),
        button('音频转写',async()=>{toast('正在读取音频…');const text=await native('audioImport');if(text)previewCapture(text,assistantCaptured);},'capture-audio'),
        button('发送',sendAi,'assistant-send','primary'))));
};
function assistantCaptured(value){const c=conversation();c.draft=(c.draft?c.draft+'\n':'')+value;const input=document.getElementById('assistant-input');if(input)input.value=c.draft;draftLibrary();}
function refreshAssistant(){
  const thread=document.getElementById('assistant-thread');if(!thread)return;const c=conversation(),visible=c.visible||40,start=Math.max(0,c.messages.length-visible);
  const nodes=[...(!c.messages.length&&!c.pending?[h('div',{class:'starter stack'},h('h2',{},'开始新对话'),row(button('拆解一个目标',()=>{S.mode=1;c.mode=1;c.draft='帮我把这个目标拆成可执行的小任务：';document.getElementById('assistant-mode').value='1';document.getElementById('assistant-input').value=c.draft;draftLibrary();},'','small'),button('预览本地安排',localPlan,'assistant-local-plan','small surface')))]:[]),
    ...(start?[button('更早的对话',()=>{c.visible=visible+40;refreshAssistant();},'','small')]:[]),
    ...c.messages.slice(start).map((message,index)=>h('div',{class:'message '+message.role},h('div',{class:'who'},message.role==='user'?'我':'鲸办助手'),message.images?.length?h('div',{class:'photos'},...message.images.map(src=>h('img',{src,alt:'已选择图片'}))):null,h('div',{class:'text'},message.content),message.role==='assistant'?button(S.mode===5?'使用这段配文':'做成分享卡片',()=>assistantShare(message.content),'assistant-share-'+(start+index),'small'):null)),
    S.aiStorageError||S.aiStatus||c.pending?.message?h('p',{id:'assistant-status',class:'assistant-status'},S.aiStorageError||S.aiStatus||c.pending?.message):null,
    S.aiStorageError?button('重试保存',async()=>{await persistLibrary();S.aiStorageError='';refreshAssistant();},'assistant-retry-save','small'):null,
    c.pending?.rejected?button('修改本次请求',async()=>{const prior=c.pending;c.draft=prior.body.prompt;S.photos=prior.body.images||[];c.photos=S.photos;c.pending=null;await persistLibrary();render(true);},'assistant-edit-rejected','small'):null,
    c.result&&C.AssistantPlan.planSize(c.result)>0&&!c.result.applied?button('查看 '+C.AssistantPlan.planSize(c.result)+' 项提案',()=>openAiProposal(c.result),'ai-proposal-open','primary'):null,
    S.aiUndo?button('撤销刚才的提案',undoAssistant,'ai-undo-assistant'):null,
    S.mode===4&&c.result?button('编辑为日记',()=>{S.diaryDay=T.dateKey(Date.now());S.diaryText=c.result.text.slice(0,800);panel('diary');},'assistant-diary'):null,
    c.pending?.jobId?button(c.pending.finished?'结束这次请求':'停止本次请求',cancelAi,'assistant-cancel','small surface'):null];
  thread.replaceChildren(...nodes.filter(node=>node!==null&&node!==undefined&&node!==false));
  const photos=document.getElementById('assistant-photos');photos.replaceChildren(...S.photos.map((src,index)=>h('div',{class:'assistant-photo'},h('img',{src,alt:'已选择图片'}),button('移除',async()=>{S.photos.splice(index,1);c.photos=S.photos;await persistLibrary();refreshAssistant();},'assistant-remove-image-'+index,'small flat'))));
  document.getElementById('conversation-title').textContent=c.title;
  const blocked=S.aiBusy||!!c.pending;
  for(const id of ['assistant-add-image','capture-voice','capture-audio','assistant-mode','assistant-context'])document.getElementById(id).disabled=blocked;
  document.getElementById('assistant-input').disabled=!!c.pending&&!c.pending.jobId;
  const send=document.getElementById('assistant-send');send.textContent=S.aiBusy?'处理中…':c.pending?'继续检查':'发送';send.disabled=S.aiBusy||!!S.aiStorageError;
  requestAnimationFrame(()=>{thread.scrollTop=thread.scrollHeight;});
}
async function newConversation(){if(S.library?.items.length>=1000)throw new Error('会话较多，请先整理已有对话');if(S.library)await persistLibrary();const item=newConversationValue();S.library.items.push(item);S.library.current=item.id;S.mode=0;S.photos=[];S.aiStatus='';await persistLibrary();if(S.tab===3&&!S.panel)render(true);}
function openConversation(id){S.library.current=id;const c=conversation();S.mode=c.mode||0;S.photos=c.photos||[];S.aiStatus='';persistLibrary().catch(fail);S.panel='';S.parents=[];S.tab=3;render(true);}
Screens.conversations=()=>{const query=S.conversationQuery||'',archived=!!S.showArchived,rows=S.library.items.filter(c=>c.archived===archived&&c.title.toLowerCase().includes(query.toLowerCase())).sort((a,b)=>Number(b.pinned)-Number(a.pinned)||b.updatedAt-a.updatedAt);return page('历史对话',input(query,value=>{S.conversationQuery=value;refreshConversationRows();},{type:'search',placeholder:'搜索对话',id:'conversation-search'}),toggle('已归档',archived,value=>{S.showArchived=value;render(true);}),h('div',{id:'conversation-rows',class:'stack'},...rows.map(conversationRow)));};
function refreshConversationRows(){const list=document.getElementById('conversation-rows');list.replaceChildren(...S.library.items.filter(c=>c.archived===!!S.showArchived&&c.title.toLowerCase().includes((S.conversationQuery||'').toLowerCase())).sort((a,b)=>Number(b.pinned)-Number(a.pinned)||b.updatedAt-a.updatedAt).map(conversationRow));}
function conversationRow(c){return h('div',{class:'card stack'},row(h('h3',{class:'grow',onClick:()=>openConversation(c.id)},(c.pinned?'· ':'')+c.title),button('···',()=>menu(c.title,[{label:c.pinned?'取消置顶':'置顶',action:async()=>{c.pinned=!c.pinned;await persistLibrary();render(true);}},{label:'重命名',action:()=>{let title=c.title;dialog('重命名对话',input(title,v=>title=v,{maxLength:80}),[button('取消',closeDialog),button('保存',async()=>{if(!title.trim())throw new Error('请输入对话名称');c.title=title.trim();c.manualTitle=true;await persistLibrary();closeDialog();render(true);},'','primary')]);}},{label:c.archived?'恢复对话':'归档',action:async()=>{c.archived=!c.archived;await persistLibrary();render(true);}}]),'','small flat')),h('p',{class:'note',onClick:()=>openConversation(c.id)},M.localText(c.updatedAt)+(c.pending?' · 待继续':'')));}
async function assistantPhoto(){if(S.photos.length>=4)throw new Error('每次最多选择4张图片');menu('添加图片',[{label:'拍照',action:()=>takeAssistantPhoto(true)},{label:'从相册选择',action:()=>takeAssistantPhoto(false)}]);}
async function takeAssistantPhoto(camera){const photo=await native(camera?'camera':'photo');if(!photo)return;S.photos.push(photo.dataUri);conversation().photos=S.photos;await persistLibrary();refreshAssistant();}
async function api(path,method='GET',body){return native('api',{path,method,...body===undefined?{}:{body}});}
async function sendAi(){
  if(!S.user.id){openAccount();return;}if(S.aiBusy)return;if(S.aiStorageError)throw new Error('请先重试保存本次内容');const c=conversation();
  if(!c.pending){
    let prompt=c.draft.trim();if(!prompt&&S.photos.length)prompt='请理解图片内容，并根据我的需要提供帮助。';if(!prompt)throw new Error('先写下想法，或者需要拆解的目标');
    if(S.mode===4)prompt='请将下面的真实记录润色成日记，保留事实，不编造经历。\n'+prompt;
    if(S.mode===5)prompt='请根据下列内容和指定风格撰写简短自然的分享配文，不编造完成情况。\n'+prompt;
    const now=Date.now(),body={kind:S.mode===1?'tasks':S.mode===2?'plan':S.mode===3?'review':'chat',prompt,requestId:M.uid('ai'),now,timezoneOffsetMinutes:-T.offset(now)/60000};
    if(S.readAgenda)body.context=C.SyncPlan.serverSnapshot(S.data);if(S.photos.length)body.images=S.photos.slice();body.history=C.AiHistory.boundedHistory(c.messages.map(m=>({role:m.role,content:m.content,images:m.images})),JSON.stringify(body));
    c.pending={body,jobId:'',signature:JSON.stringify(S.data),message:'正在确认请求…',rejected:false};await persistLibrary();
  }
  document.getElementById('assistant-input')?.blur();await continueAi(c);
}
async function continueAi(c){
  if(!c.pending||S.aiBusy)return;const pending=c.pending,owner=S.owner,epoch=S.epoch;S.aiBusy=true;S.aiStatus='正在连接助手…';refreshAssistant();
  try{
    await persistLibrary();let receipt;
    if(pending.jobId)receipt=await api('/ai/jobs/'+encodeURIComponent(pending.jobId));
    else{
      const status=await aiAvailability();if(!status.enabled)throw new Error('智能助手暂未开放，本次内容已保留');
      receipt=await api('/ai/jobs','POST',pending.body);pending.jobId=receipt.id;
      if(!c.messages.some(m=>m.requestId===pending.body.requestId)){c.messages.push({role:'user',content:pending.body.prompt,images:pending.body.images,requestId:pending.body.requestId});}
      if(!c.manualTitle)c.title=pending.body.prompt.slice(0,60);c.updatedAt=Date.now();c.draft='';c.photos=[];
      if(S.library.current===c.id){S.photos=[];const input=document.getElementById('assistant-input');if(input)input.value='';}
      await persistLibrary();
    }
    const started=Date.now();
    while(['queued','running'].includes(receipt.status)&&owner===S.owner&&epoch===S.epoch&&Date.now()-started<10*60000){
      S.aiStatus=receipt.status==='queued'?'等待助手…':'正在思考…';pending.message=S.aiStatus;if(S.library.current===c.id)refreshAssistant();await new Promise(resolve=>setTimeout(resolve,1200));receipt=await api('/ai/jobs/'+encodeURIComponent(receipt.id));
    }
    if(owner!==S.owner||epoch!==S.epoch)return;
    if(receipt.status==='completed'){
      const result=receipt.result;c.result={...result,baseSignature:pending.signature};if(!c.messages.some(m=>m.jobId===receipt.id))c.messages.push({role:'assistant',content:result.text,jobId:receipt.id});c.pending=null;c.updatedAt=Date.now();S.aiStatus='';await persistLibrary();
    }else if(['failed','cancelled'].includes(receipt.status)){
      pending.message=receipt.error?.message||(receipt.status==='cancelled'?'请求已取消':'这次请求未完成');pending.finished=true;S.aiStatus=pending.message;await persistLibrary();
    }else{pending.message='暂未确认结果，可继续检查同一次请求';S.aiStatus=pending.message;await persistLibrary();}
  }catch(error){if(epoch===S.epoch){pending.rejected=[400,413].includes(error.status);pending.message=error.message;S.aiStatus=error.message;try{await persistLibrary();}catch{S.aiStorageError='本次内容尚未保存，请重试保存';}}}
  finally{if(epoch===S.epoch){S.aiBusy=false;if(!S.panel&&S.tab===3)refreshAssistant();}}
}
let availability=null,availabilityAt=0,availabilityOwner='';
async function aiAvailability(){if(availabilityOwner===S.owner&&Date.now()-availabilityAt<30000&&availability?.enabled)return availability;const result=await api('/ai/status');availability=result;availabilityAt=Date.now();availabilityOwner=S.owner;return result;}
async function cancelAi(){const c=conversation(),p=c.pending;if(!p)return;if(p.finished){confirmAction('结束这次请求？',p.message||'本次请求已结束。',async()=>{c.pending=null;await persistLibrary();refreshAssistant();},'结束');return;}if(!p.jobId)throw new Error('接收结果尚未确认，请先继续检查');const receipt=await api('/ai/jobs/'+encodeURIComponent(p.jobId)+'/cancel','POST',{});p.message=receipt.status==='cancelled'?'请求已取消':'结果仍在确认中';if(receipt.status==='cancelled')p.finished=true;await persistLibrary();refreshAssistant();}
function openAiProposal(result){S.aiProposal=result;panel('ai-proposal');}
Screens['ai-proposal']=()=>{const p=S.aiProposal,lookup=id=>id.startsWith('new:')?p.tasks[Number(id.slice(4))]?.title||'新事项':taskName(id);return page('事项与日程提案',h('p',{class:'note'},p.text),...p.tasks.map(t=>h('div',{class:'card stack'},h('h3',{},'新增 · '+t.title),h('p',{class:'note'},`${t.minutes}分钟${t.deadline?' · 截止 '+M.localText(t.deadline):''}`))),...(p.edits||[]).map(t=>h('div',{class:'card stack'},h('h3',{},'编辑 · '+taskName(t.taskId)),h('p',{},t.title),h('p',{class:'note'},`${t.minutes}分钟${t.deadline?' · 截止 '+M.localText(t.deadline):''}`))),...(p.schedule||[]).map(b=>h('div',{class:'card stack'},h('h3',{},lookup(b.taskId)),h('p',{class:'note'},M.localText(b.start)+' – '+M.localText(b.end)))),...(p.warnings||[]).map(text=>h('p',{class:'note'},text)),button('同意并应用提案',async()=>{if(JSON.stringify(S.data)!==p.baseSignature)throw new Error('本机记录已变化，请重新生成提案');const before=M.clone(S.data),next=C.AssistantPlan.applyAssistantPlan(S.data,p);await save(next,'提案已应用');S.aiUndo={before,signature:JSON.stringify(S.data)};p.applied=true;back();},'ai-proposal-confirm','primary'));};
function undoAssistant(){confirmAction('撤销刚才的 AI 提案？','恢复应用提案前的事项和安排。',async()=>{const undo=S.aiUndo;if(!undo||JSON.stringify(S.data)!==undo.signature)throw new Error('记录已变化，不能撤销这次提案');await save(undo.before,'已撤销提案');render(true);},'撤销');}
function assistantShare(text){if(S.mode===5){const card=S.captionCard;openShare();if(card)Object.assign(S.share,{style:card.style,title:card.title,body:card.lines.join('\n')});S.share.caption=text.slice(0,2000);}else{openShare();S.share.title='一点小想法';S.share.body=text.split('\n').filter(Boolean).slice(0,5).join('\n').slice(0,1000);}render(true);}
