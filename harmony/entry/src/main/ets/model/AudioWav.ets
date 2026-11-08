/** PCM WAV import supported by the system recognizer: 16 kHz, mono, signed 16-bit. */
export function wavPcm(bytes:Uint8Array):Uint8Array {
  const bad=():never=>{throw new Error('请选择60秒以内、16kHz单声道16位的 WAV 音频');};
  if(bytes.length<44||bytes.length>2*1024*1024){return bad();}
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  const tag=(at:number):string=>String.fromCharCode(bytes[at],bytes[at+1],bytes[at+2],bytes[at+3]);
  if(tag(0)!=='RIFF'||tag(8)!=='WAVE'||view.getUint32(4,true)+8>bytes.length){return bad();}
  let format=false,start=0,length=0;
  for(let at=12;at+8<=bytes.length;){
    const size=view.getUint32(at+4,true),next=at+8+size;if(next>bytes.length){return bad();}
    if(tag(at)==='fmt '){if(size<16||view.getUint16(at+8,true)!==1||view.getUint16(at+10,true)!==1||view.getUint32(at+12,true)!==16000||view.getUint16(at+22,true)!==16){return bad();}format=true;}
    if(tag(at)==='data'){start=at+8;length=size;}
    at=next+(size%2);
  }
  if(!format||!start||!length||length%2||length>16000*2*60){return bad();}
  return bytes.slice(start,start+length);
}
