# 开发指南

[首页](../README.md) · [English](development.en.md)

需要 macOS 27+、Xcode 27+。依赖 [Sparkle 2](https://github.com/sparkle-project/Sparkle)，由 Swift Package Manager 解析。

## 构建与测试

```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
open ClipCV.xcodeproj
```

在 Xcode 选择 `ClipCV → My Mac` 或 `ClipCViOS → iPhone 模拟器`，按 `⌘R`。命令行：

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -configuration Debug build
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -only-testing:ClipCVTests test
xcodebuild -project ClipCV.xcodeproj -scheme ClipCViOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## 发布

1. 设置 Version 和 Build，二者相同，每次发布递增。
2. 本地构建 Release，完成 Developer ID 签名、公证，打包为 `ClipCV.dmg`。
3. 创建 [Release](https://github.com/wangsendi/ClipCV/releases)，标签使用 `v版本号`，上传 DMG 后发布正式版本。
4. [Update appcast](../.github/workflows/update-appcast.yml) 自动生成签名并提交 `appcast.xml`，无需手改。

EdDSA 私钥保存在本机钥匙串和 `SPARKLE_PRIVATE_KEY` Actions secret 中，不提交到 Git。

替换已发布的安装包后，手动运行 **Actions → Update appcast → Run workflow**。Appcast 使用固定版本下载地址，保证签名与安装包一致。

## 代码位置

共用逻辑在 `ClipCV/Shared`，手机端在 `ClipCV/iOS`，键盘在 `ClipCV/Extensions/Keyboard`。Mac 专属逻辑保留在原 `Models`、`Services` 和 `UI`。详见[目录说明](architecture.md)。

Mac 文案位于 [Localization.swift](../ClipCV/Services/Localization.swift)，iOS 使用 `ClipCV/iOS/Localizable.xcstrings`。

iOS 启动参数 `--design-preview` 使用内存库与演示内容，不采集或改写系统剪贴板。单元测试使用内存库及独立剪贴板，UI 测试使用演示库。PiP、真实双端同步及键盘验收见 [iOS TODO](ios-todo.md)。

自动构建与测试见 [CI](../.github/workflows/ci.yml)。
