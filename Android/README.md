# GymFlow Android（中文版）

这是 GymFlow iOS 应用的原生 Android 移植版，面向 Android 8.0（API 26）及以上设备。应用默认使用简体中文，完全离线运行，不需要账号，也不会上传训练或音乐数据。

## 已移植功能

- 今天、计划、历史、音乐、设置五个主页面
- 中文动作库、训练计划管理和逐组训练记录
- 重量/次数选择器、热身组、备注、上次表现和个人最佳
- 可恢复的休息计时器、声音/振动提醒和训练通知快捷操作
- 月历、历史详情、训练统计和训练海报分享
- 本地 MP3、M4A、AAC、WAV、AIFF、CAF、FLAC、OGG、OPUS 导入
- 播放列表、顺序/随机/循环播放、锁屏媒体控制和训练自动播放
- SQLite 本地存储；无网络、无账号、无广告和无分析服务

## 安装 APK

1. 把 `GymFlow-Android-v1.0.0.apk` 发送到 Android 手机。
2. 在手机的文件管理器或聊天软件中打开 APK。
3. 如果系统提示，请只为当前文件来源开启“允许安装未知应用”。
4. 点击“安装”，首次打开时按需要允许通知权限。

Android 可能会提示这是来自浏览器、网盘或聊天软件的外部应用，这是侧载 APK 的正常提示。本 APK 使用项目专属的本地签名；以后升级必须继续使用同一签名。

## 开发构建

需要 JDK 17 或更新版本以及 Android SDK 36。本机 Android 工具链集中在 `D:\Android`，本目录的 `local.properties` 使用：

```properties
sdk.dir=D\:\\Android\\android-sdk
```

然后运行：

```powershell
.\gradlew.bat clean testDebugUnitTest assembleDebug
```

调试 APK 输出到 `app/build/outputs/apk/debug/app-debug.apk`。

本机模拟器数据位于 `D:\Android\avd`。启动可视化测试机：

```powershell
$env:ANDROID_AVD_HOME = "D:\Android\avd"
Start-Process "D:\Android\android-sdk\emulator\emulator.exe" `
  -ArgumentList "-avd", "GymFlow_Visual_API36"
```

Windows 用户环境变量 `ANDROID_HOME`、`ANDROID_SDK_ROOT`、`ANDROID_AVD_HOME` 和 `GRADLE_USER_HOME` 已分别指向 `D:\Android\android-sdk`、`D:\Android\avd` 和 `D:\Android\gradle-cache`。修改后需重新打开 PowerShell 才会自动继承这些值。

日常模拟无需记命令：在仓库根目录双击 `启动 GymFlow Android.bat`。脚本会自动启动或复用可视化模拟器、等待开机、按需安装分发 APK并打开 GymFlow。

最终分发包使用 `.private/gymflow-release.jks` 签名；该目录已被 Git 忽略。请备份这个签名文件和同目录的本地签名配置，后续同包名覆盖升级必须使用相同签名。

## 数据说明

应用数据库和导入音频均保存在 Android 应用私有目录。覆盖安装同签名的新版本会保留数据；卸载应用或在设置中删除全部数据会移除训练记录和应用内音频副本。分享海报只包含训练摘要，不包含备注、音乐、内部标识或设备信息。
