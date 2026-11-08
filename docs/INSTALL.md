# 安装鲸办0.4.0

## Android

从[Release](https://github.com/bottledkzk/WhaleDo/releases/tag/v0.4.0-signing.1)下载WhaleDo-Android-0.4.0.apk。支持Android8.0/API26及以上，target36，versionCode40001。按系统提示允许所用下载应用安装APK，再打开文件。

APK由WhaleDo独立发布证书签名，SHA256指纹：1e37e151927c9974177f4ba628da3ff1e05d313d033ac8ecfa59cf53464a7e5d。使用Android签名轮换证明，API28+使用新证书，API26/27保留兼容签名；发布包关闭debuggable。已在API36模拟器和小米API36手机覆盖旧课程测试包，不卸载、不清数据。

不要为签名不一致而卸载已有含重要记录的应用；先核对包名、签名和数据备份。第三方重建包需要自己的密钥，不能冒充官方升级。

## HarmonyOS

WhaleDo-Harmony-0.4.0-api24-release-signed.hap是**发布签名核验包**，API24，包名com.course.whaletodomobile，versionCode40000。实际使用release模式构建，debug=false；华为发布证书和普通发布Profile均已生效，官方工具对HAP及内嵌Profile验签通过。证书SHA256指纹：31788e67b9bcdcae993ff5947054780a22ac3b90ec87eff6aeee34c48300f051。

本包供课程方下载、检查release构建信息、文件完整性和发布签名。Profile类型release、分发类型app_gallery，无设备标识；**普通发布签名不代表任意鸿蒙真机均可侧载安装**，此项目未上架应用市场。若课程方需要在自己的真机安装，应登记该设备并另配“指定设备发布Profile”，或使用自己的开发者调试签名。不能用已有调试Profile的设备列表推定普通发布包可安装。请勿为换签名而直接卸载已有重要记录。

READ_WHOLE_CALENDAR已经加入本次发布Profile，仅按已批准的课程场景使用；不代表其他开发者账户自动获得。代理提醒尚未获准，本次课程发布变体明确排除PUBLISH_AGENT_REMINDER，不申请补件；相关后台提醒不计为可用能力。原开发源码仍保留提醒适配，发布生成步骤见BUILD.md。

旧v0.4.0 Release保留未签名调试HAP供历史模拟器复现。仓库及下载文件不含签名私钥、口令或设备绑定Profile；签名包必然内嵌公开证书及普通发布Profile的签名元数据。新补充标签v0.4.0-signing.1未改变应用功能版本0.4.0。

官方流程：[发布Profile](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-profile-0000002248341090/)、[指定设备发布Profile](https://developer.huawei.com/consumer/cn/doc/App/agc-help-internaltest-profile-0000002283260129/)。

## 文件校验

Release提供SHA256SUMS.txt。Windows可用Get-FileHash -Algorithm SHA256，Linux/macOS可用sha256sum，对照所下载文件。源码ZIP不包含语音模型；脚本从官方地址按固定SHA256下载。正式AndroidAPK已内置模型。
