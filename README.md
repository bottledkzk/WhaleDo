# 鲸办 WhaleDo

今天，慢慢办好。独立移动应用课程项目，包含 HarmonyOS、Android、课程 API 和官网下载站。

[官网下载](https://whaletodo.top) · [Release](https://github.com/bottledkzk/WhaleDo/releases/tag/v0.4.0-signing.1) · [安装说明](docs/INSTALL.md) · [构建说明](docs/BUILD.md) · [验证范围](docs/VERIFICATION.md)

<img src="website/dist/assets/whaledo_mascot.png" alt="鲸办主题" width="220">

## 两端功能

- 今日、待办、日历、助手、我的；鲸鱼娘、默认头像、七色/深浅/圆方主题。
- 快速/详细记录、估时单位、日期日历与时间转轮、重要度与完成自评、重复与回收站。
- 每天/工作休息日/按星期行动时间及今日覆盖；安排预览、确认与撤销。
- 账户隔离、邮箱注册/绑定/找回；手动选范围的云端备份/覆盖/兼容同步。
- 助手会话管理、图片理解、语音与音频入口；新增/编辑/日程提案经用户同意才应用。输入区固定，聊天列表单独滚动。
- 分享卡片、AI配文、PNG/文本/ICS及鲸日分享发布、点赞、分页与自己的删除。
- 时区绝对/相对策略、日记与统计、系统日历和提醒适配。

这是0.4.0课程预览版；功能实现与实机验收范围分别记录，不能据功能清单视为全部设备能力已经通过。真人听写、相机部分路径和鸿蒙后台代理提醒仍有限制，详见验证说明。

## 代码结构

| 目录 | 内容 |
| --- | --- |
| harmony | ArkUI原生课程应用，API24，com.course.whaletodomobile |
| android | Java系统适配与可信本地WebView界面，Android8.0+，com.course.whaledo |
| server | 独立SQLite/Fastify课程API，不含运行数据或凭据 |
| website | 官网静态源码，双端下载与安装限制 |
| scripts | 同源核心打包、模型下载校验、公开源码检查 |
| docs | 安装、构建、验证与依赖声明 |

Android复用14个同源纯业务模块。公开目录保留运行代码与构建输入，仅调整本机构建路径、测试依赖加载与API默认本地数据位置；运行文件哈希见[源码清单](docs/runtime-source-sha256.json)。下载包的哈希另见Release的SHA256SUMS.txt。

## 安全与发布

仓库不包含实际账号、邮箱验证码、访问令牌、模型/SMTP/SSH凭据、服务器地址、数据库、签名私钥或设备Profile。域名是公开业务入口。测试文件中的示例账号/口令只用于本地合成联调。

Android发布包使用独立RSA4096发布证书并保留课程测试签名的升级证明；正式包关闭debuggable和WebView调试。HarmonyOS提供真正的release构建和华为发布签名HAP，供课程方下载验签，普通发布Profile的分发类型为app_gallery，不能作为任意真机通用侧载包。课程发布变体排除尚未获批的代理提醒权限，包含已批准的日历ACL。签名私钥不公开，签名包内嵌必要的公开证书和普通发布Profile签名元数据。

本项目源码公开用于课程展示；未另外授予本项目原创代码与图片的通用开源许可。第三方依赖按其原许可使用，详见[第三方声明](docs/THIRD_PARTY.md)。
