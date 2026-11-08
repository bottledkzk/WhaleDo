package com.course.whaledo;

import android.media.*;
import org.json.*;
import org.vosk.*;
import java.io.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

final class NativeSpeech {
    private final MainActivity activity;
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private volatile boolean running,cancelled,busy,microphoneMode;private volatile AudioRecord recorder;private Model model;private String activeOwner="";
    NativeSpeech(MainActivity activity){this.activity=activity;}
    private Model model() throws Exception {
        if(model!=null)return model;LibVosk.setLogLevel(LogLevel.WARNINGS);
        File folder=new File(activity.getFilesDir(),"speech-cn-0.22-3af8b0e7");File ready=new File(folder,".ready");
        if(!ready.exists()){copyAssets("speech-model",folder);NativeStore.writeAtomic(ready,"0.22".getBytes(StandardCharsets.UTF_8));}
        model=new Model(folder.getAbsolutePath());return model;
    }
    private void copyAssets(String source,File folder) throws IOException {
        String[] names=activity.getAssets().list(source);if(names==null||names.length==0)throw new IOException("语音资源未就绪，请重新安装完整应用包");
        if(!folder.isDirectory()&&!folder.mkdirs())throw new IOException("无法准备语音资源");
        for(String name:names){String next=source+"/"+name;String[] children=activity.getAssets().list(next);File target=new File(folder,name);
            if(children!=null&&children.length>0)copyAssets(next,target);
            else try(InputStream in=activity.getAssets().open(next);OutputStream out=new FileOutputStream(target)){byte[] buffer=new byte[16384];int count;while((count=in.read(buffer))!=-1)out.write(buffer,0,count);}
        }
    }
    private void event(String state,String text,String error){try{if(!activeOwner.equals(activity.store.owner()))return;activity.emit("speech",new JSONObject().put("owner",activeOwner).put("state",state).put("text",text).put("error",error));}catch(Exception ignored){}}
    private static String text(String raw,String field) throws JSONException {return new JSONObject(raw).optString(field).replaceAll("(?<=[\\p{IsHan}])\\s+(?=[\\p{IsHan}])","").trim();}
    synchronized void start(String owner,MainActivity.Reply reply){
        if(busy){reply.fail("正在转写，请先结束当前录音");return;}busy=true;running=true;cancelled=false;microphoneMode=true;activeOwner=owner;reply.ok(true);event("preparing","","");
        worker.execute(()->{
            AudioRecord local=null;StringBuilder transcript=new StringBuilder();
            try(Recognizer recognizer=new Recognizer(model(),16000)){
                if(cancelled||!running)return;
                if(activity.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)!=android.content.pm.PackageManager.PERMISSION_GRANTED)throw new IOException("未授权麦克风");
                int size=Math.max(4096,AudioRecord.getMinBufferSize(16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT));
                local=new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION,16000,AudioFormat.CHANNEL_IN_MONO,AudioFormat.ENCODING_PCM_16BIT,size);
                if(local.getState()!=AudioRecord.STATE_INITIALIZED)throw new IOException("麦克风暂时不可用，请稍后重试");
                recorder=local;local.startRecording();event("listening","","");byte[] buffer=new byte[3200];long started=System.currentTimeMillis(),lastVoice=started;String partial="";
                while(running&&!cancelled&&System.currentTimeMillis()-started<60000){int count=local.read(buffer,0,buffer.length);if(count<0)break;
                    if(recognizer.acceptWaveForm(buffer,count)){String result=text(recognizer.getResult(),"text");if(!result.isEmpty()){transcript.append(result);lastVoice=System.currentTimeMillis();}}
                    else{String value=text(recognizer.getPartialResult(),"partial");if(!value.equals(partial)){partial=value;if(!partial.isEmpty())lastVoice=System.currentTimeMillis();}event("partial",transcript+partial,"");}
                    if(transcript.length()>0&&System.currentTimeMillis()-lastVoice>1500)break;
                }
                if(!cancelled){transcript.append(text(recognizer.getFinalResult(),"text"));event("complete",transcript.toString(),transcript.length()==0?"没有识别到内容，可重试或手动输入":"");}
            }catch(Exception e){if(!cancelled)event("error","","语音识别未完成，请重试或手动输入");}
            finally{if(local!=null){try{local.stop();}catch(Exception ignored){}local.release();}recorder=null;running=false;busy=false;}
        });
    }
    void stop(boolean cancel){cancelled=cancel;running=false;AudioRecord local=recorder;if(local!=null)try{local.stop();}catch(Exception ignored){}if(cancel)event("cancelled","","");}
    synchronized void transcribe(byte[] wav,MainActivity.Reply reply){
        if(busy){reply.fail("正在转写，请先结束当前录音");return;}busy=true;running=true;cancelled=false;microphoneMode=false;
        worker.execute(()->{try(Recognizer recognizer=new Recognizer(model(),16000)){
            byte[] pcm=pcm(wav);StringBuilder result=new StringBuilder();for(int at=0;at<pcm.length&&!cancelled;at+=3200){byte[] frame=Arrays.copyOfRange(pcm,at,Math.min(at+3200,pcm.length));if(recognizer.acceptWaveForm(frame,frame.length))result.append(text(recognizer.getResult(),"text"));}
            if(cancelled)throw new IOException("已取消转写");result.append(text(recognizer.getFinalResult(),"text"));if(result.length()==0)throw new IOException("没有识别到内容，可重试或手动输入");reply.ok(result.toString());
        }catch(Exception e){reply.fail(MainActivity.message(e));}finally{running=false;busy=false;}});
    }
    static byte[] pcm(byte[] wav) throws IOException {
        if(wav.length<44||wav.length>2*1024*1024||!new String(wav,0,4,StandardCharsets.US_ASCII).equals("RIFF")||!new String(wav,8,4,StandardCharsets.US_ASCII).equals("WAVE"))throw new IOException("请选择16kHz单声道16bit WAV音频");
        ByteBuffer b=ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN);boolean valid=false;byte[] pcm=null;
        for(int at=12;at+8<=wav.length;){int size=b.getInt(at+4);if(size<0||at+8L+size>wav.length)throw new IOException("音频文件不完整");String type=new String(wav,at,4,StandardCharsets.US_ASCII);
            if(type.equals("fmt ")){if(size<16)throw new IOException("音频格式无效");valid=b.getShort(at+8)==1&&b.getShort(at+10)==1&&b.getInt(at+12)==16000&&b.getShort(at+22)==16;}
            if(type.equals("data"))pcm=Arrays.copyOfRange(wav,at+8,at+8+size);at+=8+size+(size&1);
        }
        if(!valid||pcm==null||pcm.length==0||pcm.length%2!=0||pcm.length>1920000)throw new IOException("请选择60秒内16kHz单声道16bit WAV音频");return pcm;
    }
    void close(){stop(true);worker.execute(()->{if(model!=null){model.close();model=null;}});worker.shutdown();}
    void background(){if(busy&&microphoneMode)stop(true);}
}
