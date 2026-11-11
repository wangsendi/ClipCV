<div align="center">

<img src="docs/images/banner.png" alt="ClipCV" width="128">

# ClipCV

**剪贴板，快人一步。**

快速、私密、原生的 macOS 剪贴板历史管理工具。

[功能特性](#-功能特性) · [安装](#-安装) · [快捷键](#-快捷键) · [构建](#-从源码构建) · [English](README.en.md)

macOS 26+ · Swift · SwiftUI · Sparkle 2

</div>

---

## 为什么做 ClipCV

复制、切换窗口、粘贴、再切换、再粘贴——重复复制粘贴浪费了大量时间。ClipCV 把每一次复制都记入历史：按下快捷键，输入几个字母，回车粘贴。全程不离键盘。

- **快**：按下 <kbd>⌘⇧C</kbd>，开始输入，<kbd>↩</kbd> 粘贴。通常 2 秒内完成。
- **私密**：所有数据保存在本机，不上传任何服务器。
- **原生**：原生 macOS 应用，菜单栏常驻，流畅、省电、不像 Electron。

## ✨ 功能特性

### 剪贴板历史
- 保存文本、链接、富文本（RTF/HTML）、图片（PNG/TIFF）、文件路径
- 模糊 / 正则 / 精确搜索，多关键词（如 `sig file` 搜签名图片）
- 按应用过滤历史（`from:Safari`）
- 分类筛选：文本 / 图片 / 链接 / 文件 / 颜色 / 已钉选
- 按最后复制 / 首次复制 / 复制次数排序
- 编辑任意条目的别名与内容
- 复制次数统计

### 钉选 PIN
- 钉选常用片段，单键快速调用
- 自定义键位顺序（默认 `QWEASDZXC`）
- **钉到桌面**：悬浮窗常驻屏幕，随时可拖拽内容到其他 App
- 两种钉选布局：置顶 / 置底

### 图片工具
- OCR 文字识别（Vision 框架，本机运行）：识别后可直接复制文字
- 十六进制颜色显示色块（如 `#FF4F00`）
- 图片保存时可选缩放比例，控制占用空间
- 大图预览，显示尺寸与文件大小

### 隐私与控制
- 忽略指定 App（如密码管理器）、剪贴板类型、正则规则
- 「忽略下一次复制」
- 暂停 / 恢复记录
- 退出时清空历史 / 系统剪贴板
- 限制历史条数与总容量，超限自动清理

### 外观与本地化
- 中英文界面，可跟随系统
- 多款菜单栏图标（默认为 ClipCV 专属图标）
- 菜单栏显示最近一条内容
- 明暗模式自动适配

### 同步与更新
- 可选 iCloud 同步（多台 Mac 共享历史）
- Sparkle 2 自动更新（EdDSA 签名校验）

## 📥 安装

### 下载
从 [Releases](https://github.com/wangsendi/ClipCV/releases/latest) 下载最新安装包，打开 DMG 或解压 ZIP 后，将 `ClipCV.app` 拖入「应用程序」文件夹。

> 首次启动若提示无法验证开发者，请前往 **系统设置 → 隐私与安全性**，点「仍要打开」。

### 从源码构建
```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
open ClipCV.xcodeproj
```
在 Xcode 中直接 <kbd>⌘R</kbd> 运行。需要 Xcode 27+ 与 macOS 26+。

首次启动需在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权 ClipCV（用于全局快捷键与自动粘贴）。

## ⌨️ 快捷键

| 操作 | 默认快捷键 |
| --- | --- |
| 打开剪贴板历史 | <kbd>⌘⇧C</kbd> |
| 钉选 / 取消钉选 | <kbd>⌥P</kbd> |
| 删除条目 | <kbd>⌥⌫</kbd> |
| 打开大图预览 | <kbd>⌃Space</kbd> |

历史列表中：<kbd>1</kbd>–<kbd>0</kbd> 直接粘贴最近条目，<kbd>⌘Q</kbd>–<kbd>⌘C</kbd> 调用钉选条目（可自定义）。所有快捷键均可在设置中修改。

## 🔒 隐私

ClipCV 不联网上传任何数据（仅检查软件更新时访问 GitHub）：

- 历史数据保存在本地 SwiftData 数据库
- OCR 识别完全在本机完成（Apple Vision）
- iCloud 同步为可选项，默认关闭
- 可配置忽略指定应用 / 类型 / 正则，防止敏感内容进入历史

## 🛠 从源码构建

```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -configuration Release build
```

依赖通过 Swift Package Manager 自动解析（仅 [Sparkle 2](https://github.com/sparkle-project/Sparkle)）。CI 见 [ci.yml](.github/workflows/ci.yml)。

## 🗂 项目结构

```
ClipCV/
├── ClipCV/
│   ├── Models/          # SwiftData 模型
│   ├── Services/        # 剪贴板监听、搜索、OCR、快捷键、更新…
│   └── UI/              # 历史面板、设置、钉选、菜单栏
├── ClipCVTests/         # 单元测试
└── docs/                # 文档（中英文）
```

## 📄 许可证

本项目采用 [MIT License](LICENSE)。

## 🙏 鸣谢

- [Maccy](https://github.com/p0deje/Maccy) — 交互设计灵感
- [Sparkle](https://github.com/sparkle-project/Sparkle) — 软件更新框架
