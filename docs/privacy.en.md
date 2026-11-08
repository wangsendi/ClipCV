# Privacy

ClipCV's design principle: **your clipboard data belongs to you alone.**

## Data storage

| Data | Location | Notes |
| --- | --- | --- |
| Clipboard history | Local SwiftData database (`~/Library/Application Support/ClipCV/`) | Stored on-device only |
| App settings | `~/Library/Preferences/` (UserDefaults) | Stored on-device only |
| OCR results | Never written to disk; shown/copied in the UI only | Computed on-device via Vision |
| Thumbnail cache | Local cache directory | Safe to delete anytime |

- No accounts, no analytics, no crash-reporting SDKs
- You control clear-on-quit, size caps, and ignore rules

## Network access

ClipCV touches the network in exactly two places:

1. **Update checks**: reads appcast metadata from `raw.githubusercontent.com` (daily by default, can be disabled)
2. **iCloud sync** (optional, off by default): syncs history across your devices via CloudKit

Beyond these, ClipCV sends nothing to any server.

## Sensitive content

- Pasteboard types from 1Password, KeeWeb, TypeIt4me, and similar password managers are ignored by default
- Configure ignore lists by app (bundle ID), pasteboard type, or regex rule
- "Ignore next copy" is handy for one-off passwords / verification codes
- "Pause recording" stops writing to history entirely

## Deleting your data

- Single item: select it in the history panel and press <kbd>⌥⌫</kbd>
- Bulk: Settings → Advanced → "Clear unpinned" / "Clear everything"
- Automatic: enable "Clear history on quit" in Settings → Advanced
- Full uninstall: delete the app, then delete `~/Library/Application Support/ClipCV/` — that removes every trace
