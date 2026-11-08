# 隐私说明

ClipCV 的设计原则：**你的剪贴板数据只属于你**。

## 数据存储

| 数据 | 位置 | 说明 |
| --- | --- | --- |
| 剪贴板历史 | 本地 SwiftData 数据库（`~/Library/Application Support/ClipCV/`） | 仅本机存储 |
| 应用设置 | `~/Library/Preferences/`（UserDefaults） | 仅本机存储 |
| OCR 结果 | 不落盘，识别后仅在界面展示/复制 | Vision 框架本机运算 |
| 图片缩略图缓存 | 本机缓存目录 | 可随时清除 |

- 没有账户体系，没有用户行为分析，没有崩溃上报 SDK
- 退出清空、容量上限、类型忽略等均由你控制

## 网络访问

ClipCV 仅在以下情形访问网络：

1. **检查更新**：访问 `raw.githubusercontent.com` 读取 appcast 元数据（默认每天一次，可关闭）
2. **iCloud 同步**（可选，默认关闭）：通过 CloudKit 在你的设备间同步历史

除以上两点，ClipCV 不向任何服务器发送数据。

## 敏感内容防护

- 默认忽略 1Password、KeeWeb、TypeIt4me 等密码管理器的剪贴板类型
- 可按 App（Bundle ID）、剪贴板类型、正则规则配置忽略列表
- 「忽略下一次复制」适合临时复制密码 / 验证码
- 「暂停记录」在需要时完全停止写入历史

## 删除数据

- 单条删除：历史面板中选中后 <kbd>⌥⌫</kbd>
- 批量删除：设置 → 高级 →「清除未钉选」「清除全部」
- 退出自动清空：设置 → 高级 →「退出时清除历史」
- 彻底卸载：删除 App 后，删除 `~/Library/Application Support/ClipCV/` 即可完全移除所有数据
