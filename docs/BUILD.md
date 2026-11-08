# 构建与本地检查

将仓库克隆到仅含ASCII字符的路径，避免Hvigor中文路径限制。需要Node24+、Python3、JDK21、AndroidSDK36/BuildTools35、Gradle8.13；鸿蒙使用DevEcoStudio6.1.1.418/API24。

先运行npm ci --prefix android和npm ci --prefix server。然后：

```text
node scripts/build-android-core.cjs
python scripts/prepare-speech-model.py
node --test harmony/tests/*.test.cjs
npm test --prefix android
npm test --prefix server
npm run typecheck --prefix server
node scripts/check-public.cjs
```

鸿蒙：使用DevEcoStudio打开harmony，或设DEVECO_HOME并执行harmony/build.ps1。默认按debug构建；-BuildMode release生成关闭debug的release HAP。输出entry/build/default/outputs/default/entry-default-unsigned.hap；构建模式与签名是否存在是两个独立属性。

课程发布变体在独立ASCII目录构建，生成脚本仅移除未获批准的PUBLISH_AGENT_REMINDER权限，不修改开发源码。READ_WHOLE_CALENDAR继续保留并必须由签名Profile授权：

```text
node scripts/prepare-harmony-release.cjs D:/WhaleDoHarmonyRelease
& D:/WhaleDoHarmonyRelease/build.ps1 -BuildMode release
```

取得自己账号的发布证书和普通发布Profile后，使用DevEco Studio手动发布签名或SDK官方hap-sign-tool.jar的sign-app完成签名。私钥、口令和Profile存于仓库外；不要提交到Git或把口令写入构建脚本。普通发布Profile用于应用市场分发，不能把其文件验签通过视为任意真机侧载可用；课程安装请按官方指定设备发布流程准备设备与Profile。

独立核验官方签名、Profile签名、证书匹配、release/debug标记及课程ACL：

```text
python scripts/verify-harmony-release.py WhaleDo-Harmony-0.4.0-api24-release-signed.hap --output Harmony-signing-verification.json
```

该命令读取DEVECO_HOME，或可传--deveco-home。Release中的Harmony-signing-verification.json和Harmony-release-build-inputs.json记录签名回执、生成变体和运行输入哈希，不提供私钥。签名核验不替代真机安装与功能验收。

Android：执行android/build.ps1 -Gradle <gradle.bat> -JavaHome <JDK21> -AndroidSdk <SDK> -Variant Release。缓存均位于工程自己的.local-build。缺少WHALEDO_STORE_FILE时生成unsigned APK，不能直接作为正式安装包；用自己的私钥签名，不能获得官方覆盖升级身份。Gradle签名支持WHALEDO_STORE_FILE/WHALEDO_STORE_PASSWORD/WHALEDO_KEY_ALIAS/WHALEDO_KEY_PASSWORD，均通过本地环境提供。

-Variant Verification -TestApk生成独立.verification包及Instrumentation APK。设备测试只针对该隔离包。音频样本须单独放在android/app/src/androidTest/assets/asr_example_zh.wav，不进入正式包。

server使用Node24内置SQLite，运行npm start --prefix server前参考server/.env.example配置本地数据库。SMTP/AI可选，未提供配置时相应能力停用；私密配置放在仓库之外。服务只监听回环18080，公开服务应自行配置可信HTTPS反向代理。这里不提供生产部署脚本或凭据。

website/dist为无需构建的静态站点，python -m http.server 8769 --directory website/dist可预览。Sites托管信息不包含访问凭据；重新部署需拥有对应站点权限。
