# FAQ

## Installation

### macOS says the developer can't be verified
ClipCV is signed with a Developer ID and notarized. If you still see the warning, open **System Settings → Privacy & Security** and click "Open Anyway". Or from the terminal:

```bash
xattr -d com.apple.quarantine /Applications/ClipCV.app
```

### What permissions does ClipCV need?
- **Accessibility**: required for global hotkeys and automatic paste. You'll be prompted on first launch.
- No Full Disk Access — ClipCV never reads anything beyond the clipboard.

## Usage

### Hotkeys don't work
1. Make sure Accessibility permission is granted in System Settings
2. Check for conflicts with other apps; you can rebind every shortcut in Settings
3. If ⌃Space conflicts with your input method switcher, change the preview hotkey

### How do I keep password managers out of the history?
Add the app's bundle ID (e.g. `com.agilebits.onepassword`) under **Settings → Ignore**, or use "Ignore next copy". Pasteboard types from 1Password, KeeWeb, and other password managers are ignored by default.

### How much space does history use?
Defaults to a 300 MB / 200-item cap (adjustable in **Settings → Storage**). You can also downscale images on save to save space.

### How does pinning work?
Pinned items get a single-key letter (assigned in `QWEASDZXC` order by default). Press that letter in the history panel to paste instantly — no search needed. "Pin to desktop" turns an item into a floating window you can drag content out of.

### Which content types are supported?
Text, links, RTF/HTML rich text, PNG/TIFF images, and file paths. Each type can be toggled in **Settings → Storage**.

### How does iCloud sync work?
Enable it in **Settings → Advanced** (requires an Apple ID signed into iCloud). History syncs across your Macs via CloudKit; a relaunch is needed after changing the setting. Off by default.

## Updates

### How do updates work?
ClipCV uses [Sparkle](https://sparkle-project.org) (checks daily by default). You can also check manually via **Settings → General → Check Now**. Updates are verified with an EdDSA signature.

### Update check fails?
The appcast is hosted on GitHub (raw.githubusercontent.com). If your network blocks it, download manually from [Releases](https://github.com/wangsendi/ClipCV-MacOs/releases).

---

More questions? [Open an issue](https://github.com/wangsendi/ClipCV-MacOs/issues).
