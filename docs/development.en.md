# Development

[Home](../README.en.md) · [中文](development.md)

Requires macOS 27+ and Xcode 27+. [Sparkle 2](https://github.com/sparkle-project/Sparkle) is resolved through Swift Package Manager.

## Build and test

```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
open ClipCV.xcodeproj
```

Press `⌘R` in Xcode, or use the command line:

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -configuration Debug build
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -only-testing:ClipCVTests test
```

## Release

1. Set Version and Build to the same value; increase both for each release.
2. Build Release locally, sign with Developer ID, notarize, and package as `ClipCV.dmg`.
3. Create a [release](https://github.com/wangsendi/ClipCV/releases) tagged `vVERSION`, upload the DMG, then publish a stable release.
4. [Update appcast](../.github/workflows/update-appcast.yml) signs the update and commits `appcast.xml` automatically.

Keep the EdDSA private key in the local keychain and the `SPARKLE_PRIVATE_KEY` Actions secret, never in Git.

After replacing a published package, run **Actions → Update appcast → Run workflow**. The appcast uses URLs tied to a specific version so signatures match the package.

## Code layout

`ClipCV/Models` contains data models, `Services` holds core logic, and `UI` contains views. Tests live in `ClipCVTests`.

Strings live in [Localization.swift](../ClipCV/Services/Localization.swift). Add each new `L10n.Key` to both language dictionaries.

See [CI](../.github/workflows/ci.yml) for automated builds and tests.
