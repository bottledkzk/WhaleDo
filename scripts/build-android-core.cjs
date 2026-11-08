/* Package the same course business modules, without duplicating scheduling or sync rules. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),source=path.join(root,'harmony/entry/src/main/ets');
const destination=path.join(root,'android/app/src/main/assets');
let ts;for(const candidate of [process.env.TYPESCRIPT_PATH,path.join(root,'android/node_modules/typescript'), 'typescript',null].filter(Boolean)){try{ts=require(candidate);break;}catch{}}
if(!ts)throw Error('Install TypeScript or set TYPESCRIPT_PATH.');
const names=['engine/Types','engine/TaskRules','engine/Scheduler','model/AppTime','model/AppTheme','model/MobileModel','model/SyncPlan','model/AssistantPlan','model/CalendarImport','model/SharingModel','model/ReminderPlan','model/ZonePolicy','model/AudioWav','model/AiHistory'];
const hashes={},chunks=[];
for(const name of names){const text=fs.readFileSync(path.join(source,name+'.ets'),'utf8');if(/@kit\.|@ohos\./.test(text))throw Error('Native module in shared core');hashes[name]=crypto.createHash('sha256').update(text).digest('hex');const code=ts.transpileModule(text,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS},fileName:name+'.ts'}).outputText;chunks.push(`${JSON.stringify(name)}:function(require,module,exports){\n${code}\n}`);}
const wrapper=`/* Generated from canonical Harmony course modules. Run script/build_whaledo_android_core.cjs. */\n(function(){'use strict';const modules={${chunks.join(',\n')}},cache={};function load(name){if(cache[name])return cache[name].exports;if(!modules[name])throw Error('Unknown core module '+name);const m={exports:{}};cache[name]=m;modules[name](rel=>{const a=name.split('/');a.pop();for(const s of rel.split('/')){if(s==='..')a.pop();else if(s!=='.')a.push(s);}return load(a.join('/'));},m,m.exports);return m.exports;}window.WhaleCore=Object.fromEntries(${JSON.stringify(names)}.map(n=>[n.split('/').pop(),load(n)]));})();\n`;
fs.mkdirSync(destination,{recursive:true});fs.writeFileSync(path.join(destination,'core.js'),wrapper);fs.writeFileSync(path.join(destination,'core-sources.json'),JSON.stringify(hashes,null,2)+'\n');
const media=path.join(source,'../resources/base/media'),assets=path.join(destination,'media');fs.mkdirSync(assets,{recursive:true});
for(const name of fs.readdirSync(media).filter(n=>/^(whaledo_mascot|launcher_icon|share_|nav_)/.test(n)))fs.copyFileSync(path.join(media,name),path.join(assets,name));
const icons=path.join(destination,'../res/drawable');fs.mkdirSync(icons,{recursive:true});fs.copyFileSync(path.join(media,'launcher_icon.png'),path.join(icons,'launcher_icon.png'));
console.log('Shared '+names.length+' unchanged course modules and matching visual assets.');
