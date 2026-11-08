import { AppTime } from '../model/AppTime';
export const MINUTE: number = 60000;
export const DAY: number = 86400000;
export class TaskWindow { date:string='';weekdays:number[]=[];startMinute:number=480;endMinute:number=1080; }
export class Task {
  id: string = '';
  parentId: string = '';
  kind: string = 'task';
  title: string = '';
  subject: string = '';
  note: string = '';
  deadline: number = 0;
  earliest: number = 0;
  minutes: number = 60;
  priority: number = 3;
  chunk: number = 45;
  splittable: boolean = true;
  archived: boolean = false;
  createdAt: number = 0;
  taskType:string='short';
  openEnded:boolean=false;
  windows:TaskWindow[]=[];
}
export class Block {
  timeZone?:string;
  id: string = '';
  taskId: string = '';
  start: number = 0;
  end: number = 0;
  locked: boolean = false;
  done: boolean = false;
  completedAt: number = 0;
  rating: number = 0;
  reflection: string = '';
}
export class FreeWindow {
  id: string = '';
  weekday: number = 1;
  date: string = '';
  startMinute: number = 1080;
  endMinute: number = 1320;
}
export class Course {
  id: string = '';
  title: string = '';
  location: string = '';
  start: number = 0;
  end: number = 0;
  weekdays: number[] = [];
  until: number = 0;
  weeks: number[] = [];
  source:string='manual';
  externalId:string='';
}
export class AIConfig {
  provider: string = '小艺';
  endpoint: string = '';
  model: string = '';
  protocol: string = 'openai';
  agentId: string = '';
  systemPrompt: string = '你是温和务实的课业安排助手。尊重学生的空闲、截止和休息，提出可执行的小步骤，不责备用户。';
}
export class PetLine {
  event: string = 'idle';
  text: string = '';
}
export class Settings {
  theme: string = 'system';
  systemDark: boolean = false;
  accent: string = '#6261DE';
  wallpaper: string = '';
  wallpaperOpacity: number = 0.18;
  termStart: number = 0;
  termWeeks: number = 20;
  horizonDays: number = 366;
  reminder: string = 'off';
  reminderLead: number = 10;
  reminderSent: string[] = [];
  petEnabled: boolean = true;
  petKind: string = 'cat';
  petImage: string = '';
  petSmart: boolean = false;
  petPrompt: string = '你是一只温柔的小猫学习伙伴。用简短、自然、体贴的话陪伴学习，不催促、不批评，提醒休息。';
  petLines: PetLine[] = [];
  petOverlay:boolean=true;
  petRoam:boolean=false;
  petAutoHide:boolean=true;
  petDockSeconds:number=15;
  petUseSharedModel:boolean=true;
  petProvider:string='';
  petAI:AIConfig=new AIConfig();
  petSize:number=76;
  calendarExports:string[]=[];
  productRevision:number=0;
  ai: AIConfig = new AIConfig();
  aiConfigs: AIConfig[] = [];
}
export class ChatMessage {
  id: string = '';
  role: string = 'user';
  content: string = '';
  createdAt: number = 0;
  proposal:string='';
  proposalState:string='';
  proposalRevision:number=0;
}
export class ChatSession {
  id:string='';title:string='新会话';createdAt:number=0;updatedAt:number=0;archived:boolean=false;
  messages:ChatMessage[]=[];
  draft:string='';
}
export class AppData {
  version: number = 1;
  revision: number = 0;
  tasks: Task[] = [];
  blocks: Block[] = [];
  free: FreeWindow[] = [];
  courses: Course[] = [];
  settings: Settings = new Settings();
  messages: ChatMessage[] = [];
  sessions:ChatSession[]=[];
  activeSessionId:string='';
  planningRevision:number=0;
  lastPlan: number = 0;
}
export class Unscheduled {
  taskId: string = '';
  minutes: number = 0;
  reason: string = '';
}
export class PlanResult {
  blocks: Block[] = [];
  unmet: Unscheduled[] = [];
  warnings: string[] = [];
  added: number = 0;
  moved: number = 0;
  preserved: number = 0;
}
export class LoadBucket {
  start: number = 0;
  end: number = 0;
  planned: number = 0;
  done: number = 0;
  capacity: number = 0;
  deadlines: number = 0;
}
export function uid(prefix: string = 'id'): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
export function cloneData(data: AppData): AppData { return JSON.parse(JSON.stringify(data)) as AppData; }
export class Failure { code?:number;message?:string; }
export function errorText(error:Object):string {
  if(error===null||error===undefined){return '操作失败，请重试';}if(typeof error==='string'){return String(error);}
  const value=error as Failure;const message=typeof value.message==='string'?value.message:'操作失败';return value.code===undefined?message:`${message}（${value.code}）`;
}
export function dayStart(time: number): number {return AppTime.dayStart(time);}
export function addDays(time: number, count: number): number {return AppTime.addDays(time,count);}
export function dateKey(time: number): string {
  return AppTime.dateKey(time);
}
export function clock(time: number): string {return AppTime.clock(time);}
export function formatDate(time: number): string { return `${dateKey(time)} ${clock(time)}`; }
export function parseLocalDateTime(text:string):number {
  const input=text.trim();if(!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(input)){return NaN;}
  const time=Date.parse(input.replace(' ','T'));return Number.isFinite(time)&&formatDate(time)===input?time:NaN;
}
export function hours(minutes: number): string { return `${Math.round(minutes/6)/10}h`; }
export function taskName(data: AppData, taskId: string): string { const t = data.tasks.find((item: Task) => item.id === taskId); return t === undefined ? '已删除的课业' : t.title; }
export function doneMinutes(data: AppData, taskId: string): number {
  return data.blocks.filter((b: Block) => b.taskId === taskId && b.done).reduce((sum: number, b: Block) => sum + (b.end-b.start)/MINUTE, 0);
}
export function remaining(data: AppData, task: Task): number { return Math.max(0, task.minutes - doneMinutes(data,task.id)); }
export function isDark(data: AppData): boolean { return data.settings.theme === 'dark' || (data.settings.theme === 'system' && data.settings.systemDark); }
export function bg(data: AppData): string { return isDark(data) ? '#141824' : '#F4F5FC'; }
export function ink(data: AppData): string { return isDark(data) ? '#F0F1FA' : '#252C46'; }
export function card(data: AppData): string { return isDark(data) ? '#E6222839' : '#EEFFFFFF'; }
export function muted(data: AppData): string { return isDark(data) ? '#A8B2CA' : '#768199'; }
export function priorityColor(priority: number): string { return priority >= 4.5 ? '#D96C73' : priority >= 3.5 ? '#C88C36' : priority >= 2.5 ? '#6261DE' : '#3F9B91'; }
export function defaultData(now: number = Date.now()): AppData {
  const d = new AppData(); d.settings.termStart = dayStart(now);
  for (let weekday = 0; weekday < 7; weekday++) {
    const f = new FreeWindow(); f.id = `default-${weekday}`; f.weekday = weekday;
    f.startMinute = weekday === 0 || weekday === 6 ? 9*60 : 18*60;
    f.endMinute = weekday === 0 || weekday === 6 ? 12*60 : 22*60; d.free.push(f);
  }
  const line = new PetLine(); line.event='idle'; line.text='把大事拆成一小步，今天也可以从容一点。'; d.settings.petLines.push(line);
  return d;
}
