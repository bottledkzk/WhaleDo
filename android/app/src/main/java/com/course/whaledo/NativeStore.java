package com.course.whaledo;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;

final class NativeStore {
    private final Context context;
    private JSONObject session;
    private static final String ALIAS="whaledo-course-session-v1";
    private static final Set<String> RECORDS=Collections.unmodifiableSet(new HashSet<>(Arrays.asList("data","previous-data","library","pending-feed","pending-ai","pending-sync","pending-email","sync-options","reminders")));
    NativeStore(Context context) {this.context=context;}
    private SecretKey key() throws Exception {
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");ks.load(null);
        if(!ks.containsAlias(ALIAS)) {
            KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        return (SecretKey)ks.getKey(ALIAS,null);
    }
    synchronized JSONObject session() throws Exception {
        if(session!=null)return new JSONObject(session.toString());
        AtomicFile file=new AtomicFile(new File(context.getFilesDir(),"session.enc"));
        if(!file.getBaseFile().exists()){session=new JSONObject();return new JSONObject();}
        byte[] encoded=file.readFully();if(encoded.length<29)throw new IOException("账户凭据无法读取，请重新登录");
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Arrays.copyOfRange(encoded,0,12)));
        session=new JSONObject(new String(cipher.doFinal(encoded,12,encoded.length-12),StandardCharsets.UTF_8));return new JSONObject(session.toString());
    }
    synchronized void saveSession(JSONObject value) throws Exception {
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key());
        byte[] encrypted=cipher.doFinal(value.toString().getBytes(StandardCharsets.UTF_8));ByteArrayOutputStream output=new ByteArrayOutputStream();output.write(cipher.getIV());output.write(encrypted);
        writeAtomic(new File(context.getFilesDir(),"session.enc"),output.toByteArray());session=new JSONObject(value.toString());
    }
    synchronized String owner() throws Exception {return session().optJSONObject("user")==null?"guest":session().getJSONObject("user").getString("id");}
    synchronized JSONObject identity() throws Exception {
        JSONObject s=session();return s.optJSONObject("user")==null?new JSONObject().put("id","").put("username",""):new JSONObject(s.getJSONObject("user").toString());
    }
    private File record(String owner,String name) throws Exception {
        if(!owner.equals("guest")&&!owner.matches("[a-f0-9-]{36}"))throw new IOException("账户标识无效");
        if(!RECORDS.contains(name))throw new IOException("记录类型无效");
        File dir=new File(context.getFilesDir(),"accounts/"+owner);if(!dir.isDirectory()&&!dir.mkdirs())throw new IOException("无法创建本机记录");
        return new File(dir,name+".json");
    }
    synchronized Object read(String expectedOwner,String name) throws Exception {
        if(!owner().equals(expectedOwner))throw new IOException("账户已切换，请重试");
        AtomicFile f=new AtomicFile(record(expectedOwner,name));if(!f.getBaseFile().exists())return JSONObject.NULL;
        String text=new String(f.readFully(),StandardCharsets.UTF_8);return new org.json.JSONTokener(text).nextValue();
    }
    synchronized void write(String expectedOwner,String name,Object value) throws Exception {
        if(!owner().equals(expectedOwner))throw new IOException("账户已切换，请重试");
        if(name.equals("previous-data"))throw new IOException("恢复记录只可读取");
        byte[] bytes=String.valueOf(value).getBytes(StandardCharsets.UTF_8);if(bytes.length>24*1024*1024)throw new IOException("本机记录过大，请先整理");
        File file=record(expectedOwner,name);
        if(name.equals("data")&&file.exists()) {
            byte[] prior=new AtomicFile(file).readFully();JSONObject old=new JSONObject(new String(prior,StandardCharsets.UTF_8));
            if(old.optInt("version")==1)writeAtomic(record(expectedOwner,"previous-data"),prior);
        }
        writeAtomic(file,bytes);
    }
    static void writeAtomic(File target,byte[] bytes) throws IOException {
        File parent=target.getParentFile();if(!parent.isDirectory()&&!parent.mkdirs())throw new IOException("无法保存本机记录");
        AtomicFile f=new AtomicFile(target);FileOutputStream out=null;
        try{out=f.startWrite();out.write(bytes);out.getFD().sync();f.finishWrite(out);}catch(IOException e){f.failWrite(out);throw e;}
    }
}
