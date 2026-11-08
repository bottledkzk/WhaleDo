package com.course.whaledo;

import android.app.*;
import android.content.*;
import android.database.Cursor;
import android.graphics.*;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.Build;
import android.provider.*;
import android.util.Base64;
import androidx.core.content.FileProvider;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.*;
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

final class NativeMedia {
    private final MainActivity a;private final NativeSpeech speech;
    private MainActivity.Reply pending;private String pendingOwner,purpose;private JSONObject options;private Uri capture;private byte[] pendingSave;
    private static final Set<String> COMMANDS=Collections.unmodifiableSet(new HashSet<>(Arrays.asList("photo","camera","ocr","audioImport","speechStart","speechStop","calendarPreview","calendarAdd","shareImage","saveImage","shareText","shareIcs","removeAvatar")));
    NativeMedia(MainActivity a){this.a=a;this.speech=new NativeSpeech(a);}
    boolean handles(String command){return COMMANDS.contains(command);}
    private boolean sameOwner(String owner){try{return a.store.owner().equals(owner);}catch(Exception e){return false;}}
    void handle(String command,JSONObject p,MainActivity.Reply reply) throws Exception {
        switch(command){
            case "photo":case "camera":case "ocr":case "audioImport":pick(command,p,reply);return;
            case "speechStart":String voiceOwner=p.getString("owner");a.permission(android.Manifest.permission.RECORD_AUDIO,()->{if(sameOwner(voiceOwner))speech.start(voiceOwner,reply);else reply.fail("账户已切换，请重试");},()->reply.fail("需要麦克风权限才能语音输入"));return;
            case "speechStop":speech.stop(p.optBoolean("cancel"));reply.ok(true);return;
            case "calendarPreview":a.permission(android.Manifest.permission.READ_CALENDAR,()->calendar(p,reply),()->reply.fail("未授权读取系统日历"));return;
            case "calendarAdd":addCalendar(p);reply.ok(true);return;
            case "shareText":a.startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,p.getString("text")),"分享"));reply.ok(true);return;
            case "shareIcs":share("WhaleDo.ics","text/calendar",p.getString("text").getBytes(StandardCharsets.UTF_8));reply.ok(true);return;
            case "shareImage":share("WhaleDo-"+System.currentTimeMillis()+".png","image/png",png(p),p.optString("caption"));reply.ok(true);return;
            case "saveImage":save(p,reply);return;
            case "removeAvatar":String name=p.getString("name");if(name.matches("whaletodo-avatar-"+p.getString("owner")+"-[0-9]+\\.jpg"))new File(a.getFilesDir(),"avatars/"+name).delete();reply.ok(true);return;
            default:throw new IOException("当前操作不可用");
        }
    }
    private void pick(String command,JSONObject p,MainActivity.Reply reply) throws Exception {
        if(pending!=null){reply.fail("请先完成当前选择");return;}
        pending=reply;pendingOwner=p.getString("owner");purpose=command;options=p;
        Intent intent;
        if(command.equals("camera")){
            File directory=new File(a.getCacheDir(),"shared");directory.mkdirs();File output=new File(directory,"capture-"+UUID.randomUUID()+".jpg");capture=FileProvider.getUriForFile(a,a.getPackageName()+".files",output);
            intent=new Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT,capture).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            intent.setClipData(ClipData.newRawUri("照片",capture));
        }else intent=new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(command.equals("audioImport")?"audio/*":"image/*");
        try{a.startActivityForResult(intent,701);}catch(ActivityNotFoundException e){pending=null;throw new IOException(command.equals("camera")?"当前设备暂无可用相机，可从相册选择":"当前设备无法打开文件选择器");}
    }
    void result(int request,int result,Intent data){
        if(request!=701&&request!=702)return;
        MainActivity.Reply reply=pending;String owner=pendingOwner;String mode=purpose;JSONObject p=options;Uri camera=capture;byte[] saved=pendingSave;
        pending=null;capture=null;pendingSave=null;
        if(reply==null)return;if(!sameOwner(owner)){reply.fail("账户已切换，未使用所选内容");return;}
        if(result!=Activity.RESULT_OK){reply.ok(JSONObject.NULL);return;}
        Uri uri=data==null?null:data.getData();if(mode!=null&&mode.equals("camera"))uri=camera;
        if(uri==null){reply.fail("没有取得所选内容，请重试");return;}final Uri selected=uri;
        a.io.execute(()->{try{
            if(request==702){try(OutputStream out=a.getContentResolver().openOutputStream(selected,"w")){if(out==null)throw new IOException("图片保存失败");out.write(saved);}reply.ok(true);return;}
            if(mode.equals("audioImport")){speech.transcribe(read(selected,2*1024*1024),new MainActivity.Reply(){public void ok(Object value){if(sameOwner(owner))reply.ok(value);else reply.fail("账户已切换，未填入转写内容");}public void fail(String message,int status){reply.fail(message,status);}});return;}
            Bitmap bitmap=bitmap(selected,mode.equals("ocr")?2600:p.optBoolean("avatar")?512:1536);
            if(!sameOwner(owner)){bitmap.recycle();throw new IOException("账户已切换，未使用所选内容");}
            if(mode.equals("ocr")){
                TextRecognizer recognizer=TextRecognition.getClient(new ChineseTextRecognizerOptions.Builder().build());
                recognizer.process(InputImage.fromBitmap(bitmap,0)).addOnSuccessListener(value->{if(sameOwner(owner))reply.ok(value.getText().trim());else reply.fail("账户已切换，未填入识别内容");}).addOnFailureListener(error->reply.fail("图片识字未完成，请重试")).addOnCompleteListener(task->{recognizer.close();bitmap.recycle();});return;
            }
            ByteArrayOutputStream out=new ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.JPEG,85,out);bitmap.recycle();byte[] bytes=out.toByteArray();
            if(bytes.length>2*1024*1024)throw new IOException("图片过大，请选择较小的图片");
            String name="";if(p.optBoolean("avatar")){name="whaletodo-avatar-"+owner+"-"+System.currentTimeMillis()+".jpg";NativeStore.writeAtomic(new File(a.getFilesDir(),"avatars/"+name),bytes);}
            reply.ok(new JSONObject().put("name",name).put("dataUri","data:image/jpeg;base64,"+Base64.encodeToString(bytes,Base64.NO_WRAP)));
        }catch(Exception e){reply.fail(MainActivity.message(e));}finally{if(camera!=null)try{a.getContentResolver().delete(camera,null,null);}catch(Exception ignored){}}});
    }
    private byte[] read(Uri uri,int maximum) throws IOException {
        try(InputStream in=a.getContentResolver().openInputStream(uri)){if(in==null)throw new IOException("无法读取所选文件");ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[16384];int n;while((n=in.read(buffer))!=-1){if(out.size()+n>maximum)throw new IOException("所选文件过大");out.write(buffer,0,n);}return out.toByteArray();}
    }
    private Bitmap bitmap(Uri uri,int maximum) throws Exception {
        byte[] bytes=read(uri,20*1024*1024);BitmapFactory.Options bounds=new BitmapFactory.Options();bounds.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,bounds);
        if(bounds.outWidth<=0||bounds.outHeight<=0)throw new IOException("无法读取所选图片");BitmapFactory.Options sample=new BitmapFactory.Options();sample.inSampleSize=1;while(Math.max(bounds.outWidth,bounds.outHeight)/sample.inSampleSize>maximum*2)sample.inSampleSize*=2;
        Bitmap decoded=BitmapFactory.decodeByteArray(bytes,0,bytes.length,sample);if(decoded==null)throw new IOException("无法读取所选图片");
        int orientation=ExifInterface.ORIENTATION_NORMAL;try{orientation=new ExifInterface(new ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION,1);}catch(Exception ignored){}
        Matrix transform=new Matrix();if(orientation==6)transform.postRotate(90);else if(orientation==3)transform.postRotate(180);else if(orientation==8)transform.postRotate(270);else if(orientation==2)transform.postScale(-1,1);
        float ratio=Math.min(1f,(float)maximum/Math.max(decoded.getWidth(),decoded.getHeight()));transform.postScale(ratio,ratio);
        Bitmap value=Bitmap.createBitmap(decoded,0,0,decoded.getWidth(),decoded.getHeight(),transform,true);if(value!=decoded)decoded.recycle();return value;
    }
    private static byte[] png(JSONObject p) throws Exception {
        String data=p.getString("png");if(!data.startsWith("data:image/png;base64,")||data.length()>16*1024*1024)throw new IOException("分享图片无效");byte[] bytes=Base64.decode(data.substring(22),Base64.DEFAULT);
        if(bytes.length<8||bytes[0]!=(byte)137||bytes[1]!=80||bytes[2]!=78||bytes[3]!=71)throw new IOException("分享图片无效");return bytes;
    }
    private void share(String name,String mime,byte[] bytes) throws Exception {
        share(name,mime,bytes,"");
    }
    private void share(String name,String mime,byte[] bytes,String caption) throws Exception {
        if(bytes.length>12*1024*1024)throw new IOException("分享内容过大");File f=new File(a.getCacheDir(),"shared/"+name);NativeStore.writeAtomic(f,bytes);Uri uri=FileProvider.getUriForFile(a,a.getPackageName()+".files",f);
        Intent send=new Intent(Intent.ACTION_SEND).setType(mime).putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);if(!caption.isEmpty())send.putExtra(Intent.EXTRA_TEXT,caption.substring(0,Math.min(2000,caption.length())));send.setClipData(ClipData.newRawUri("鲸办 WhaleDo",uri));a.startActivity(Intent.createChooser(send,"分享"));
    }
    private void save(JSONObject p,MainActivity.Reply reply) throws Exception {
        byte[] bytes=png(p);
        if(Build.VERSION.SDK_INT<29){if(pending!=null)throw new IOException("请先完成当前选择");pending=reply;pendingOwner=p.getString("owner");purpose="save";pendingSave=bytes;a.startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/png").putExtra(Intent.EXTRA_TITLE,"WhaleDo-"+System.currentTimeMillis()+".png"),702);return;}
        a.io.execute(()->{Uri uri=null;try{
            ContentValues v=new ContentValues();v.put(MediaStore.Images.Media.DISPLAY_NAME,"WhaleDo-"+System.currentTimeMillis()+".png");v.put(MediaStore.Images.Media.MIME_TYPE,"image/png");v.put(MediaStore.Images.Media.RELATIVE_PATH,"Pictures/WhaleDo");v.put(MediaStore.Images.Media.IS_PENDING,1);
            uri=a.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,v);if(uri==null)throw new IOException("图片保存失败");try(OutputStream out=a.getContentResolver().openOutputStream(uri)){if(out==null)throw new IOException("图片保存失败");out.write(bytes);}ContentValues ready=new ContentValues();ready.put(MediaStore.Images.Media.IS_PENDING,0);a.getContentResolver().update(uri,ready,null,null);reply.ok(true);
        }catch(Exception e){if(uri!=null)a.getContentResolver().delete(uri,null,null);reply.fail("图片保存失败，请重试");}});
    }
    private void calendar(JSONObject p,MainActivity.Reply reply){a.io.execute(()->{try{
        if(a.checkSelfPermission(android.Manifest.permission.READ_CALENDAR)!=android.content.pm.PackageManager.PERMISSION_GRANTED)throw new IOException("未授权读取系统日历");
        String owner=p.getString("owner");long from=p.getLong("from"),to=p.getLong("to"),now=System.currentTimeMillis();if(from<now-2*86400000L||to<=from||to-from>32*86400000L)throw new IOException("请选择未来30天的日程");
        JSONArray events=new JSONArray();HashSet<String> ids=new HashSet<>();String[] projection={CalendarContract.Instances.EVENT_ID,CalendarContract.Instances.TITLE,CalendarContract.Instances.BEGIN,CalendarContract.Instances.END,CalendarContract.Instances.ALL_DAY,CalendarContract.Instances.EVENT_LOCATION};
        try(Cursor c=CalendarContract.Instances.query(a.getContentResolver(),projection,from,to)){while(c!=null&&c.moveToNext()){long start=c.getLong(2),end=c.getLong(3),id=c.getLong(0);String key=id+":"+start+":"+end;if(!ids.add(key))continue;if(events.length()>=1000)throw new IOException("日程较多，请先在系统日历整理后重试");events.put(new JSONObject().put("eventId",id).put("title",c.getString(1)==null?"未命名日程":c.getString(1)).put("start",start).put("end",end).put("allDay",c.getInt(4)!=0).put("location",c.getString(5)==null?"":c.getString(5)));}}
        if(!sameOwner(owner))throw new IOException("账户已切换，请重新读取");reply.ok(events);
    }catch(Exception e){reply.fail(MainActivity.message(e));}});}
    private void addCalendar(JSONObject p) throws Exception {
        long start=p.getLong("start"),end=p.getLong("end");if(start<0||end<=start)throw new IOException("请先填写日程时间");
        Intent intent=new Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI).putExtra(CalendarContract.Events.TITLE,p.getString("title")).putExtra(CalendarContract.Events.DESCRIPTION,p.optString("note")).putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME,start).putExtra(CalendarContract.EXTRA_EVENT_END_TIME,end).putExtra(CalendarContract.Events.ALL_DAY,p.optBoolean("allDay"));
        try{a.startActivity(intent);}catch(ActivityNotFoundException e){throw new IOException("当前设备暂无可用系统日历");}
    }
    void close(){speech.close();pending=null;}
    void background(){speech.background();}
}
