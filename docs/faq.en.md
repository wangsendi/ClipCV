# FAQ

[Home](../README.en.md) · [中文](faq.md)

## The app won't open or paste automatically

If macOS blocks the app, choose **Open Anyway** in **System Settings → Privacy & Security**. Automatic paste requires Accessibility permission for ClipCV.

## Shortcuts don't respond

Check for conflicts with other apps or input methods, then rebind the shortcut in Settings. `⌃Space` often conflicts with input switching.

## Copies aren't appearing in history

Check whether recording is paused, "Ignore next copy" is enabled, or **Settings → Ignore** filters out the app, pasteboard type, or text.

## How much space does history use?

Defaults are 200 items and 300 MB, adjustable in **Settings → Storage**. Cleanup removes the oldest unpinned items; pinned items remain. Images can be downscaled on save.

## Files from history won't paste

Newly copied files retain access on this Mac after the clipboard is overwritten or the app is relaunched. The original file must still exist and its authorization must remain valid. For older records, records synced from another device, or revoked access, copy the file again in Finder.

## How does iCloud sync work?

Sign in to iCloud, then enable sync in **Settings → Advanced**. It is off by default and changes require a relaunch. Disabling sync preserves local history and recording. Pausing recording does not disable iCloud sync.

## How do I update?

Use **Settings → General → Check Now**, or enable automatic checks. If your network blocks updates, download from [Releases](https://github.com/wangsendi/ClipCV/releases/latest).

For other questions, [open an issue](https://github.com/wangsendi/ClipCV/issues).
