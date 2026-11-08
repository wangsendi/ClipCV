# 常见问题 FAQ

## 安装

### 提示「无法验证开发者」怎么办？
ClipCV 使用 Developer ID 签名并经过公证。若仍出现提示，前往 **系统设置 → 隐私与安全性**，点「仍要打开」。或终端执行：

```bash
xattr -d com.apple.quarantine /Applications/ClipCV.app
```

### 需要哪些权限？
- **辅助功能**：全局快捷键与自动粘贴必需。首次启动会引导授权。
- 不需要「完全磁盘访问」，不读取剪贴板以外的任何数据。

## 使用

### 快捷键不起作用？
1. 确认已在系统设置中授予辅助功能权限
2. 检查快捷键是否与其他 App 冲突，可在设置中更换
3. 若使用输入法冲突（如 ⌃Space 切换输入法），请更换预览快捷键

### 如何忽略密码管理器等敏感 App？
**设置 → 忽略** 中添加应用的 Bundle ID（如 `com.agilebits.onepassword`），或使用「忽略下一次复制」。内置已默认忽略 1Password、KeeWeb 等密码管理器的剪贴板类型。

### 历史记录占用多少空间？
默认上限 300 MB / 200 条（可在 **设置 → 存储** 调整）。图片可设置保存时缩放比例进一步节省空间。

### 钉选条目如何使用？
钉选后，条目会显示单键字母（默认按 `QWEASDZXC` 顺序分配）。在历史面板中直接按对应字母即可粘贴，无需搜索。「钉到桌面」可把条目变成屏幕上的悬浮窗，支持拖拽内容到其他 App。

### 支持哪些内容类型？
文本、链接、RTF/HTML 富文本、PNG/TIFF 图片、文件路径。可在 **设置 → 存储** 按类型开关。

### iCloud 同步如何工作？
**设置 → 高级** 中开启（需 Apple ID 登录 iCloud）。历史通过 CloudKit 在你的多台 Mac 间同步，更改后需重启 App 生效。开启和关闭使用同一个本机数据库，关闭同步仍会继续记录，历史不会因切换开关而消失。默认关闭。

## 更新

### 如何更新？
ClipCV 使用 [Sparkle](https://sparkle-project.org) 自动更新（默认每天检查一次）。也可在 **设置 → 通用 → 立即检查** 手动检查。更新包经 EdDSA 签名校验，确保来源可信。

### 检查更新失败？
Appcast 托管在 GitHub（raw.githubusercontent.com）。若网络受限，可手动下载：[Releases](https://github.com/wangsendi/ClipCV-MacOs/releases)。

---

更多问题？[提交 Issue](https://github.com/wangsendi/ClipCV-MacOs/issues)。
