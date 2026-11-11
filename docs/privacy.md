# 隐私说明

[首页](../README.md) · [English](privacy.en.md)

## 数据存储

| 数据 | 位置 |
| --- | --- |
| 历史记录与 OCR 结果 | `~/Library/Application Support/ClipCV/` |
| 应用设置 | `~/Library/Preferences/wangsendi.ClipCV.plist` |
| 图片缩略图 | 仅缓存在内存中 |

OCR 通过 Apple Vision 在本机执行，识别结果保存在对应历史记录中。不含使用统计或崩溃上报 SDK。

## 网络访问

- 软件更新通过 GitHub 检查和下载安装包。
- iCloud 同步默认关闭；启用后，历史内容与 OCR 结果可同步到 iCloud。

## 控制与清理

可按应用、类型和正则设置忽略规则，也可暂停记录或忽略下一次复制。

在历史面板或 **设置 → 高级** 中清理记录，也支持退出时自动清空。卸载应用不会自动删除本机历史和 iCloud 数据。
