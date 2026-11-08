export interface HistoryMessage {role:string;content:string;images?:string[];}
function utf8Size(text:string):number {let n=0;for(let i=0;i<text.length;i++){const code=text.charCodeAt(i);if(code<128){n++;}else if(code<2048){n+=2;}else if(code>=0xD800&&code<=0xDBFF&&i+1<text.length&&text.charCodeAt(i+1)>=0xDC00&&text.charCodeAt(i+1)<=0xDFFF){n+=4;i++;}else{n+=3;}}return n;}
/** Preserve the visible library; bound only outbound context, prioritizing recent turns. */
export function boundedHistory<T extends HistoryMessage>(messages:T[],reserved:string):T[] {
  let budget=7*1024*1024-utf8Size(reserved)-4096;
  if(budget<0){throw new Error('本次内容较大，请减少附带记录或图片后重试');}
  const selected:T[]=[];
  for(let i=messages.length-1;i>=0&&selected.length<80;i--){
    const row=JSON.parse(JSON.stringify(messages[i])) as T;
    if(row.content.length>1000000){row.content=row.content.slice(0,999900).replace(/[\uD800-\uDBFF]$/,'')+'\n[较长的历史回复已截短]';}
    // Old pictures need not be resent every turn; the latest two turns retain them if they fit.
    if(i<messages.length-2){row.images=undefined;}
    let cost=utf8Size(JSON.stringify(row));
    if(cost>budget&&row.images?.length){row.images=undefined;cost=utf8Size(JSON.stringify(row));}
    if(cost>budget){break;}budget-=cost;selected.unshift(row);
  }
  while(selected.length&&selected[0].role!=='user'){selected.shift();}
  return selected;
}
