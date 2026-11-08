# Development Guide

## Requirements

| Dependency | Version |
| --- | --- |
| macOS | 26+ |
| Xcode | 27+ (Swift 6 toolchain) |
| Third-party | [Sparkle 2](https://github.com/sparkle-project/Sparkle) only (resolved via SPM) |

## Building

```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
open ClipCV.xcodeproj   # press ⌘R in Xcode
```

From the command line:

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -configuration Debug build
```

> Sparkle's XCFramework is downloaded as an SPM artifact. If resolution is incomplete, delete SourcePackages under `~/Library/Developer/Xcode/DerivedData` and retry, or resolve with `-clonedSourcePackagesDirPath`.

## Testing

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV \
  -only-testing:ClipCVTests test
```

## CI

GitHub Actions workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

- Triggers: push / PR to `main`
- Runner: `xcode-27` (picks the newest installed Xcode)
- Steps: SPM cache → resolve dependencies → Debug build → unit tests → verify Sparkle embedding and Info.plist update keys

## Release process

ClipCV ships via local manual releases (like Maccy); release scripts stay out of the repo:

1. **Package & notarize**: `scripts/release.sh` (local, gitignored)
   - Release build → Developer ID signing → notarization → zip
2. **Generate appcast**: `scripts/make-appcast.sh` produces an EdDSA-signed `appcast.xml`
3. **Publish**: commit `appcast.xml` and the zip download to the `main` branch
   - SUFeedURL points at `raw.githubusercontent.com/.../main/appcast.xml`, so clients pick up the update automatically

Key safety: the EdDSA private key lives only in the local keychain and **never** enters the repo; the repo carries the public key only (`SUPublicEDKey`).

## Code layout

```
ClipCV/
├── Models/               # SwiftData models (ClipboardItem, …)
├── Services/
│   ├── ClipboardMonitor.swift    # pasteboard polling
│   ├── ClipboardRules.swift      # type detection & ignore rules
│   ├── SearchService.swift       # exact/fuzzy/regex search
│   ├── OCRService.swift          # Vision OCR
│   ├── HotkeyManager.swift       # Carbon global hotkeys
│   ├── SoftwareUpdater.swift     # Sparkle wrapper
│   ├── DesktopPinSnapshot.swift  # desktop pin floating windows
│   └── Localization.swift        # English/Chinese localization
├── UI/
│   ├── HistoryPanel.swift        # history popup panel
│   ├── HistoryView.swift         # history list
│   ├── MenuBarController.swift   # menu bar icon & menu
│   ├── DesktopPinController.swift# desktop pin windows
│   └── Settings/                 # settings window panes
└── ClipCVTests/                  # unit tests
```

## Localization

All strings live in the `zh` / `en` dictionaries in `Services/Localization.swift`. To add one:

1. Add a case to the `L10n.Key` enum
2. Provide both languages in the `zh` and `en` dictionaries
3. Reference it with `L10n.t(.yourKey)`

## Contributing

Issues and PRs are welcome. Before submitting, make sure:

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -only-testing:ClipCVTests test
```

passes cleanly.
