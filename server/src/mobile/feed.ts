import { DatabaseSync } from 'node:sqlite';
import { randomUUID, createHash } from 'node:crypto';
import { MobileError } from './snapshot.ts';

export interface FeedCard { title:string; lines:string[]; style:number; date:string; footer:string; }
export interface FeedPost { id:string; author:string; card:FeedCard; caption:string; createdAt:number; likes:number; liked:boolean; mine:boolean; }
type Row = { id:string; user_id:string; author:string; card:string; caption:string; created_at:number; likes:number; liked:number; seq:number };
const invalid=():never=>{throw new MobileError(400,'INVALID_FEED_POST','请检查分享标题、内容和配文');};
const clean=(v:unknown,max:number,required=false):string=>{if(typeof v!=='string'||v.length>max||/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(v)||required&&!v.trim())return invalid();return v.trim();};
export function feedDraft(raw:unknown):{requestId:string;author:string;card:FeedCard;caption:string} {
  if(!raw||typeof raw!=='object'||Array.isArray(raw))return invalid();
  const b=raw as Record<string,unknown>,c=b.card as Record<string,unknown>;
  if(Object.keys(b).some(k=>!['requestId','author','card','caption'].includes(k))||typeof b.requestId!=='string'||!/^[A-Za-z0-9_-]{8,120}$/.test(b.requestId)||!c||typeof c!=='object'||Array.isArray(c)||Object.keys(c).some(k=>!['title','lines','style','date','footer'].includes(k)))return invalid();
  if(!Number.isInteger(c.style)||Number(c.style)<0||Number(c.style)>2||!Array.isArray(c.lines)||c.lines.length>5||typeof c.date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(c.date))return invalid();
  return {requestId:b.requestId,author:clean(b.author,40,true),caption:clean(b.caption,2000),card:{title:clean(c.title,60,true),lines:c.lines.map(line=>clean(line,200)),style:Number(c.style),date:c.date,footer:clean(c.footer,40)}};
}

/** A separate public feed. It never reads private snapshots or AI history. */
export class MobileFeed {
  private db:DatabaseSync;
  private now:()=>number;
  constructor(file:string,now:()=>number=Date.now) {
    this.now=now;
    this.db=new DatabaseSync(file);
    this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS mobile_feed_posts(seq INTEGER PRIMARY KEY AUTOINCREMENT,id TEXT UNIQUE NOT NULL,user_id TEXT NOT NULL REFERENCES mobile_users(id),request_id TEXT NOT NULL,fingerprint TEXT NOT NULL,author TEXT NOT NULL,card TEXT NOT NULL,caption TEXT NOT NULL,created_at INTEGER NOT NULL,deleted INTEGER NOT NULL DEFAULT 0,UNIQUE(user_id,request_id));
      CREATE TABLE IF NOT EXISTS mobile_feed_likes(post_id TEXT NOT NULL REFERENCES mobile_feed_posts(id),user_id TEXT NOT NULL REFERENCES mobile_users(id),PRIMARY KEY(post_id,user_id));
      CREATE INDEX IF NOT EXISTS mobile_feed_page ON mobile_feed_posts(deleted,seq DESC);
      CREATE INDEX IF NOT EXISTS mobile_feed_owner ON mobile_feed_posts(user_id,seq DESC);`);
  }
  close(){this.db.close();}
  private query(user:string){return `SELECT p.*, (SELECT COUNT(*) FROM mobile_feed_likes l WHERE l.post_id=p.id) AS likes, EXISTS(SELECT 1 FROM mobile_feed_likes l WHERE l.post_id=p.id AND l.user_id=?) AS liked FROM mobile_feed_posts p`;}
  private map(row:Row,user:string):FeedPost {return {id:row.id,author:row.author,card:JSON.parse(row.card) as FeedCard,caption:row.caption,createdAt:row.created_at,likes:row.likes,liked:!!row.liked,mine:row.user_id===user};}
  get(id:string,user=''):FeedPost {
    const row=this.db.prepare(this.query(user)+' WHERE p.id=? AND p.deleted=0').get(user,id) as Row|undefined;
    if(!row)throw new MobileError(404,'FEED_NOT_FOUND','这条分享已不存在');return this.map(row,user);
  }
  list(user='',before=Number.MAX_SAFE_INTEGER){
    if(!Number.isSafeInteger(before)||before<1)throw new MobileError(400,'INVALID_CURSOR','请刷新分享列表');
    const rows=this.db.prepare(this.query(user)+' WHERE p.deleted=0 AND p.seq<? ORDER BY p.seq DESC LIMIT 21').all(user,before) as Row[];
    const page=rows.slice(0,20);return {items:page.map(row=>this.map(row,user)),nextBefore:rows.length>20?page[page.length-1]!.seq:0};
  }
  publish(user:string,raw:unknown):FeedPost {
    const draft=feedDraft(raw),payload=JSON.stringify({author:draft.author,card:draft.card,caption:draft.caption}),fingerprint=createHash('sha256').update(payload).digest('hex');
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const previous=this.db.prepare('SELECT id,fingerprint,deleted FROM mobile_feed_posts WHERE user_id=? AND request_id=?').get(user,draft.requestId) as {id:string;fingerprint:string;deleted:number}|undefined;
      if(previous){if(previous.fingerprint!==fingerprint)throw new MobileError(409,'IDEMPOTENCY_CONFLICT','分享内容已有变化，请重新确认');if(previous.deleted)throw new MobileError(409,'FEED_DELETED','该分享已删除，请重新创建');this.db.exec('COMMIT');return this.get(previous.id,user);}
      const recent=this.db.prepare('SELECT COUNT(*) AS count FROM mobile_feed_posts WHERE user_id=? AND created_at>?').get(user,this.now()-60000) as {count:number};
      if(recent.count>=20)throw new MobileError(429,'FEED_RATE_LIMIT','发布较频繁，请稍后再试');
      const id=randomUUID();this.db.prepare('INSERT INTO mobile_feed_posts(id,user_id,request_id,fingerprint,author,card,caption,created_at) VALUES(?,?,?,?,?,?,?,?)').run(id,user,draft.requestId,fingerprint,draft.author,JSON.stringify(draft.card),draft.caption,this.now());
      this.db.exec('COMMIT');return this.get(id,user);
    }catch(error){if(this.db.isTransaction)this.db.exec('ROLLBACK');throw error;}
  }
  like(user:string,id:string,liked:unknown):FeedPost {
    if(typeof liked!=='boolean')throw new MobileError(400,'INVALID_LIKE','点赞状态无效');
    this.db.exec('BEGIN IMMEDIATE');
    try{this.get(id,user);if(liked)this.db.prepare('INSERT OR IGNORE INTO mobile_feed_likes VALUES(?,?)').run(id,user);else this.db.prepare('DELETE FROM mobile_feed_likes WHERE post_id=? AND user_id=?').run(id,user);this.db.exec('COMMIT');return this.get(id,user);}catch(error){if(this.db.isTransaction)this.db.exec('ROLLBACK');throw error;}
  }
  remove(user:string,id:string){
    const post=this.get(id,user);if(!post.mine)throw new MobileError(403,'FEED_FORBIDDEN','只能删除自己的分享');
    this.db.prepare('UPDATE mobile_feed_posts SET deleted=1 WHERE id=? AND user_id=?').run(id,user);return {ok:true};
  }
}
