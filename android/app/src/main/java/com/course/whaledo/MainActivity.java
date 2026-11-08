package com.course.whaledo;

import android.app.*;
import android.content.*;
import android.content.res.Configuration;
import android.graphics.Color;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.webkit.*;
import android.widget.*;
import androidx.webkit.*;
import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;
import org.json.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public final class MainActivity extends ComponentActivity {
    static final String ORIGIN="https://appassets.androidplatform.net";
    final ExecutorService io=Executors.newFixedThreadPool(3);
    NativeStore store;CourseApi api;NativeMedia media;WebView web;
    private boolean darkAppearance;
    private int appearanceInk=Color.rgb(38,52,61),appearanceAccent=Color.rgb(63,101,162);
    private Runnable granted,denied;
    interface Reply {void ok(Object value);void fail(String message,int status);default void fail(String message){fail(message,0);}}
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);store=new NativeStore(this);api=new CourseApi(store);media=new NativeMedia(this);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE|View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN|View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        FrameLayout root=new FrameLayout(this);root.setBackgroundColor(Color.rgb(245,247,252));web=new WebView(this);root.addView(web,new FrameLayout.LayoutParams(-1,-1));setContentView(root);
        root.setOnApplyWindowInsetsListener((v,insets)->{
            int top,bottom,left,right;boolean keyboard=false;
            if(Build.VERSION.SDK_INT>=30){android.graphics.Insets bars=insets.getInsets(WindowInsets.Type.systemBars()|WindowInsets.Type.displayCutout());android.graphics.Insets ime=insets.getInsets(WindowInsets.Type.ime());top=bars.top;bottom=Math.max(bars.bottom,ime.bottom);left=bars.left;right=bars.right;keyboard=insets.isVisible(WindowInsets.Type.ime());}
            else{top=insets.getSystemWindowInsetTop();bottom=insets.getSystemWindowInsetBottom();left=insets.getSystemWindowInsetLeft();right=insets.getSystemWindowInsetRight();keyboard=bottom>getResources().getDisplayMetrics().density*160;}
            v.setPadding(left,top,right,bottom);emit("keyboard",object("visible",keyboard));return insets;
        });
        WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setDomStorageEnabled(false);s.setGeolocationEnabled(false);s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);s.setJavaScriptCanOpenWindowsAutomatically(false);s.setSupportMultipleWindows(false);s.setSafeBrowsingEnabled(true);s.setCacheMode(WebSettings.LOAD_NO_CACHE);s.setDefaultTextEncodingName("UTF-8");
        CookieManager.getInstance().setAcceptCookie(false);
        WebView.setWebContentsDebuggingEnabled((getApplicationInfo().flags&android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE)!=0);
        WebViewAssetLoader assets=new WebViewAssetLoader.Builder().addPathHandler("/assets/",new WebViewAssetLoader.AssetsPathHandler(this)).build();
        web.setWebViewClient(new WebViewClient(){
            @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest request){
                Uri uri=request.getUrl();
                if(!"https".equals(uri.getScheme())||!"appassets.androidplatform.net".equals(uri.getHost()))return blocked();
                if(uri.getPath()!=null&&uri.getPath().startsWith("/avatar/")){
                    String name=uri.getLastPathSegment();
                    try{String owner=store.owner();if(name!=null&&name.matches("whaletodo-avatar-"+owner+"-[0-9]+\\.jpg")){File f=new File(getFilesDir(),"avatars/"+name);return new WebResourceResponse("image/jpeg",null,new FileInputStream(f));}}catch(Exception ignored){}
                    return blocked();
                }
                WebResourceResponse response=assets.shouldInterceptRequest(uri);return response==null?blocked():response;
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest request){
                Uri u=request.getUrl();if("https".equals(u.getScheme())&&"appassets.androidplatform.net".equals(u.getHost()))return false;
                if(request.isForMainFrame()&&request.hasGesture()&&"https".equals(u.getScheme()))try{startActivity(new Intent(Intent.ACTION_VIEW,u));}catch(Exception ignored){}
                return true;
            }
            @Override public void onReceivedSslError(WebView v,android.webkit.SslErrorHandler handler,android.net.http.SslError error){handler.cancel();}
        });
        if(!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)){TextView text=new TextView(this);text.setText("请更新 Android System WebView 后打开鲸办");text.setGravity(Gravity.CENTER);setContentView(text);return;}
        WebViewCompat.addWebMessageListener(web,"WhaleNative",Collections.singleton(ORIGIN),(v,message,sourceOrigin,isMainFrame,proxy)->{
            if(!isMainFrame||!ORIGIN.equals(sourceOrigin.toString()))return;
            try{
                String raw=message.getData();if(raw==null||raw.length()>18*1024*1024)throw new IOException("内容过大");
                JSONObject request=new JSONObject(raw);String id=request.getString("id");if(!id.matches("[A-Za-z0-9_-]{1,100}"))throw new IOException("请求无效");
                Reply reply=new Reply(){
                    void send(Object result,String error,int status){runOnUiThread(()->{try{proxy.postMessage(new JSONObject().put("id",id).put("ok",error==null).put("data",result==null?JSONObject.NULL:result).put("error",error==null?JSONObject.NULL:error).put("status",status).toString());}catch(Exception ignored){}});}
                    public void ok(Object result){send(result,null,0);}public void fail(String error,int status){send(null,error,status);}
                };
                dispatch(request.getString("command"),request.optJSONObject("params")==null?new JSONObject():request.getJSONObject("params"),reply);
            }catch(Exception ignored){}
        });
        web.loadUrl(ORIGIN+"/assets/index.html");
        getOnBackPressedDispatcher().addCallback(this,new OnBackPressedCallback(true){@Override public void handleOnBackPressed(){emit("back",new JSONObject());}});
    }
    static WebResourceResponse blocked(){return new WebResourceResponse("text/plain","UTF-8",403,"Forbidden",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
    static JSONObject object(String key,Object value){try{return new JSONObject().put(key,value);}catch(JSONException e){throw new IllegalStateException(e);}}
    void emit(String type,JSONObject payload){if(web==null)return;runOnUiThread(()->web.evaluateJavascript("window.__nativeEvent&&window.__nativeEvent("+JSONObject.quote(type)+","+payload+")",null));}
    private void owner(JSONObject p) throws Exception {if(!store.owner().equals(p.getString("owner")))throw new IOException("账户已切换，请重试");}
    private void dispatch(String command,JSONObject p,Reply reply){
        try{
            if(command.equals("date")){date(p,reply);return;}
            if(command.equals("time")){time(p,reply);return;}
            if(command.equals("appearance")){appearance(p);reply.ok(true);return;}
            if(command.equals("closeApp")){moveTaskToBack(true);reply.ok(true);return;}
            if(media.handles(command)){owner(p);media.handle(command,p,reply);return;}
            if(command.equals("reminderPermission")){if(Build.VERSION.SDK_INT<33)reply.ok(true);else permission(android.Manifest.permission.POST_NOTIFICATIONS,()->reply.ok(true),()->reply.ok(false));return;}
            if(command.equals("exactAlarmSettings")){if(Build.VERSION.SDK_INT>=31)startActivity(new Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:"+getPackageName())));reply.ok(true);return;}
            io.execute(()->{try{
                switch(command){
                    case "bootstrap":reply.ok(new JSONObject().put("user",store.identity()).put("owner",store.owner()).put("systemZone",TimeZone.getDefault().getID()).put("systemDark",(getResources().getConfiguration().uiMode&Configuration.UI_MODE_NIGHT_MASK)==Configuration.UI_MODE_NIGHT_YES).put("version","0.4.0").put("platform","android"));break;
                    case "read":owner(p);reply.ok(store.read(p.getString("owner"),p.getString("name")));break;
                    case "write":owner(p);store.write(p.getString("owner"),p.getString("name"),p.get("value"));reply.ok(true);break;
                    case "login":reply.ok(api.login(p));break;
                    case "logout":ReminderReceiver.cancel(this);reply.ok(api.logout());break;
                    case "api":owner(p);reply.ok(api.request(p));break;
                    case "reminders":owner(p);reply.ok(ReminderReceiver.update(this,p));break;
                    case "notificationTest":owner(p);ReminderReceiver.notify(this,"今天，慢慢完成",false,777);reply.ok(true);break;
                    default:throw new IOException("当前操作不可用");
                }
            }catch(Exception e){reply.fail(message(e),e instanceof CourseApi.ApiError?((CourseApi.ApiError)e).status:0);}});
        }catch(Exception e){reply.fail(message(e));}
    }
    static String message(Exception e){String m=e.getMessage();if(e instanceof java.net.SocketTimeoutException)return "连接超时，可稍后继续同一请求";if(e instanceof java.net.UnknownHostException)return "无法连接服务，请检查网络";return m==null||m.length()>300?"操作未完成，请重试":m;}
    private void date(JSONObject p,Reply reply) throws Exception {
        String[] parts=p.optString("day",new java.text.SimpleDateFormat("yyyy-MM-dd",Locale.ROOT).format(new Date())).split("-");int year=Integer.parseInt(parts[0]),month=Integer.parseInt(parts[1])-1,day=Integer.parseInt(parts[2]);
        DatePickerDialog dialog=new DatePickerDialog(this,(v,y,m,d)->reply.ok(String.format(Locale.ROOT,"%04d-%02d-%02d",y,m+1,d)),year,month,day);dialog.getDatePicker().setCalendarViewShown(true);dialog.getDatePicker().setSpinnersShown(false);dialog.setOnCancelListener(v->reply.ok(JSONObject.NULL));dialog.show();
    }
    private void time(JSONObject p,Reply reply) throws Exception {
        boolean midnight=p.optBoolean("allowMidnight");int maximum=midnight?1440:1439,minimum=Math.max(0,Math.min(maximum,p.optInt("minimum",0))),value=Math.max(minimum,Math.min(maximum,p.optInt("minute",540)));
        ContextThemeWrapper themed=new ContextThemeWrapper(this,darkAppearance?android.R.style.Theme_Material_Dialog_Alert:android.R.style.Theme_Material_Light_Dialog_Alert);
        LinearLayout body=new LinearLayout(themed);body.setOrientation(LinearLayout.VERTICAL);body.setPadding(dp(24),dp(20),dp(24),dp(8));body.setGravity(Gravity.CENTER);
        TextView title=new TextView(themed);title.setText(p.optString("title","选择时间"));title.setTextSize(20);title.setTextColor(appearanceInk);title.setGravity(Gravity.CENTER);body.addView(title,new LinearLayout.LayoutParams(-1,dp(40)));
        LinearLayout wheels=new LinearLayout(themed);wheels.setGravity(Gravity.CENTER);wheels.setOrientation(LinearLayout.HORIZONTAL);
        NumberPicker hour=new NumberPicker(themed),minute=new NumberPicker(themed);hour.setContentDescription("小时");minute.setContentDescription("分钟");
        hour.setMinValue(minimum/60);hour.setMaxValue(midnight?24:23);hour.setDisplayedValues(clockValues(hour.getMinValue(),hour.getMaxValue()));hour.setValue(value/60);
        for(NumberPicker picker:new NumberPicker[]{hour,minute}){picker.setWrapSelectorWheel(false);picker.setDescendantFocusability(NumberPicker.FOCUS_BLOCK_DESCENDANTS);if(Build.VERSION.SDK_INT>=29){picker.setTextColor(appearanceInk);picker.setTextSize(22*getResources().getDisplayMetrics().scaledDensity);picker.setSelectionDividerHeight(dp(2));}}
        Runnable setMinutes=()->{int low=hour.getValue()==minimum/60?minimum%60:0,high=hour.getValue()==24?0:59,prior=minute.getValue();minute.setDisplayedValues(null);minute.setMinValue(low);minute.setMaxValue(high);minute.setDisplayedValues(clockValues(low,high));minute.setValue(Math.max(low,Math.min(high,prior)));minute.setWrapSelectorWheel(false);};
        setMinutes.run();minute.setValue(value%60);hour.setOnValueChangedListener((picker,old,next)->setMinutes.run());
        wheels.addView(hour,new LinearLayout.LayoutParams(dp(90),dp(210)));TextView colon=new TextView(themed);colon.setText(":");colon.setTextSize(24);colon.setTextColor(appearanceInk);colon.setGravity(Gravity.CENTER);wheels.addView(colon,new LinearLayout.LayoutParams(dp(28),dp(210)));wheels.addView(minute,new LinearLayout.LayoutParams(dp(90),dp(210)));body.addView(wheels,new LinearLayout.LayoutParams(-1,dp(230)));
        AlertDialog dialog=new AlertDialog.Builder(themed).setView(body).setNegativeButton("取消",(d,w)->reply.ok(JSONObject.NULL)).setPositiveButton("确定",(d,w)->reply.ok(hour.getValue()*60+minute.getValue())).create();dialog.setOnCancelListener(d->reply.ok(JSONObject.NULL));dialog.show();
        if(dialog.getWindow()!=null){dialog.getWindow().setGravity(Gravity.CENTER);dialog.getWindow().setLayout(Math.min(getResources().getDisplayMetrics().widthPixels-dp(48),dp(400)),WindowManager.LayoutParams.WRAP_CONTENT);}dialog.getButton(DialogInterface.BUTTON_POSITIVE).setTextColor(appearanceAccent);dialog.getButton(DialogInterface.BUTTON_NEGATIVE).setTextColor(appearanceAccent);
    }
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private static String[] clockValues(int first,int last){String[] values=new String[last-first+1];for(int i=first;i<=last;i++)values[i-first]=String.format(Locale.ROOT,"%02d",i);return values;}
    void permission(String name,Runnable yes,Runnable no){
        if(name.equals(android.Manifest.permission.POST_NOTIFICATIONS)&&Build.VERSION.SDK_INT<33){yes.run();return;}
        if(checkSelfPermission(name)==android.content.pm.PackageManager.PERMISSION_GRANTED){yes.run();return;}
        if(granted!=null){no.run();return;}granted=yes;denied=no;requestPermissions(new String[]{name},901);
    }
    @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] results){super.onRequestPermissionsResult(code,permissions,results);if(code==901){Runnable action=results.length>0&&results[0]==android.content.pm.PackageManager.PERMISSION_GRANTED?granted:denied;granted=null;denied=null;if(action!=null)action.run();}}
    private void appearance(JSONObject p){
        boolean dark=p.optBoolean("dark");darkAppearance=dark;int flags=getWindow().getDecorView().getSystemUiVisibility();int light=View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR|View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;getWindow().getDecorView().setSystemUiVisibility(dark?flags&~light:flags|light);
        if(Build.VERSION.SDK_INT>=29)getWindow().setNavigationBarContrastEnforced(false);
        try{appearanceInk=Color.parseColor(p.optString("ink",dark?"#F0F3F5":"#26343D"));appearanceAccent=Color.parseColor(p.optString("accent","#3F65A2"));((View)web.getParent()).setBackgroundColor(Color.parseColor(p.optString("paper","#F5F7FC")));}catch(Exception ignored){}
    }
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);media.result(request,result,data);}
    @Override public void onConfigurationChanged(Configuration c){super.onConfigurationChanged(c);emit("configuration",new JSONObject());}
    @Override protected void onStop(){media.background();super.onStop();}
    @Override protected void onDestroy(){media.close();io.shutdownNow();if(web!=null){web.stopLoading();web.destroy();web=null;}super.onDestroy();}
}
