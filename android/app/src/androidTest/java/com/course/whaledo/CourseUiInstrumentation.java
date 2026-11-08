package com.course.whaledo;

import android.app.*;
import android.content.*;
import android.content.pm.ActivityInfo;
import android.graphics.*;
import android.os.*;
import android.view.*;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.inputmethod.InputMethodManager;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

/** Device regression checks run only against the separate verification application. */
public final class CourseUiInstrumentation extends Instrumentation {
    private MainActivity activity;
    private Bundle arguments;
    private final JSONArray checks=new JSONArray();
    private File evidence;
    @Override public void onCreate(Bundle args){super.onCreate(args);arguments=args==null?new Bundle():args;start();}
    @Override public void onStart(){
        Bundle result=new Bundle();int code=Activity.RESULT_OK;
        try{
            String target=getTargetContext().getPackageName();
            require(target.equals("com.course.whaledo.verification"),"Verification package required");
            evidence=new File(getTargetContext().getExternalFilesDir(null),"evidence");
            if(!evidence.isDirectory()&&!evidence.mkdirs())throw new IOException("Cannot create test evidence");
            Intent launch=new Intent().setClassName(target,MainActivity.class.getName()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            ActivityMonitor monitor=addMonitor(MainActivity.class.getName(),null,false);
            runOnMainSync(()->getTargetContext().startActivity(launch));
            activity=(MainActivity)monitor.waitForActivityWithTimeout(15000);removeMonitor(monitor);
            require(activity!=null,"Verification activity did not start");
            await("S.ready===true",60000);
            if(arguments.getString("suite","ui").equals("speech"))speech();else ui();
            result.putString("checks",checks.toString());
        }catch(Throwable error){code=Activity.RESULT_CANCELED;result.putString("failure",error.toString());}
        finally{
            if(activity!=null)runOnMainSync(()->activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED));
            try{if(evidence!=null)try(FileOutputStream out=new FileOutputStream(new File(evidence,"result.json"))){out.write(new JSONObject().put("passed",code==Activity.RESULT_OK).put("checks",checks).put("failure",result.getString("failure","")).toString(2).getBytes(StandardCharsets.UTF_8));}}catch(Exception ignored){}
            finish(code,result);
        }
    }
    private Object js(String expression) throws Exception {
        CountDownLatch done=new CountDownLatch(1);AtomicReference<String> value=new AtomicReference<>();
        runOnMainSync(()->activity.web.evaluateJavascript("(()=>{"+expression+"})()",raw->{value.set(raw);done.countDown();}));
        require(done.await(15,TimeUnit.SECONDS),"WebView evaluation timeout");return new JSONTokener(value.get()).nextValue();
    }
    private void await(String condition,long millis) throws Exception {
        long until=SystemClock.elapsedRealtime()+millis;
        while(SystemClock.elapsedRealtime()<until){if(Boolean.TRUE.equals(js("return !!("+condition+");")))return;Thread.sleep(100);}
        throw new AssertionError("Timed out: "+condition);
    }
    private static void require(boolean value,String message){if(!value)throw new AssertionError(message);}
    private void check(String name,Object detail) throws JSONException {checks.put(new JSONObject().put("check",name).put("passed",true).put("details",detail));Bundle progress=new Bundle();progress.putString("check",name);sendStatus(1,progress);}
    private void capture(String name) throws Exception {
        await("Array.from(document.images).every(image=>image.complete)",20000);Thread.sleep(400);
        Bitmap bitmap=getUiAutomation().takeScreenshot();require(bitmap!=null,"Screenshot unavailable");
        try(FileOutputStream out=new FileOutputStream(new File(evidence,name+".png"))){bitmap.compress(Bitmap.CompressFormat.PNG,100,out);}finally{bitmap.recycle();}
    }
    private void click(String id) throws Exception {js("document.getElementById("+JSONObject.quote(id)+").click();return true;");Thread.sleep(200);}
    private JSONObject rect(String selector) throws Exception {return (JSONObject)js("const r=document.querySelector("+JSONObject.quote(selector)+").getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,bottom:r.bottom};");}
    private void profileRows(String label) throws Exception {
        JSONArray rows=(JSONArray)js("return Array.from(document.querySelectorAll('.profile-row')).map(row=>{const r=row.getBoundingClientRect();return {title:row.querySelector('.grow').textContent,height:r.height,width:r.width,items:Array.from(row.children).map(n=>{const q=n.getBoundingClientRect();return {text:n.textContent,centerDelta:Math.abs(q.y+q.height/2-r.y-r.height/2),inside:q.x>=r.x&&q.right<=r.right}})}});");
        require(rows.length()>0,"No profile rows");
        for(int i=0;i<rows.length();i++){JSONObject row=rows.getJSONObject(i);require(row.getDouble("height")>=58,"Small profile row");JSONArray items=row.getJSONArray("items");for(int j=0;j<items.length();j++){JSONObject item=items.getJSONObject(j);require(item.getDouble("centerDelta")<1.1,"Off-center text: "+item.getString("text"));require(item.getBoolean("inside"),"Overflow: "+item.getString("text"));}}
        check(label,rows);
    }
    private void ui() throws Exception {
        require(Boolean.TRUE.equals(js("return document.querySelectorAll('.navigation>button').length===5&&document.querySelector('.brand').textContent==='鲸办 WhaleDo'&&document.querySelectorAll('.hero .stats b').length===3;")),"Home content missing");
        check("home-brand-and-five-tabs",true);capture("home");
        click("nav-4");profileRows("profile-text-centered");capture("profile");
        click("profile-row-设置");profileRows("settings-text-centered");capture("settings");
        click("profile-row-行动时间");
        js("document.querySelector('.work-range button').click();return true;");Thread.sleep(400);
        AccessibilityNodeInfo root=getUiAutomation().getRootInActiveWindow();require(root!=null,"Time dialog missing");
        Rect bounds=new Rect();root.getBoundsInScreen(bounds);
        float density=activity.getResources().getDisplayMetrics().density;
        int screenWidth=activity.getResources().getDisplayMetrics().widthPixels,screenHeight=activity.getResources().getDisplayMetrics().heightPixels;
        require(bounds.width()>=280*density,"Time dialog too small");require(Math.abs(bounds.exactCenterX()-screenWidth/2f)<24*density,"Time dialog not horizontally centered");require(Math.abs(bounds.exactCenterY()-screenHeight/2f)<100*density,"Time dialog not vertically centered");
        require(!root.findAccessibilityNodeInfosByText("开始时间").isEmpty(),"Time title missing");
        check("time-wheel-size-and-center",new JSONObject().put("bounds",bounds.toShortString()).put("density",density));capture("time-wheel");
        sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);Thread.sleep(100);
        js("S.panel='';S.parents=[];S.tab=3;render(true);return true;");
        require(Boolean.TRUE.equals(js("return !document.getElementById('assistant-thread').textContent.includes('null')&&Array.from(document.querySelectorAll('#assistant-tools>button')).map(n=>n.textContent).join('|')==='添加图片|语音输入|音频转写|发送'&&!document.getElementById('capture-ocr');")),"Assistant content regression");
        JSONObject before=rect("#assistant-composer");
        js("window.__checkedInput=document.getElementById('assistant-input');conversation().messages=Array.from({length:50},(_,i)=>({role:i%2?'assistant':'user',content:'Controlled layout verification '+i+'\\n'+('Readable text. '.repeat(12))}));refreshAssistant();return true;");Thread.sleep(300);
        JSONObject after=rect("#assistant-composer");
        require(Math.abs(before.getDouble("y")-after.getDouble("y"))<1,"Composer moved with history");
        require(Boolean.TRUE.equals(js("return __checkedInput===document.getElementById('assistant-input')&&document.getElementById('assistant-thread').scrollHeight>document.getElementById('assistant-thread').clientHeight;")),"Input rebuilt or chat did not scroll");
        toolbar();check("assistant-null-absent-and-sticky-history",after);capture("assistant-history");
        JSONObject input=rect("#assistant-input");int[] location=new int[2];runOnMainSync(()->activity.web.getLocationOnScreen(location));
        long down=SystemClock.uptimeMillis();float x=location[0]+(float)(input.getDouble("x")+input.getDouble("width")/2)*density,y=location[1]+(float)(input.getDouble("y")+input.getDouble("height")/2)*density;
        MotionEvent press=MotionEvent.obtain(down,down,MotionEvent.ACTION_DOWN,x,y,0),release=MotionEvent.obtain(down,down+80,MotionEvent.ACTION_UP,x,y,0);sendPointerSync(press);sendPointerSync(release);press.recycle();release.recycle();
        await("document.body.classList.contains('keyboard')",10000);sendStringSync("WhaleDo fixed input");
        await("document.getElementById('assistant-input').value.includes('WhaleDo fixed input')",5000);toolbar();capture("assistant-keyboard");
        check("assistant-keyboard-input-and-four-controls",rect("#assistant-composer"));sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);Thread.sleep(300);
        runOnMainSync(()->activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE));await("innerWidth>innerHeight",15000);toolbar();capture("assistant-landscape");
        check("assistant-landscape-controls",rect("#assistant-composer"));
        runOnMainSync(()->activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT));await("innerHeight>innerWidth",15000);
    }
    private void toolbar() throws Exception {
        require(Boolean.TRUE.equals(js("const buttons=Array.from(document.querySelectorAll('#assistant-tools>button')).map(n=>n.getBoundingClientRect());return buttons.length===4&&buttons.every(r=>r.width>=50&&r.height>=39&&Math.abs(r.y-buttons[0].y)<1&&r.x>=0&&r.right<=innerWidth&&r.bottom<=innerHeight);")),"Toolbar clipped or uneven");
    }
    private void speech() throws Exception {
        byte[] sample;try(InputStream in=getContext().getAssets().open("asr_example_zh.wav")){ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[8192];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);sample=out.toByteArray();}
        NativeSpeech speech=new NativeSpeech(activity);CountDownLatch done=new CountDownLatch(1);AtomicReference<Object> text=new AtomicReference<>();AtomicReference<String> error=new AtomicReference<>();long start=SystemClock.elapsedRealtime();
        speech.transcribe(sample,new MainActivity.Reply(){public void ok(Object value){text.set(value);done.countDown();}public void fail(String message,int status){error.set(message);done.countDown();}});
        require(done.await(90,TimeUnit.SECONDS),"Speech timeout");speech.close();require(error.get()==null,"Speech failed: "+error.get());require(text.get()!=null&&text.get().toString().contains("欢迎")&&text.get().toString().contains("语音"),"Unexpected speech transcript: "+text.get());
        check("official-sample-production-speech-adapter",new JSONObject().put("text",text.get()).put("elapsedMs",SystemClock.elapsedRealtime()-start));
    }
}
