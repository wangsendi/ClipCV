# 开发指南

## 环境要求

| 依赖 | 版本 |
| --- | --- |
| macOS | 26+ |
| Xcode | 27+（含 Swift 6 工具链） |
| 第三方库 | [Sparkle 2](https://github.com/sparkle-project/Sparkle)（SPM 自动解析，无其他依赖） |

## 构建

```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
open ClipCV.xcodeproj   # Xcode 中 ⌘R 运行
```

命令行构建：

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -configuration Debug build
```

> Sparkle 的 XCFramework 通过 SPM artifact 下载。若解析不完整，删除 `~/Library/Developer/Xcode/DerivedData` 中的 SourcePackages 后重试，或带 `-clonedSourcePackagesDirPath` 单独解析。

## 测试

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV \
  -only-testing:ClipCVTests test
```

## CI

GitHub Actions 工作流：[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

- 触发：push / PR 到 `main`
- Runner：`xcode-27`（自动选择最新 Xcode）
- 步骤：SPM 缓存 → 解析依赖 → Debug 构建 → 单元测试 → 校验 Sparkle 框架嵌入与 Info.plist 更新配置

## 发布流程

1. 在 Xcode 设置 Version；Build 跟随 Version，每次发布都应递增。
2. 本地构建 Release，完成 Developer ID 签名、公证并打包为 `ClipCV.dmg`。
3. 在 [ClipCV Releases](https://github.com/wangsendi/ClipCV/releases) 创建对应版本的 Release（例如 `v1.0.2`），上传 `ClipCV.dmg` 后点击 Publish release。
4. [Update appcast](../.github/workflows/update-appcast.yml) 自动读取安装包的版本和系统要求，生成 EdDSA 签名、校验并提交 `appcast.xml`，无需手动修改。

应用的更新源为 `https://raw.githubusercontent.com/wangsendi/ClipCV/main/appcast.xml`。安装包首次切换到新更新源后，需要手动下载安装一次；之后发布新版即可自动检测更新。

普通下载入口可使用 `https://github.com/wangsendi/ClipCV/releases/latest/download/ClipCV.dmg`。Appcast 使用具体版本的固定下载地址，避免缓存的签名与安装包不一致。替换已发布 Release 的安装包后，手动运行 Actions → Update appcast → Run workflow 刷新更新源。

EdDSA 私钥保存在本机钥匙串和仓库的 `SPARKLE_PRIVATE_KEY` Actions secret 中，不提交到 Git；应用只包含公钥（`SUPublicEDKey`）。

## 代码结构

```
ClipCV/
├── Models/               # SwiftData 模型（ClipboardItem 等）
├── Services/
│   ├── ClipboardMonitor.swift    # 剪贴板轮询监听
│   ├── ClipboardRules.swift      # 类型识别与忽略规则
│   ├── SearchService.swift       # 精确/模糊/正则搜索
│   ├── OCRService.swift          # Vision OCR
│   ├── HotkeyManager.swift       # Carbon 全局快捷键
│   ├── SoftwareUpdater.swift     # Sparkle 封装
│   ├── DesktopPinSnapshot.swift  # 桌面钉选悬浮窗
│   └── Localization.swift        # 中英文本地化
├── UI/
│   ├── HistoryPanel.swift        # 历史弹窗面板
│   ├── HistoryView.swift         # 历史列表
│   ├── MenuBarController.swift   # 菜单栏图标与菜单
│   ├── DesktopPinController.swift# 桌面钉选窗口
│   └── Settings/                 # 设置窗口各分页
└── ClipCVTests/                  # 单元测试
```

## 本地化

文案集中在 `Services/Localization.swift` 的 `zh` / `en` 字典。新增文案时：

1. 在 `L10n.Key` 枚举中加 key
2. 在 `zh` 与 `en` 字典中补齐两种语言
3. 通过 `L10n.t(.yourKey)` 引用

## 贡献

欢迎 Issue / PR。提交前请确保：

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -only-testing:ClipCVTests test
```

全部通过。
