# 鲸办 WhaleDo · 更新记录

## 0.4.0-signing.1：鸿蒙发布签名补充（2026-11-08）

已申请生效的华为发布证书及普通发布Profile，重新构建release HAP（debug=false）并完成HAP/Profile双重官方验签。包含已批准的READ_WHOLE_CALENDAR；课程发布变体排除尚未获准的PUBLISH_AGENT_REMINDER。应用功能版本仍0.4.0，Android APK不变，旧v0.4.0标签保留。

当前下载请使用[签名补充Release](https://github.com/bottledkzk/WhaleDo/releases/tag/v0.4.0-signing.1)。普通发布Profile分发类型为app_gallery，供课程方下载验签，不保证任意真机侧载；课程设备安装应另配指定设备发布Profile或自行调试签名。签名差异、覆盖升级、源码编译及核验方法见[签名更新说明](SIGNING.md)。

## 0.4.0：首次课程预览（历史）

首次独立公开发布鸿蒙与Android课程源码、Android正式签名APK和鸿蒙API24未签名调试HAP。官网提供双端下载入口。图片、头像和OCR选图优先使用系统照片选择器，旧设备使用图库入口；音频仍从文件选择器导入。

本版加入鲸鱼娘主题、鲸日分享与点赞、匹配卡片风格的AI配文，以及必须由用户确认的事项编辑/日程提案。两端助手输入区固定，图片入口合并，添加图片/语音输入/音频转写/发送在输入框下并排。Android同时修复null文字、时间转轮尺寸与位置、我的/设置文字垂直偏移；接入兼容的返回手势，并为Android8导航栏资源设置正确的版本限定。

Android支持API26+，发布包关闭debuggable，使用独立RSA4096发布证书及课程测试包升级证明；API36模拟器和小米真机覆盖安装成功。完整签名及文件哈希见Android-signature.txt和SHA256SUMS.txt。

**鸿蒙下载项未签名，普通真机不可直接安装。**用于模拟器调试；真机需自己的证书、设备Profile与相应ACL。没有提供通用商用鸿蒙签名包，也不包含私钥或Profile。

检查：鸿蒙95项、课程API62项、Android前端10项通过；API36模拟器7项布局设备回归通过。真人听写、Android部分系统能力及真实端侧API全流程、部分云相机路径仍待进一步验证；鸿蒙后台代理提醒未获准。公开发布不代表这些限制已消除。

源码ZIP与仓库包含harmony、android、server、website及构建/验证说明，排除账号、令牌、模型/SMTP/SSH凭据、服务器地址、数据库、设备标识和签名材料。Android语音模型已在APK内；源码通过固定SHA256脚本从官方站点下载。

仓库：https://github.com/bottledkzk/WhaleDo
官网：https://whaletodo.top
安装说明：https://github.com/bottledkzk/WhaleDo/blob/main/docs/INSTALL.md
