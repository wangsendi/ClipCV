# Development

[Home](../README.en.md) · [中文](development.md)

Requires macOS 27+ and Xcode 27+. [Sparkle 2](https://github.com/sparkle-project/Sparkle) is resolved through Swift Package Manager.

## Build and test

```bash
git clone https://github.com/wangsendi/ClipCV.git
cd ClipCV
open ClipCV.xcodeproj
```

Choose `ClipCV → My Mac` or `ClipCViOS → iPhone Simulator`, then press `⌘R`. From the command line:

```bash
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -configuration Debug build
xcodebuild -project ClipCV.xcodeproj -scheme ClipCV -only-testing:ClipCVTests test
xcodebuild -project ClipCV.xcodeproj -scheme ClipCViOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## Release

1. Set Version and Build to the same value; increase both for each release.
2. Build Release locally, sign with Developer ID, notarize, and package as `ClipCV.dmg`.
3. Create a [release](https://github.com/wangsendi/ClipCV/releases) tagged `vVERSION`, upload the DMG, then publish a stable release.
4. [Update appcast](../.github/workflows/update-appcast.yml) signs the update and commits `appcast.xml` automatically.

Keep the EdDSA private key in the local keychain and the `SPARKLE_PRIVATE_KEY` Actions secret, never in Git.

After replacing a published package, run **Actions → Update appcast → Run workflow**. The appcast uses URLs tied to a specific version so signatures match the package.

## Code layout

Shared code lives in `ClipCV/Shared`, the mobile app in `ClipCV/iOS`, and the keyboard in `ClipCV/Extensions/Keyboard`. Mac-specific files remain in the original `Models`, `Services`, and `UI` folders. See the [directory guide](architecture.md).

Mac strings live in [Localization.swift](../ClipCV/Services/Localization.swift); iOS uses `ClipCV/iOS/Localizable.xcstrings`.

The iOS launch argument `--design-preview` uses an in-memory sample history without reading or writing the system clipboard. Unit tests use isolated stores and pasteboards; UI tests use the sample history. Device validation is tracked in the [iOS TODO](ios-todo.md).

See [CI](../.github/workflows/ci.yml) for automated builds and tests.
