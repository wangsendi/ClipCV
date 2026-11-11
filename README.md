<img src="docs/images/banner.png" alt="ClipCV" width="128">

# ClipCV

原生 macOS 剪贴板历史工具，支持搜索、钉选、图片预览和本机 OCR。需要 macOS 27+。

[下载最新版](https://github.com/wangsendi/ClipCV/releases/latest/download/ClipCV.dmg) · [English](README.en.md)

## 安装

1. 下载并打开 `ClipCV.dmg`，将应用拖入「应用程序」。
2. 按 `⌘⇧C` 打开历史面板。
3. 使用自动粘贴前，在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权 ClipCV。

## 功能

- 保存文本、链接、富文本、图片和文件路径。
- 精确、模糊、正则搜索，按内容类型或来源应用筛选。
- 钉选常用内容，支持桌面悬浮窗与拖拽。
- 图片预览、保存时缩放、文字识别及颜色预览。
- 忽略规则、暂停记录、容量限制和自动清理。
- 中英文界面、可选 iCloud 同步、自动更新。

## 默认快捷键

| 操作 | 快捷键 |
| --- | --- |
| 打开剪贴板历史 | <kbd>⌘⇧C</kbd> |
| 钉选 / 取消钉选 | <kbd>⌥P</kbd> |
| 删除条目 | <kbd>⌥⌫</kbd> |
| 打开预览 | <kbd>⌃Space</kbd> |

面板中默认按 `↩` 复制、`⌥↩` 粘贴；字母键调用钉选条目，`⌘1`–`⌘0` 调用最近条目。快捷键与默认行为可在设置中调整。

## 文档

[常见问题](docs/faq.md) · [隐私说明](docs/privacy.md) · [构建与发布](docs/development.md)

## 许可证与鸣谢

自本次许可变更起，项目自有代码采用 [PolyForm Noncommercial 1.0.0](LICENSE)，允许非商业使用、修改和分发；商业使用需另行取得作者授权。

此前按 MIT 发布的代码仍可按 MIT 使用。第三方组件遵循各自的许可证。

交互参考 [Maccy](https://github.com/p0deje/Maccy)，自动更新使用 [Sparkle](https://github.com/sparkle-project/Sparkle)。
