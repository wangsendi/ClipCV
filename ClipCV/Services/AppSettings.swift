//
//  AppSettings.swift
//  ClipCV
//

import AppKit
import Foundation

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    static let defaultIgnoredPasteboardTypes: Set<String> = [
        "Pasteboard generator type",
        "com.agilebits.onepassword",
        "com.typeit4me.clipping",
        "de.petermaurer.TransientPasteboardType",
        "net.antelle.keeweb",
    ]

    var paused = false { didSet { defaults.set(paused, forKey: Key.paused); onPausedChanged?() } }
    var ignoreNext = false { didSet { defaults.set(ignoreNext, forKey: Key.ignoreNext) } }
    var historyLimit = 200 {
        didSet {
            persistClamped(historyLimit, 1...999, key: Key.historyLimit, assign: { self.historyLimit = $0 }) {
                self.onHistoryLimitChanged?($0)
            }
        }
    }
    /// 0 = no size cap. When exceeded, oldest unpinned items are removed first.
    var historySizeLimitMB = 300 {
        didSet {
            persistClamped(
                historySizeLimitMB,
                0...10_240,
                key: Key.historySizeLimitMB,
                assign: { self.historySizeLimitMB = $0 }
            ) { _ in
                self.onHistoryLimitChanged?(self.historyLimit)
            }
        }
    }
    /// 0 or 100 = keep original; 1...99 = scale width/height to that percent on save.
    var imageStorageScalePercent = 0 {
        didSet {
            persistClamped(
                imageStorageScalePercent,
                0...100,
                key: Key.imageStorageScalePercent,
                assign: { self.imageStorageScalePercent = $0 }
            )
        }
    }
    var ignoredBundleIDs: [String] = [] { didSet { defaults.set(ignoredBundleIDs, forKey: Key.ignoredBundleIDs) } }
    var ignoreAllAppsExceptListed = false {
        didSet { defaults.set(ignoreAllAppsExceptListed, forKey: Key.ignoreAllAppsExceptListed) }
    }
    var ignoredPasteboardTypes: [String] = [] {
        didSet { defaults.set(ignoredPasteboardTypes, forKey: Key.ignoredPasteboardTypes) }
    }
    var ignoredRegexps: [String] = [] { didSet { defaults.set(ignoredRegexps, forKey: Key.ignoredRegexps) } }
    var enabledTypes: Set<String> = ClipboardRules.supportedTypes {
        didSet { defaults.set(Array(enabledTypes), forKey: Key.enabledTypes) }
    }
    var sortMode: SortMode = .lastCopiedAt { didSet { defaults.set(sortMode.rawValue, forKey: Key.sortMode) } }
    var searchMode: SearchMode = .exact { didSet { defaults.set(searchMode.rawValue, forKey: Key.searchMode) } }
    var pasteByDefault = false { didSet { defaults.set(pasteByDefault, forKey: Key.pasteByDefault) } }
    var removeFormattingByDefault = false {
        didSet { defaults.set(removeFormattingByDefault, forKey: Key.removeFormattingByDefault) }
    }
    var popupPosition: PopupPositionSetting = .cursor {
        didSet { defaults.set(popupPosition.rawValue, forKey: Key.popupPosition) }
    }
    var pinTo: PinPosition = .top { didSet { defaults.set(pinTo.rawValue, forKey: Key.pinTo) } }
    var imageMaxHeight = 40 {
        didSet {
            persistClamped(imageMaxHeight, 1...200, key: Key.imageMaxHeight, assign: { self.imageMaxHeight = $0 })
        }
    }
    var highlightMatch: HighlightMatchStyle = .bold {
        didSet { defaults.set(highlightMatch.rawValue, forKey: Key.highlightMatch) }
    }
    var showSpecialSymbols = false { didSet { defaults.set(showSpecialSymbols, forKey: Key.showSpecialSymbols) } }
    var showInStatusBar = true {
        didSet { defaults.set(showInStatusBar, forKey: Key.showInStatusBar); onStatusBarAppearanceChanged?() }
    }
    var showRecentCopyInMenuBar = false {
        didSet {
            defaults.set(showRecentCopyInMenuBar, forKey: Key.showRecentCopyInMenuBar)
            onStatusBarAppearanceChanged?()
        }
    }
    var menuIcon: MenuBarIconStyle = .clipcv {
        didSet { defaults.set(menuIcon.rawValue, forKey: Key.menuIcon); onStatusBarAppearanceChanged?() }
    }
    var showSearch = true { didSet { defaults.set(showSearch, forKey: Key.showSearch) } }
    var searchVisibility: SearchVisibility = .always {
        didSet { defaults.set(searchVisibility.rawValue, forKey: Key.searchVisibility) }
    }
    var showTitle = true { didSet { defaults.set(showTitle, forKey: Key.showTitle) } }
    var showApplicationIcons = true {
        didSet { defaults.set(showApplicationIcons, forKey: Key.showApplicationIcons) }
    }
    var showHexColorSwatch = false { didSet { defaults.set(showHexColorSwatch, forKey: Key.showHexColorSwatch) } }
    var showFooter = true { didSet { defaults.set(showFooter, forKey: Key.showFooter) } }
    var clearOnQuit = false { didSet { defaults.set(clearOnQuit, forKey: Key.clearOnQuit) } }
    var clearSystemClipboard = false {
        didSet { defaults.set(clearSystemClipboard, forKey: Key.clearSystemClipboard) }
    }
    /// Read by AppModelContainer at launch; changing requires relaunch.
    var iCloudSyncEnabled = false {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Key.iCloudSyncEnabled) }
    }
    var hotkey: Hotkey = .popupDefault {
        didSet { store(hotkey, Key.hotkeyKeyCode, Key.hotkeyModifiers); onHotkeyChanged?(hotkey) }
    }
    var pinHotkey: Hotkey = .pinDefault { didSet { store(pinHotkey, Key.pinKeyCode, Key.pinModifiers) } }
    var deleteHotkey: Hotkey = .deleteDefault {
        didSet { store(deleteHotkey, Key.deleteKeyCode, Key.deleteModifiers) }
    }
    var previewHotkey: Hotkey = .previewDefault {
        didSet { store(previewHotkey, Key.previewKeyCode, Key.previewModifiers) }
    }
    var pinKeyOrder = HotkeyFormatting.defaultPinKeyOrder {
        didSet {
            let normalized = HotkeyFormatting.normalizePinOrder(pinKeyOrder)
            if normalized != pinKeyOrder {
                pinKeyOrder = normalized.isEmpty ? HotkeyFormatting.defaultPinKeyOrder : normalized
                return
            }
            defaults.set(pinKeyOrder, forKey: Key.pinKeyOrder)
            onPinKeyOrderChanged?(pinKeyOrder)
        }
    }
    var unpinnedKeyOrder = HotkeyFormatting.defaultUnpinnedKeyOrder {
        didSet {
            let normalized = HotkeyFormatting.normalizeUnpinnedOrder(unpinnedKeyOrder)
            if normalized != unpinnedKeyOrder {
                unpinnedKeyOrder = normalized.isEmpty
                    ? HotkeyFormatting.defaultUnpinnedKeyOrder
                    : normalized
                return
            }
            defaults.set(unpinnedKeyOrder, forKey: Key.unpinnedKeyOrder)
        }
    }
    var pinnedShortcutPrefix: ShortcutModifierPrefix = .none {
        didSet { defaults.set(pinnedShortcutPrefix.rawValue, forKey: Key.pinnedShortcutPrefix) }
    }
    var unpinnedShortcutPrefix: ShortcutModifierPrefix = .command {
        didSet { defaults.set(unpinnedShortcutPrefix.rawValue, forKey: Key.unpinnedShortcutPrefix) }
    }
    var openPreviewAutomatically = true {
        didSet { defaults.set(openPreviewAutomatically, forKey: Key.openPreviewAutomatically) }
    }
    var previewDelay = 1500 {
        didSet {
            persistClamped(previewDelay, 200...100_000, key: Key.previewDelay, assign: { self.previewDelay = $0 })
        }
    }
    var appLanguage: AppLanguage = .system {
        didSet { defaults.set(appLanguage.rawValue, forKey: Key.appLanguage) }
    }
    var capturingTarget: HotkeyCaptureTarget? {
        didSet { onCaptureChanged?(capturingTarget != nil) }
    }

    var onPausedChanged: (() -> Void)?
    var onHistoryLimitChanged: ((Int) -> Void)?
    var onHotkeyChanged: ((Hotkey) -> Void)?
    var onCaptureChanged: ((Bool) -> Void)?
    var onStatusBarAppearanceChanged: (() -> Void)?
    var onPinKeyOrderChanged: ((String) -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        paused = defaults.bool(forKey: Key.paused)
        ignoreNext = defaults.bool(forKey: Key.ignoreNext)
        let storedLimit = defaults.integer(forKey: Key.historyLimit)
        historyLimit = storedLimit == 0 ? 200 : min(999, max(1, storedLimit))
        if defaults.object(forKey: Key.historySizeLimitMB) == nil {
            historySizeLimitMB = 300
        } else {
            historySizeLimitMB = min(10_240, max(0, defaults.integer(forKey: Key.historySizeLimitMB)))
        }
        imageStorageScalePercent = min(100, max(0, defaults.integer(forKey: Key.imageStorageScalePercent)))
        ignoredBundleIDs = defaults.stringArray(forKey: Key.ignoredBundleIDs) ?? []
        ignoreAllAppsExceptListed = defaults.bool(forKey: Key.ignoreAllAppsExceptListed)
        ignoredPasteboardTypes = defaults.stringArray(forKey: Key.ignoredPasteboardTypes)
            ?? Array(Self.defaultIgnoredPasteboardTypes).sorted()
        ignoredRegexps = defaults.stringArray(forKey: Key.ignoredRegexps) ?? []

        if let stored = defaults.stringArray(forKey: Key.enabledTypes), !stored.isEmpty {
            let filtered = Set(stored).intersection(ClipboardRules.supportedTypes)
            enabledTypes = filtered.isEmpty ? ClipboardRules.supportedTypes : filtered
        }

        sortMode = .init(rawValue: defaults.string(forKey: Key.sortMode) ?? "") ?? .lastCopiedAt
        searchMode = .init(rawValue: defaults.string(forKey: Key.searchMode) ?? "") ?? .exact
        pasteByDefault = defaults.bool(forKey: Key.pasteByDefault)
        removeFormattingByDefault = defaults.bool(forKey: Key.removeFormattingByDefault)
        popupPosition = .init(rawValue: defaults.string(forKey: Key.popupPosition) ?? "") ?? .cursor
        pinTo = .init(rawValue: defaults.string(forKey: Key.pinTo) ?? "") ?? .top
        let imageHeight = defaults.integer(forKey: Key.imageMaxHeight)
        imageMaxHeight = imageHeight == 0 ? 40 : min(200, max(1, imageHeight))
        highlightMatch = .init(rawValue: defaults.string(forKey: Key.highlightMatch) ?? "") ?? .bold
        showSpecialSymbols = defaults.object(forKey: Key.showSpecialSymbols) as? Bool ?? false
        showInStatusBar = defaults.object(forKey: Key.showInStatusBar) as? Bool ?? true
        showRecentCopyInMenuBar = defaults.bool(forKey: Key.showRecentCopyInMenuBar)
        menuIcon = .init(rawValue: defaults.string(forKey: Key.menuIcon) ?? "") ?? .clipcv
        showSearch = defaults.object(forKey: Key.showSearch) as? Bool ?? true
        searchVisibility = .init(rawValue: defaults.string(forKey: Key.searchVisibility) ?? "") ?? .always
        showTitle = defaults.object(forKey: Key.showTitle) as? Bool ?? true
        showApplicationIcons = defaults.object(forKey: Key.showApplicationIcons) as? Bool ?? true
        showHexColorSwatch = defaults.bool(forKey: Key.showHexColorSwatch)
        showFooter = defaults.object(forKey: Key.showFooter) as? Bool ?? true
        clearOnQuit = defaults.bool(forKey: Key.clearOnQuit)
        clearSystemClipboard = defaults.bool(forKey: Key.clearSystemClipboard)
        iCloudSyncEnabled = defaults.bool(forKey: Key.iCloudSyncEnabled)
        hotkey = loadHotkey(Key.hotkeyKeyCode, Key.hotkeyModifiers, fallback: .popupDefault)
        pinHotkey = loadHotkey(Key.pinKeyCode, Key.pinModifiers, fallback: .pinDefault)
        deleteHotkey = loadHotkey(Key.deleteKeyCode, Key.deleteModifiers, fallback: .deleteDefault)
        previewHotkey = loadHotkey(Key.previewKeyCode, Key.previewModifiers, fallback: .previewDefault)
        let storedPinOrder = defaults.string(forKey: Key.pinKeyOrder) ?? HotkeyFormatting.defaultPinKeyOrder
        let normalizedPinOrder = HotkeyFormatting.normalizePinOrder(storedPinOrder)
        pinKeyOrder = normalizedPinOrder.isEmpty ? HotkeyFormatting.defaultPinKeyOrder : normalizedPinOrder
        let storedUnpinnedOrder =
            defaults.string(forKey: Key.unpinnedKeyOrder) ?? HotkeyFormatting.defaultUnpinnedKeyOrder
        let normalizedUnpinnedOrder = HotkeyFormatting.normalizeUnpinnedOrder(storedUnpinnedOrder)
        unpinnedKeyOrder = normalizedUnpinnedOrder.isEmpty
            ? HotkeyFormatting.defaultUnpinnedKeyOrder
            : normalizedUnpinnedOrder
        pinnedShortcutPrefix =
            .init(rawValue: defaults.string(forKey: Key.pinnedShortcutPrefix) ?? "") ?? .none
        unpinnedShortcutPrefix =
            .init(rawValue: defaults.string(forKey: Key.unpinnedShortcutPrefix) ?? "") ?? .command
        openPreviewAutomatically = defaults.object(forKey: Key.openPreviewAutomatically) as? Bool ?? true
        let delay = defaults.integer(forKey: Key.previewDelay)
        previewDelay = delay == 0 ? 1500 : min(100_000, max(200, delay))
        appLanguage = .init(rawValue: defaults.string(forKey: Key.appLanguage) ?? "") ?? .system
    }

    var saveFiles: Bool {
        get { enabledTypes.contains(ClipboardRules.Kind.fileURL) }
        set { setStorageGroup([ClipboardRules.Kind.fileURL], enabled: newValue) }
    }

    var saveImages: Bool {
        get {
            enabledTypes.contains(ClipboardRules.Kind.png) || enabledTypes.contains(ClipboardRules.Kind.tiff)
        }
        set {
            setStorageGroup([ClipboardRules.Kind.png, ClipboardRules.Kind.tiff], enabled: newValue)
        }
    }

    var saveText: Bool {
        get {
            enabledTypes.contains(ClipboardRules.Kind.string)
                || enabledTypes.contains(ClipboardRules.Kind.rtf)
                || enabledTypes.contains(ClipboardRules.Kind.html)
        }
        set {
            setStorageGroup(
                [ClipboardRules.Kind.string, ClipboardRules.Kind.rtf, ClipboardRules.Kind.html],
                enabled: newValue
            )
        }
    }

    var modifierHelpText: String {
        let none = appLanguage.resolvedIsChinese ? "无修饰键" : "none"
        return L10n.format(
            .modifiersHelp,
            pasteByDefault ? "⌥" : none,
            pasteByDefault ? none : "⌥",
            "⌥⇧"
        )
    }

    func addIgnored(_ bundleID: String) {
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !ignoredBundleIDs.contains(id) else { return }
        ignoredBundleIDs.append(id)
    }

    func removeIgnored(_ bundleID: String) {
        ignoredBundleIDs.removeAll { $0 == bundleID }
    }

    func resetIgnoredPasteboardTypes() {
        ignoredPasteboardTypes = Array(Self.defaultIgnoredPasteboardTypes).sorted()
    }

    func beginCapture(_ target: HotkeyCaptureTarget) { capturingTarget = target }

    func clearHotkey(_ target: HotkeyCaptureTarget) {
        switch target {
        case .popup: hotkey = .none
        case .pin: pinHotkey = .none
        case .delete: deleteHotkey = .none
        case .preview: previewHotkey = .none
        }
        capturingTarget = nil
    }

    func capture(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        guard let capturingTarget else { return }
        if keyCode == 53 { self.capturingTarget = nil; return }
        guard !HotkeyFormatting.isModifierOnly(keyCode) else { return }
        let flags = modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .shift, .option, .control])
        if capturingTarget == .popup {
            guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control) else { return }
        }
        let value = Hotkey(keyCode: keyCode, modifiers: flags.rawValue)
        switch capturingTarget {
        case .popup: hotkey = value
        case .pin: pinHotkey = value
        case .delete: deleteHotkey = value
        case .preview: previewHotkey = value
        }
        self.capturingTarget = nil
    }

    func shouldIgnore(sourceApp bundleID: String?) -> Bool {
        guard let bundleID else { return ignoreAllAppsExceptListed }
        let listed = ignoredBundleIDs.contains(bundleID)
        return ignoreAllAppsExceptListed ? !listed : listed
    }

    func shouldIgnore(pasteboardTypes types: Set<String>) -> Bool {
        ClipboardRules.shouldIgnore(types: types) || !types.isDisjoint(with: Set(ignoredPasteboardTypes))
    }

    func shouldIgnore(title: String) -> Bool {
        ignoredRegexps.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(
                in: title,
                range: NSRange(title.startIndex..<title.endIndex, in: title)
            ) != nil
        }
    }

    private func setStorageGroup(_ types: Set<String>, enabled: Bool) {
        var next = enabledTypes
        if enabled { next.formUnion(types) } else { next.subtract(types) }
        if next.isEmpty { next.insert(ClipboardRules.Kind.string) }
        enabledTypes = next
    }

    private func persistClamped(
        _ value: Int,
        _ range: ClosedRange<Int>,
        key: String,
        assign: (Int) -> Void,
        onStore: ((Int) -> Void)? = nil
    ) {
        let clamped = min(range.upperBound, max(range.lowerBound, value))
        guard clamped == value else {
            assign(clamped)
            return
        }
        defaults.set(value, forKey: key)
        onStore?(value)
    }

    private func loadHotkey(_ keyCodeKey: String, _ modifiersKey: String, fallback: Hotkey) -> Hotkey {
        guard let keyCode = defaults.object(forKey: keyCodeKey) as? Int,
              let modifiers = defaults.object(forKey: modifiersKey) as? Int
        else { return fallback }
        return Hotkey(keyCode: UInt16(keyCode), modifiers: UInt(modifiers))
    }

    private func store(_ hotkey: Hotkey, _ keyCodeKey: String, _ modifiersKey: String) {
        defaults.set(Int(hotkey.keyCode), forKey: keyCodeKey)
        defaults.set(Int(hotkey.modifiers), forKey: modifiersKey)
    }

    static let iCloudSyncDefaultsKey = Key.iCloudSyncEnabled

    private enum Key {
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let appLanguage = "appLanguage"
        static let paused = "paused"
        static let ignoreNext = "ignoreNext"
        static let historyLimit = "historyLimit"
        static let historySizeLimitMB = "historySizeLimitMB"
        static let imageStorageScalePercent = "imageStorageScalePercent"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let ignoreAllAppsExceptListed = "ignoreAllAppsExceptListed"
        static let ignoredPasteboardTypes = "ignoredPasteboardTypes"
        static let ignoredRegexps = "ignoredRegexps"
        static let enabledTypes = "enabledTypes"
        static let sortMode = "sortMode"
        static let searchMode = "searchMode"
        static let pasteByDefault = "pasteByDefault"
        static let removeFormattingByDefault = "removeFormattingByDefault"
        static let popupPosition = "popupPosition"
        static let pinTo = "pinTo"
        static let imageMaxHeight = "imageMaxHeight"
        static let highlightMatch = "highlightMatch"
        static let showSpecialSymbols = "showSpecialSymbols"
        static let showInStatusBar = "showInStatusBar"
        static let showRecentCopyInMenuBar = "showRecentCopyInMenuBar"
        static let menuIcon = "menuIcon"
        static let showSearch = "showSearch"
        static let searchVisibility = "searchVisibility"
        static let showTitle = "showTitle"
        static let showApplicationIcons = "showApplicationIcons"
        static let showHexColorSwatch = "showHexColorSwatch"
        static let showFooter = "showFooter"
        static let clearOnQuit = "clearOnQuit"
        static let clearSystemClipboard = "clearSystemClipboard"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let pinKeyCode = "pinKeyCode"
        static let pinModifiers = "pinModifiers"
        static let deleteKeyCode = "deleteKeyCode"
        static let deleteModifiers = "deleteModifiers"
        static let previewDelay = "previewDelay"
        static let openPreviewAutomatically = "openPreviewAutomatically"
        static let previewModifiers = "previewModifiers"
        static let previewKeyCode = "previewKeyCode"
        static let pinKeyOrder = "pinKeyOrder"
        static let unpinnedKeyOrder = "unpinnedKeyOrder"
        static let pinnedShortcutPrefix = "pinnedShortcutPrefix"
        static let unpinnedShortcutPrefix = "unpinnedShortcutPrefix"
    }
}
