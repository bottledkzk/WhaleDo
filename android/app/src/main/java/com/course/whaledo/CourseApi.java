package com.course.whaledo;

import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

final class CourseApi {
    private static final String BASE="https://mobile-api.whaletodo.top:8443/api/v1";
    private final NativeStore store;
    private final Object refreshLock=new Object();
    private volatile long generation;
    CourseApi(NativeStore store){this.store=store;}
    static final class ApiError extends IOException {final int status;ApiError(int status,String message){super(message);this.status=status;}}
    private JSONObject raw(String path,String method,Object body,String token) throws Exception {
        HttpURLConnection c=(HttpURLConnection)new URL(BASE+path).openConnection();c.setInstanceFollowRedirects(false);c.setConnectTimeout(20000);c.setReadTimeout(45000);c.setRequestMethod(method);
        c.setRequestProperty("User-Agent","WhaleDo-Android/0.4.0");c.setRequestProperty("Accept","application/json");c.setRequestProperty("Cache-Control","no-store");
        if(!token.isEmpty())c.setRequestProperty("Authorization","Bearer "+token);
        try{
            if(!method.equals("GET")){
                byte[] bytes=(body==null?"{}":body.toString()).getBytes(StandardCharsets.UTF_8);if(bytes.length>8*1024*1024)throw new IOException("内容过大，请减少图片或记录");
                c.setDoOutput(true);c.setRequestProperty("Content-Type","application/json");c.setFixedLengthStreamingMode(bytes.length);try(OutputStream out=c.getOutputStream()){out.write(bytes);}
            }
            int status=c.getResponseCode();InputStream input=status>=400?c.getErrorStream():c.getInputStream();if(input==null)throw new ApiError(status,"服务暂时不可用，请稍后重试");
            ByteArrayOutputStream output=new ByteArrayOutputStream();try(input){byte[] buffer=new byte[16384];int n;while((n=input.read(buffer))!=-1){if(output.size()+n>8*1024*1024)throw new IOException("服务返回内容过大");output.write(buffer,0,n);}}
            JSONObject envelope;try{envelope=new JSONObject(output.toString(StandardCharsets.UTF_8.name()));}catch(Exception ignored){throw new ApiError(status,"服务暂时不可用，请稍后重试");}
            if(status<200||status>=300){JSONObject error=envelope.optJSONObject("error");throw new ApiError(status,error==null?"请求未完成，请重试":error.optString("message","请求未完成，请重试"));}
            JSONObject data=envelope.optJSONObject("data");if(data==null)throw new IOException("服务返回格式无效");return data;
        }finally{c.disconnect();}
    }
    JSONObject login(JSONObject p) throws Exception {
        long epoch=generation;
        JSONObject body=new JSONObject().put("username",p.getString("username").trim()).put("password",p.getString("password"));
        boolean email=p.optBoolean("emailRegistration");String path=p.optBoolean("register")?"/auth/register":"/auth/login";
        if(email){path="/auth/register/email";body.put("email",p.getString("email").trim()).put("ticket",p.getString("ticket"));}
        JSONObject s=raw(path,"POST",body,"");s.getJSONObject("user").getString("id");
        synchronized(refreshLock){if(epoch!=generation)throw new IOException("账户操作已变化，请重试");store.saveSession(s);generation++;}
        return store.identity();
    }
    JSONObject logout() throws Exception {
        JSONObject s; synchronized(refreshLock){s=store.session();generation++;store.saveSession(new JSONObject());} boolean revoked=true;
        try{if(!s.optString("accessToken").isEmpty())raw("/auth/logout","POST",new JSONObject(),s.getString("accessToken"));}catch(Exception e){revoked=false;}
        return new JSONObject().put("revoked",revoked);
    }
    private JSONObject refreshed(JSONObject old,long epoch) throws Exception {
        synchronized(refreshLock){
            if(epoch!=generation)throw new IOException("账户已切换，请重试");
            JSONObject current=store.session();if(!current.optString("accessToken").equals(old.optString("accessToken")))return current;
            JSONObject s=raw("/auth/refresh","POST",new JSONObject().put("refreshToken",old.getString("refreshToken")),"");
            if(epoch!=generation)throw new IOException("账户已切换，请重试");store.saveSession(s);return s;
        }
    }
    JSONObject request(JSONObject p) throws Exception {
        String path=p.getString("path"),method=p.optString("method","GET");
        if(!method.matches("GET|POST|PUT|DELETE")||path.length()>240||!path.matches("/(?:health|cloud/(?:head|history|snapshot)|ai/(?:status|jobs(?:/[A-Za-z0-9_-]+(?:/cancel)?)?)|feed/posts(?:/[A-Za-z0-9_-]+(?:/like)?)?|auth/email/(?:status|send-code|verify|requests/[A-Za-z0-9_-]+)|auth/password/reset|me/email/bind)(?:\\?(?:before|revision)=[0-9]+)?"))throw new IOException("请求无效");
        Object body=p.has("body")?p.get("body"):null;
        boolean publicRoute=path.equals("/health")||path.startsWith("/auth/email/")||path.equals("/auth/password/reset");
        boolean feedRead=path.startsWith("/feed/posts")&&method.equals("GET");
        boolean bind=body instanceof JSONObject&&"bind".equals(((JSONObject)body).optString("purpose"));
        JSONObject s=store.session();long epoch=generation;boolean useToken=!s.optString("accessToken").isEmpty()&&(!publicRoute||bind);
        if(!publicRoute&&!feedRead&&!useToken)throw new ApiError(401,"请先登录");
        if(useToken&&s.optLong("accessExpiresAt")<System.currentTimeMillis()+30000)s=refreshed(s,epoch);
        JSONObject result;
        try{result=raw(path,method,body,useToken?s.getString("accessToken"):"");}
        catch(ApiError e){if(e.status!=401||!useToken)throw e;s=refreshed(s,epoch);result=raw(path,method,body,s.getString("accessToken"));}
        if(epoch!=generation)throw new IOException("账户已切换，请重试");return result;
    }
}
