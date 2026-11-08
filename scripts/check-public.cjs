const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),skip=new Set(['.git','node_modules','build','.gradle','.local-build','.hvigor','oh_modules','.tmp','.idea']);
const forbidden=/\.(?:p12|p7b|jks|keystore|dpapi|clixml|sqlite|db|log)$/i;
const patterns=[/-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----/,/\bgh[pousr]_[A-Za-z0-9]{30,}\b/,/\bgithub_pat_[A-Za-z0-9_]{30,}\b/,/\bsk-[A-Za-z0-9]{24,}\b/];
let count=0;
function scan(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){if(skip.has(entry.name))continue;const file=path.join(dir,entry.name);if(entry.isDirectory()){assert(entry.name!=='speech-model','Downloaded model must not enter source');scan(file);}else{const rel=path.relative(root,file);assert(!forbidden.test(entry.name),'Forbidden private/runtime file: '+rel);assert(!entry.name.startsWith('.env')||entry.name==='.env.example','Environment file: '+rel);const data=fs.readFileSync(file);if(!data.includes(0)){const text=data.toString('utf8');for(const pattern of patterns)assert(!pattern.test(text),'Credential-like content: '+rel);}count++;}}}
scan(root);console.log('Public-source checks passed for '+count+' files.');
