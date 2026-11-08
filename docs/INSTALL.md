# 安装鲸办0.4.0

## Android

从[Release](https://github.com/bottledkzk/WhaleDo/releases/tag/v0.4.0)下载WhaleDo-Android-0.4.0.apk。支持Android8.0/API26及以上，target36，versionCode40001。按系统提示允许所用下载应用安装APK，再打开文件。

APK由WhaleDo独立发布证书签名，SHA256指纹：1e37e151927c9974177f4ba628da3ff1e05d313d033ac8ecfa59cf53464a7e5d。使用Android签名轮换证明，API28+使用新证书，API26/27保留兼容签名；发布包关闭debuggable。已在API36模拟器和小米API36手机覆盖旧课程测试包，不卸载、不清数据。

不要为签名不一致而卸载已有含重要记录的应用；先核对包名、签名和数据备份。第三方重建包需要自己的密钥，不能冒充官方升级。

## HarmonyOS

WhaleDo-Harmony-0.4.0-api24-unsigned.hap是**未签名调试包**，API24，包名com.course.whaletodomobile，versionCode40000。可用于DevEco Studio模拟器调试；不是所有鸿蒙真机都能直接打开安装的商用发行包。

真机需要开发者自己的调试证书、设备登记及对应Profile，使用DevEco Studio的调试签名流程构建/签名，再由官方调试工具安装。仓库与Release不提供私钥、设备标识或设备绑定Profile。

应用声明的READ_WHOLE_CALENDAR属于受限权限。批量日历调试必须具备相应ACL并添加到Profile；课程已获批准不代表其他开发者账户自动获得。代理提醒尚未获准，本项目按课程范围暂停补件；普通通知不等同于后台代理提醒已可用。

保持既有正式包名并覆盖安装，避免卸载导致记录丢失。构建和安装步骤见BUILD.md，华为签名/Profile流程以[官方说明](https://developer.huawei.com/consumer/cn/doc/app/agc-help-add-releaseprofile-0000001914714796)为准。

## 文件校验

Release提供SHA256SUMS.txt。Windows可用Get-FileHash -Algorithm SHA256，Linux/macOS可用sha256sum，对照所下载文件。源码ZIP不包含语音模型；脚本从官方地址按固定SHA256下载。正式AndroidAPK已内置模型。
