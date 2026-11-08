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

鸿蒙：使用DevEcoStudio打开harmony，或设DEVECO_HOME并执行harmony/build.ps1。该脚本按debug构建未签名HAP，输出entry/build/default/outputs/default/entry-default-unsigned.hap。真机签名由自己的开发者账号配置。

Android：执行android/build.ps1 -Gradle <gradle.bat> -JavaHome <JDK21> -AndroidSdk <SDK> -Variant Release。缓存均位于工程自己的.local-build。缺少WHALEDO_STORE_FILE时生成unsigned APK，不能直接作为正式安装包；用自己的私钥签名，不能获得官方覆盖升级身份。Gradle签名支持WHALEDO_STORE_FILE/WHALEDO_STORE_PASSWORD/WHALEDO_KEY_ALIAS/WHALEDO_KEY_PASSWORD，均通过本地环境提供。

-Variant Verification -TestApk生成独立.verification包及Instrumentation APK。设备测试只针对该隔离包。音频样本须单独放在android/app/src/androidTest/assets/asr_example_zh.wav，不进入正式包。

server使用Node24内置SQLite，运行npm start --prefix server前参考server/.env.example配置本地数据库。SMTP/AI可选，未提供配置时相应能力停用；私密配置放在仓库之外。服务只监听回环18080，公开服务应自行配置可信HTTPS反向代理。这里不提供生产部署脚本或凭据。

website/dist为无需构建的静态站点，python -m http.server 8769 --directory website/dist可预览。Sites托管信息不包含访问凭据；重新部署需拥有对应站点权限。
