# 代码目录

两端通过 Target Membership 共用源码，无独立 Package。

```text
ClipCV/
├── Shared/
│   ├── Models/             # 历史与内容模型
│   ├── Storage/            # 同库配置、历史操作、共享清理规则
│   ├── Clipboard/          # 内容规则、键盘文本快照
│   └── Services/           # OCR、JSON / Markdown
├── iOS/
│   ├── App/                # 启动、生命周期、隔离演示数据
│   ├── Clipboard/          # UIPasteboard 采集与写回
│   ├── Services/           # 同步状态、缩略图
│   ├── Settings/
│   ├── UI/
│   ├── Resources/
│   └── Localizable.xcstrings
├── Extensions/Keyboard/    # 只读快照，通过文本代理插入
├── Models/                 # 其余 Mac 专属模型
├── Services/               # Mac 采集、文件授权、热键等
├── UI/                     # Mac 面板、桌面与设置
├── ClipCVApp.swift         # Mac 入口
├── Assets.xcassets         # Mac 图标
└── *Info.plist / *.entitlements

ClipCVTests/                # Mac 回归与共用存储测试
ClipCViOSTests/             # 隔离剪贴板采集、共用存储测试
ClipCViOSUITests/           # 隔离演示库的界面流程
```

`Shared` 不依赖 AppKit、UIKit 或平台入口。富文本解码等平台差异保留在各自的 `ClipboardRules` 扩展中。Mac 专属文件暂留原目录，`macOS/` 保留目录占位。

每台设备使用一个 `clipboard-v4.store`。iCloud 开关完整重开后生效；暂停只停止本机采集。启用同步后，数量与容量规则由同一个 iCloud KVS 标识共享；未取得已有策略前不按新设备默认值自动删除。

键盘 Target 只编译视图、控制器与 `KeyboardSnapshot`，不打开数据库，不运行 CloudKit 或 OCR。主应用写入最多 60 条、每条 8 KB、总共 512 KB 的文本快照，键盘请求的完全访问权限为关闭。

## 运行

打开 `ClipCV.xcodeproj`：

- `ClipCV → My Mac`：macOS 27+
- `ClipCViOS → iPhone / iPad`：iOS 27+

按 `⌘R`。iOS 主应用自动嵌入 `ClipCVKeyboard`，安装后在系统键盘设置中添加 ClipCV。

真机签名需要为主应用配置 CloudKit、App Groups、iCloud 键值存储，为键盘配置相同的 App Group。共享标识见各 Target 的 entitlements。

功能进度见 [iOS TODO](ios-todo.md)，交互约定见 [功能规划](ios-design.md)。
