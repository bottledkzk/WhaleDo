# 鸿蒙签名更新与课程核验

更新：2026-11-08。应用功能版本仍为0.4.0；签名补充标签为[v0.4.0-signing.1](https://github.com/bottledkzk/WhaleDo/releases/tag/v0.4.0-signing.1)。

## 发生了什么变化

此前v0.4.0提供debug模式未签名HAP，当时尚未申请发布证书与Profile。本次已申请华为发布证书、普通发布Profile，并重新以release模式构建后签名；不是给旧debug文件改名。旧标签、旧源码ZIP及旧安装文件保留，便于追溯。

| 文件/属性 | 当前签名补充包 | 旧v0.4.0 |
| --- | --- | --- |
| 鸿蒙文件 | WhaleDo-Harmony-0.4.0-api24-release-signed.hap | WhaleDo-Harmony-0.4.0-api24-unsigned.hap |
| 构建模式 | release，debug=false | debug，未签名 |
| 用途 | 下载核验发布构建、证书与文件完整性 | 本地模拟器调试与历史复现 |
| 证书/Profile | 华为发布证书；普通发布Profile，release/app_gallery | 不含发布签名 |
| 日历ACL | 已加入READ_WHOLE_CALENDAR | 真机另需相应授权与Profile |
| 代理提醒 | 课程发布变体移除未获准的PUBLISH_AGENT_REMINDER | 开发源码保留适配，不能据此视为可用 |

发布证书与Profile有效至2029-11-08。内嵌Profile没有设备列表，未申请应用市场上架。Android APK完全沿用已验证的0.4.0/code40001文件，本次没有换签或重打包Android。

## 下载后怎样核验

1. 对照同一Release的SHA256SUMS.txt计算文件SHA256，避免混用两个标签的清单。
2. HAP应为9,075,940字节，SHA256为`bf4bdbae24a6d8f2aa7b1c514c04efb3ba37f8a277f587b82d8de6eb6d4f874e`。
3. 发布证书SHA256指纹为`31788e67b9bcdcae993ff5947054780a22ac3b90ec87eff6aeee34c48300f051`。包名com.course.whaletodomobile、API24、versionCode40000。
4. 安装DevEco Studio后，按[构建说明](BUILD.md)运行scripts/verify-harmony-release.py，调用官方SDK的verify-app和verify-profile。随包回执见Harmony-signing-verification.json，实际发布输入和生成规则见Harmony-release-build-inputs.json。

官方工具验签、证书与Profile匹配、release/debug标记和ZIP完整性均已通过。文件核验不替代设备安装及业务功能验收。

## 课程方编译与真机安装

源码不需要生产私钥即可编译：在ASCII目录解压工程，准备对应SDK，按BUILD.md构建未签名HAP并运行本地模拟器。课程release变体使用prepare-harmony-release.cjs生成，明确排除未获准代理提醒权限。重新构建出的二进制、证书或哈希不保证与官方已签名下载包相同；私有签名材料不进入源码ZIP。

**普通发布签名不能保证任意鸿蒙真机直接侧载。** 当前Profile的分发类型是app_gallery；课程方若需在自己的真机安装，应登记目标设备并另配指定设备发布Profile，或使用自己的开发者账号和调试签名。不要把“没有设备列表”理解为没有安装限制。受限日历能力还需当前签名Profile覆盖相应ACL。

已有调试签名应用与新发布签名包不能直接推定为可互相覆盖升级。签名或分发类型不匹配时，先备份数据、核对包名和签名；不要直接卸载含重要记录的应用。Android继续使用既有发布证书与轮换证明，不受这次鸿蒙签名补充影响。

## 公开与私有材料

公开包内嵌验签必需的公开证书和普通发布Profile元数据；独立设备标识、设备绑定Profile、签名私钥、口令、真实测试账户和服务凭据不公开。后续签名应复用已保存的发布密钥，避免无故重建导致身份变化。

官方依据：[申请发布证书](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-cert-0000002283336729/)、[申请发布Profile](https://developer.huawei.com/consumer/cn/doc/App/agc-help-release-profile-0000002248341090/)、[指定设备发布Profile](https://developer.huawei.com/consumer/cn/doc/App/agc-help-internaltest-profile-0000002283260129/)。
