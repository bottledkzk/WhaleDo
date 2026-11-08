package com.course.whaledo;

import android.app.*;
import android.content.*;
import android.net.Uri;
import android.os.Build;
import org.json.*;

public final class ReminderReceiver extends BroadcastReceiver {
    private static final String ACTION="com.course.whaledo.REMIND";
    private static PendingIntent intent(Context context,int index,boolean create){
        Intent i=new Intent(context,ReminderReceiver.class).setAction(ACTION).setData(Uri.parse("whaledo://reminder/"+index)).putExtra("index",index);
        return PendingIntent.getBroadcast(context,index,i,(create?PendingIntent.FLAG_UPDATE_CURRENT:PendingIntent.FLAG_NO_CREATE)|PendingIntent.FLAG_IMMUTABLE);
    }
    static void cancel(Context context){AlarmManager manager=context.getSystemService(AlarmManager.class);for(int i=0;i<20;i++){PendingIntent pending=intent(context,i,false);if(pending!=null){manager.cancel(pending);pending.cancel();}}context.getSharedPreferences("reminder-native",0).edit().remove("plan").commit();}
    static JSONObject update(Context context,JSONObject plan) throws Exception {
        if(!new NativeStore(context).owner().equals(plan.getString("owner")))throw new IllegalStateException("账户已切换，请重试");
        JSONArray items=plan.optJSONArray("items");if(items==null||items.length()>20)throw new IllegalArgumentException("提醒数量无效");
        long now=System.currentTimeMillis();for(int i=0;i<items.length();i++){JSONObject item=items.getJSONObject(i);if(item.getString("title").length()>120||item.getString("kind").length()>120||item.getLong("at")<now)throw new IllegalArgumentException("提醒时间或内容无效");}
        cancel(context);if(!context.getSharedPreferences("reminder-native",0).edit().putString("plan",plan.toString()).commit())throw new IllegalStateException("提醒设置未保存");
        return schedule(context,plan);
    }
    private static JSONObject schedule(Context context,JSONObject plan) throws Exception {
        AlarmManager manager=context.getSystemService(AlarmManager.class);boolean exact=Build.VERSION.SDK_INT<31||manager.canScheduleExactAlarms();JSONArray items=plan.getJSONArray("items");int count=0;
        for(int i=0;i<items.length();i++){long at=items.getJSONObject(i).getLong("at");if(at<=System.currentTimeMillis())continue;PendingIntent pending=intent(context,i,true);if(exact)manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending);else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,pending);count++;}
        return new JSONObject().put("scheduled",count).put("exact",exact);
    }
    static void notify(Context context,String text,boolean silent,int id){
        NotificationManager manager=context.getSystemService(NotificationManager.class);String channel=silent?"whaledo-silent":"whaledo-reminders";
        NotificationChannel c=new NotificationChannel(channel,silent?"静音提醒":"事项提醒",NotificationManager.IMPORTANCE_DEFAULT);if(silent)c.setSound(null,null);manager.createNotificationChannel(c);
        PendingIntent open=PendingIntent.getActivity(context,0,new Intent(context,MainActivity.class),PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        Notification notification=new Notification.Builder(context,channel).setSmallIcon(R.drawable.ic_notification).setContentTitle("鲸办 WhaleDo").setContentText(text).setContentIntent(open).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build();
        try{manager.notify(id,notification);}catch(SecurityException ignored){}
    }
    @Override public void onReceive(Context context,Intent intent){try{
        String raw=context.getSharedPreferences("reminder-native",0).getString("plan","");if(raw.isEmpty())return;JSONObject plan=new JSONObject(raw);if(!new NativeStore(context).owner().equals(plan.getString("owner")))return;
        if(!ACTION.equals(intent.getAction())){schedule(context,plan);return;}
        int index=intent.getIntExtra("index",-1);JSONArray items=plan.getJSONArray("items");if(index<0||index>=items.length())return;JSONObject item=items.getJSONObject(index);
        if(Math.abs(System.currentTimeMillis()-item.getLong("at"))>3600000)return;notify(context,item.getString("kind")+" · "+item.getString("title"),plan.optBoolean("silent"),1000+index);
    }catch(Exception ignored){}}
}
