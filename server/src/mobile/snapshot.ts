import { createHash } from 'node:crypto';

export class MobileError extends Error {
  status:number;code:string;
  constructor(status: number, code: string, message: string) { super(message);this.status=status;this.code=code; }
}
const invalid = () => { throw new MobileError(400, 'INVALID_SNAPSHOT', '备份记录格式无效，未覆盖云端'); };
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return invalid();
  return value as Record<string, unknown>;
}
function integer(v: unknown, min: number, max: number) { return typeof v === 'number' && Number.isSafeInteger(v) && v >= min && v <= max; }
function text(v: unknown, max: number) { return typeof v === 'string' && v.length <= max; }
function zone(v:unknown):boolean {if(v===undefined)return true;if(typeof v!=='string'||v.length>80)return false;try{new Intl.DateTimeFormat('en',{timeZone:v});return true;}catch{return false;}}
export function validateSnapshot(input: unknown): string {
  const d = object(input);
  const allowed = ['version','revision','tasks','blocks','diaries','workStart','workEnd','theme','timeZone'];
  if (Object.keys(d).some(k => !allowed.includes(k)) || d.version !== 1 ||
      !Array.isArray(d.tasks) || !Array.isArray(d.blocks) || !Array.isArray(d.diaries) ||
      d.tasks.length > 10000 || d.blocks.length > 50000 || d.diaries.length > 10000 ||
      !integer(d.workStart,0,1439) || !integer(d.workEnd,1,1440) || Number(d.workStart) >= Number(d.workEnd) ||
      !['light','dark','system'].includes(String(d.theme)) || !zone(d.timeZone) || (d.revision !== undefined && !integer(d.revision,0,Number.MAX_SAFE_INTEGER))) invalid();
  const ids = new Set<string>();
  for (const raw of d.tasks as unknown[]) {
    const t = object(raw);
    if (!text(t.id,120) || !t.id || ids.has(String(t.id)) || !text(t.title,120) || !String(t.title).trim() ||
        !text(t.note,2000) || !text(t.category,120) || !integer(t.minutes,0,525600) || !integer(t.deadline,0,8640000000000000) ||
        typeof t.priority!=='number' || !Number.isFinite(t.priority) || t.priority<1 || t.priority>5 || typeof t.done !== 'boolean' || !integer(t.createdAt,0,8640000000000000) ||
        !integer(t.completedAt,0,8640000000000000) || !integer(t.rating,0,5) ||
        (t.repeat!==undefined&&!['none','daily','weekdays','weekly'].includes(String(t.repeat))) ||
        (t.deletedAt!==undefined&&!integer(t.deletedAt,0,8640000000000000)) ||
        (t.repeatSource!==undefined&&!text(t.repeatSource,120)) ||
        !zone(t.timeZone)||Object.keys(t).some(k=>!['id','title','note','category','minutes','deadline','priority','done','createdAt','completedAt','rating','repeat','deletedAt','repeatSource','timeZone'].includes(k))) invalid();
    ids.add(String(t.id));
  }
  const blocks = new Set<string>();
  for (const raw of d.blocks as unknown[]) {
    const b = object(raw);
    if (!text(b.id,200) || !b.id || blocks.has(String(b.id)) || !ids.has(String(b.taskId)) ||
        !integer(b.start,0,8640000000000000) || !integer(b.end,0,8640000000000000) || Number(b.start)>=Number(b.end) ||
        typeof b.locked!=='boolean' || typeof b.done!=='boolean' || !integer(b.completedAt,0,8640000000000000) ||
        !integer(b.rating,0,5) || !text(b.reflection,2000) ||
        !zone(b.timeZone)||Object.keys(b).some(k=>!['id','taskId','start','end','locked','done','completedAt','rating','reflection','timeZone'].includes(k))) invalid();
    blocks.add(String(b.id));
  }
  const days = new Set<string>();
  for (const raw of d.diaries as unknown[]) {
    const diary = object(raw);
    const day = String(diary.day);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(Date.parse(day+'T00:00:00Z')) ||
        new Date(day+'T00:00:00Z').toISOString().slice(0,10)!==day || days.has(day) || !text(diary.text,800) ||
        !zone(diary.timeZone)||Object.keys(diary).some(k=>!['day','text','timeZone'].includes(k))) invalid();
    days.add(day);
  }
  const value = JSON.stringify(d);
  if (Buffer.byteLength(value)>32*1024*1024) throw new MobileError(413,'SNAPSHOT_TOO_LARGE','备份超过当前32MiB传输能力，请分批整理或使用本地导出');
  return value;
}
export function digest(value: string) { return createHash('sha256').update(value).digest('hex'); }
