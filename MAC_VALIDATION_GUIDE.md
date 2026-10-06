# 在另一台 Mac 验证 GymFlow

本次提交包含性能修复、回归测试、独立诊断程序和审计报告。Google Drive 未合并。
原机器上的 Xcode 服务无法访问，因此这些修改尚未完成原生构建或真机测试。
主机回归结果和待验证项见 [PERFORMANCE_FIX_REPORT.md](PERFORMANCE_FIX_REPORT.md)。

## 获取项目

1. 在 Xcode 的仓库克隆界面打开 `https://github.com/gouyuanshuo/GymFlow.git`。
2. 使用 `main` 分支，打开 `GymFlow.xcodeproj`。
3. 顶部运行 Scheme 选择 **GymFlow**，不要选择 `GymFlowLiveActivityExtension` 作为运行应用。

如果另一台 Mac 已有克隆，先保留它自己的未提交修改，再更新 `main`。

## 先在模拟器测试

1. 安装 Xcode 所需的 iOS 平台和模拟器运行环境。
2. 选择一个可用的 iPhone 模拟器作为运行目标。
3. 选择 **Product → Build**（⌘B）。
4. 选择 **Product → Test**（⌘U），运行 `GymFlowTests` 和 `GymFlowUITests`。
5. 在 Report Navigator 保存构建、测试结果和失败日志。

完整 UI 测试会操作应用数据，使用专门用于测试的模拟器。

可选的 Terminal 命令（在项目目录运行）：

```bash
xcrun simctl list devices available
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/GymFlowValidation CODE_SIGNING_ALLOWED=NO build
```

从设备列表选择实际安装的模拟器，将下面的 `SIMULATOR_UDID` 替换后运行：

```bash
xcodebuild -project GymFlow.xcodeproj -scheme GymFlow -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' -derivedDataPath /tmp/GymFlowValidation CODE_SIGNING_ALLOWED=NO test
```

## 在现有 iPhone 上构建并运行

1. 使用支持手机当前 iOS 版本的 Xcode，连接并解锁 iPhone，完成手机与 Mac 的信任提示。
2. 按 Xcode 的要求启用手机的 Developer Mode。
3. 在 Xcode 设置中登录原来的 Apple 开发账户，确认主应用和 Live Activity 扩展使用正确的签名 Team。
4. 保持主应用 Bundle Identifier 为 `com.gouyuanshuo.GymFlow`，保持已有签名身份对应的 Team。
5. Scheme 保持 **GymFlow**，运行目标选择实际连接的 iPhone。
6. 先 **Product → Build**（⌘B），再 **Product → Run**（⌘R），覆盖安装并启动。

保留手机上现有 GymFlow 和数据。遇到签名或安装失败时记录具体错误，不要通过卸载应用、重置样例或清空 SwiftData 来解决。
如果需要在这部手机运行单元测试，从 Test Navigator 只运行 `GymFlowTests`；完整 UI 测试留在测试模拟器中。

## 真机验收

依照 [性能修复报告的十二项检查](PERFORMANCE_FIX_REPORT.md#remaining-unverified-risks-and-physical-device-checklist)，检查 Exercise Detail、分享预览与导出、训练预填、休息计时、音乐暂停恢复、大文件导入、训练结束、锁屏媒体控制和 Live Activity。

记录手机型号、iOS/Xcode 版本、代码提交 SHA、构建/测试结果，以及每个失败的复现步骤。
独立 SwiftData 基准使用临时内存数据库；它的耗时不代表 iPhone 界面的实际耗时。
