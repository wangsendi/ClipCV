# Privacy

[Home](../README.en.md) · [中文](privacy.md)

## Storage

| Data | Location |
| --- | --- |
| History and OCR results | `~/Library/Containers/wangsendi.ClipCV/Data/Library/Application Support/ClipCV/` |
| Settings | `~/Library/Containers/wangsendi.ClipCV/Data/Library/Preferences/wangsendi.ClipCV.plist` |
| Image thumbnails | Memory only |

OCR runs locally through Apple Vision. Results are saved with the history item. No analytics or crash-reporting SDKs are included.

The app uses App Sandbox. File history stores references and persistent access bookmarks on this Mac, without copying file contents. Bookmarks do not sync through iCloud and are deleted with their history records. Access is activated when restoring files to the clipboard and released after the clipboard is replaced.

## Network access

- Software updates use GitHub to check for and download packages.
- iCloud sync is off by default. When enabled, history content and OCR results can sync to iCloud.

## Controls and deletion

Configure ignore rules by app, pasteboard type, or regex. You can also pause recording or ignore the next copy.

Clear records from the history panel or **Settings → Advanced**, or enable clear-on-quit. Uninstalling the app does not automatically remove local history or iCloud data.
