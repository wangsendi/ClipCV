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

1. Set Version in Xcode. Build follows Version and must increase with every release.
2. Build Release locally, sign with Developer ID, notarize, and package as `ClipCV.dmg`.
3. Create a matching release (for example, `v1.0.2`) in [ClipCV Releases](https://github.com/wangsendi/ClipCV/releases), upload `ClipCV.dmg`, then click Publish release.
4. [Update appcast](../.github/workflows/update-appcast.yml) reads the version and system requirements from the package, signs it with EdDSA, validates the feed, and commits `appcast.xml` automatically.

The app uses `https://raw.githubusercontent.com/wangsendi/ClipCV/main/appcast.xml` for updates. Users switching feeds must manually install a newly built package once; subsequent releases are detected automatically.

Use `https://github.com/wangsendi/ClipCV/releases/latest/download/ClipCV.dmg` for a general download link. The appcast uses a URL tied to a specific version so cached signatures match the package. After replacing an asset in an already published release, run Actions → Update appcast → Run workflow to refresh the feed.

The EdDSA private key is stored in the local keychain and the repository's `SPARKLE_PRIVATE_KEY` Actions secret, never in Git. The app contains only the public key (`SUPublicEDKey`).

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
