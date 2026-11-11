import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    var id: Self { self }

    var title: String {
        switch self {
        case .system: L10n.t(.languageSystem)
        case .chinese: "中文"
        case .english: "English"
        }
    }

    var resolvedIsChinese: Bool {
        switch self {
        case .chinese:
            return true
        case .english:
            return false
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("zh")
        }
    }
}

enum L10n {
    enum Key: String {
        case language
        case languageSystem
        case tabGeneral, tabHotkeys, tabAppearance, tabStorage, tabIgnore, tabAdvanced
        case launchAtLogin, launchNeedsApproval
        case hotkeys, open, pin, delete, preview
        case openHelp, pinHelp, deleteHelp, previewHelp
        case openLabel, pinLabel, deleteLabel, previewLabel, searchLabel
        case notificationsAndSounds, openPreviewAutomatically, previewDelay
        case checkForUpdates, checkNow, contactDeveloperTitle, contactDeveloperMessage
        case behavior, pasteAutomatically, pasteWithoutFormatting
        case modifiersHelp
        case historyShortcuts, shortcutPrefixNone
        case unpinnedKeyOrder, unpinnedKeyOrderHelp
        case accessibility, authorized, unauthorized, requestPermission, systemSettings
        case accessibilityFooter
        case popupAt, pinTo, imageHeightLabel, highlightMatches
        case showSpecialSymbols, showMenuIcon, showRecentCopyInMenuBar
        case showSearchField, showTitleBeforeSearch, showApplicationIcons
        case showHexColorSwatch, showFooter, footerHiddenWarning
        case save, files, images, text, saveDescription
        case capacity, sortBy, currentCount, currentSize, capacityItems
        case historySizeLimit, historySizeLimitHelp, historySizeUnlimited
        case imageStorageScale, imageStorageScaleHelp, imageStorageScaleOff
        case ignoreApps, ignorePasteboardTypes, ignoreRegexps
        case ignoreAllAppsExceptListed, ignoredAppsDescription
        case ignoredPasteboardTypesDescription, ignoredRegexpsDescription
        case reset, add
        case pause
        case clearHistoryOnQuit, clearSystemClipboard
        case clearUnpinnedNow, clearEverythingNow, clearHelp
        case clearUnpinnedConfirm, clearEverythingConfirm
        case iCloud, iCloudSync, iCloudUnavailable
        case iCloudRestartTitle, iCloudRestartMessage, iCloudRestartNow, iCloudRestartLater
        case iCloudPendingRestart
        case searchExact, searchFuzzy, searchRegex, searchMixed
        case popupCursor, popupStatusItem
        case pinTop, pinBottom
        case sortLastCopied, sortFirstCopied, sortNumberOfCopies
        case highlightBold, highlightItalic, highlightUnderline, highlightColor
        case searchVisibilityAlways, searchVisibilityDuringSearch
        case unpin, pinToDesktop, pinToDesktopSession, revealInFinder, dragToInsertHint, selectThenDragHint, clear, settings
        case editItem, alias, aliasPlaceholder, content, contentNotEditable, cancel, done, pinKeyLabel, pinKeyTaken, pinKeyInvalid, copyOCR, recognizeOCR
        case searchPlaceholder, noHistory, noMatches
        case needsAccessibility, accessibilityCopied, accessibilityCopiedPlain, fileAccessHint, ok
        case showHistory, resumeRecording, pauseRecording, ignoreNextCopy
        case clearUnpinned, clearEverything, quitApp
        case ignoreNextTooltip, pausedTooltip
        case capturingHotkey
        case ocrAvailable, previewEmpty, copiesCount
        case previewApp, previewDimensions, previewFileSize, previewFirstCopied, previewLastCopied
        case previewRaw, previewView, previewRendering
        case categoryAll, categoryText, categoryImage, categoryLink
        case categoryFile, categoryColor, categoryPinned
        case richTextTitle, clipboardContent
        case filterByApp
        case totalCountHelp
        case pinKeyOrder
        case pinnedKeyOrderHelp
    }

    static func t(_ key: Key, language: AppLanguage? = nil) -> String {
        let chinese = (language ?? AppSettings.shared.appLanguage).resolvedIsChinese
        return chinese ? zh[key] ?? key.rawValue : en[key] ?? key.rawValue
    }

    static func format(_ key: Key, _ args: CVarArg..., language: AppLanguage? = nil) -> String {
        String(format: t(key, language: language), arguments: args)
    }

    private static let zh: [Key: String] = [
        .language: "语言",
        .languageSystem: "跟随系统",
        .tabGeneral: "通用",
        .tabHotkeys: "快捷键",
        .tabAppearance: "外观",
        .tabStorage: "存储",
        .tabIgnore: "忽略",
        .tabAdvanced: "高级",
        .launchAtLogin: "登录时启动",
        .launchNeedsApproval: "登录项需要在系统设置中批准。",
        .hotkeys: "全局快捷键",
        .historyShortcuts: "历史列表快捷键",
        .shortcutPrefixNone: "无",
        .unpinnedKeyOrder: "非固定顺序：",
        .unpinnedKeyOrderHelp: "左侧选择前缀，右侧设置按键顺序（默认 ⌘ + 1234567890）。",
        .pinnedKeyOrderHelp: "左侧选择前缀，右侧设置字母顺序（默认无前缀 + QWEASDZXC）。",
        .open: "打开",
        .pin: "置顶",
        .delete: "删除",
        .openHelp: "用于打开历史的全局快捷键。默认：⇧⌘C。",
        .pinHelp: "置顶/取消置顶当前项。默认：⌥P。",
        .deleteHelp: "删除当前项。默认：⌥⌫。",
        .behavior: "行为",
        .pasteAutomatically: "自动粘贴",
        .pasteWithoutFormatting: "纯文本粘贴",
        .modifiersHelp: "选择项目时的行为：\n• %@ → 复制\n• %@ → 复制并粘贴\n• %@ → 复制并以纯文本粘贴",
        .accessibility: "辅助功能",
        .authorized: "已授权",
        .unauthorized: "未授权",
        .requestPermission: "请求权限",
        .systemSettings: "系统设置",
        .accessibilityFooter: "自动粘贴需要辅助功能权限。未授权时仍会把内容复制到剪贴板。",
        .popupAt: "弹窗位置",
        .pinTo: "置顶到",
        .imageHeightLabel: "图片高度：",
        .highlightMatches: "高亮匹配",
        .showSpecialSymbols: "显示特殊符号",
        .showMenuIcon: "显示菜单栏图标",
        .showRecentCopyInMenuBar: "在菜单栏图标旁显示剪贴板内容",
        .showSearchField: "显示搜索框",
        .showTitleBeforeSearch: "在搜索框前显示应用名",
        .showApplicationIcons: "显示应用程序图标",
        .showHexColorSwatch: "显示十六进制颜色色块",
        .showFooter: "显示底部菜单",
        .footerHiddenWarning: "隐藏底部菜单时仍可按 ⌘, 打开偏好设置。",
        .save: "保存",
        .files: "文件",
        .images: "图像",
        .text: "文本",
        .saveDescription: "设置何种类型的内容会被保存。",
        .capacity: "容量",
        .sortBy: "排序方式",
        .currentCount: "当前 %d 条",
        .currentSize: "占用 %@",
        .historySizeLimit: "大小上限：",
        .historySizeLimitHelp: "单位 MB，0 表示不限制。超出后从最旧的未固定项开始删除；固定项保留。可与条数上限同时生效。新安装默认 300 MB。",
        .historySizeUnlimited: "不限制",
        .imageStorageScale: "图片压缩率：",
        .imageStorageScaleHelp: "填写百分比，如 50。0 或 100 表示不压缩。",
        .imageStorageScaleOff: "不压缩",
        .capacityItems: "条",
        .ignoreApps: "忽略应用",
        .ignorePasteboardTypes: "忽略剪贴板类型",
        .ignoreRegexps: "正则表达式",
        .ignoreAllAppsExceptListed: "忽略列表之外的所有应用程序",
        .ignoredAppsDescription: "忽略来自特定应用的内容。此选项并非总是有效，最好同时使用忽略剪贴板类型。",
        .ignoredPasteboardTypesDescription: "忽略特定剪贴板内容类型。默认提供了一些已知类型，可删除或自行添加。",
        .ignoredRegexpsDescription: "匹配这些正则的复制内容将被忽略。",
        .reset: "重置",
        .add: "添加",
        .pause: "暂停",
        .clearHistoryOnQuit: "退出时清除历史记录",
        .clearSystemClipboard: "同时清除系统剪贴板",
        .clearUnpinnedNow: "立即清空未固定",
        .clearEverythingNow: "立即清空全部",
        .clearHelp: "清空未固定：⌥⌘⌫；清空全部：⇧⌥⌘⌫。固定项不会被「清空未固定」删除。",
        .clearUnpinnedConfirm: "删除所有未固定的历史记录？固定项会保留。",
        .clearEverythingConfirm: "删除全部历史记录（含固定项）？此操作无法撤销。",
        .iCloud: "iCloud",
        .iCloudSync: "通过 iCloud 同步历史",
        .iCloudUnavailable: "iCloud 不可用，请检查系统账户设置。",
        .iCloudRestartTitle: "需要重启",
        .iCloudRestartMessage: "重启后应用 iCloud 设置。",
        .iCloudRestartNow: "立即重启",
        .iCloudRestartLater: "稍后",
        .iCloudPendingRestart: "重启后生效",
        .searchExact: "精确",
        .searchFuzzy: "模糊",
        .searchRegex: "正则表达式",
        .searchMixed: "混合",
        .popupCursor: "光标",
        .popupStatusItem: "菜单栏图标",
        .pinTop: "顶部",
        .pinBottom: "底部",
        .sortLastCopied: "上次复制时间",
        .sortFirstCopied: "首次复制时间",
        .sortNumberOfCopies: "复制次数",
        .highlightBold: "粗体",
        .highlightItalic: "斜体",
        .highlightUnderline: "下划线",
        .highlightColor: "颜色",
        .searchVisibilityAlways: "始终",
        .searchVisibilityDuringSearch: "在搜索过程中",
        .unpin: "取消固定",
        .pinToDesktop: "钉到桌面",
        .pinToDesktopSession: "仅当前会话，重启后消失",
        .revealInFinder: "在 Finder 中显示",
        .dragToInsertHint: "拖内容可插入其他 App",
        .selectThenDragHint: "选中后可拖出插入 · ⌘C 复制",
        .editItem: "编辑",
        .alias: "别名",
        .aliasPlaceholder: "列表显示名（可选）",
        .content: "内容",
        .contentNotEditable: "此项内容不是可编辑文本",
        .cancel: "取消",
        .done: "完成",
        .pinKeyLabel: "快捷键",
        .pinKeyTaken: "该快捷键已被占用",
        .pinKeyInvalid: "仅支持单个字母或 [];'./-=\\",
        .copyOCR: "复制识别文字",
        .recognizeOCR: "识别文字",
        .clear: "清空",
        .settings: "设置…",
        .searchPlaceholder: "搜索",
        .noHistory: "暂无剪贴板记录",
        .noMatches: "没有匹配结果",
        .needsAccessibility: "需要辅助功能权限",
        .accessibilityCopied: "内容已复制到剪贴板。若要自动粘贴到当前应用，请允许 ClipCV 使用辅助功能。",
        .accessibilityCopiedPlain: "纯文本已复制到剪贴板。若要自动粘贴到当前应用，请允许 ClipCV 使用辅助功能。",
        .fileAccessHint: "请在“系统设置 → 隐私与安全性 → 文件与文件夹”中允许 ClipCV 访问文件所在目录，然后重试。",
        .ok: "好",
        .showHistory: "显示历史",
        .resumeRecording: "继续记录",
        .pauseRecording: "暂停记录",
        .ignoreNextCopy: "忽略下一次复制",
        .clearUnpinned: "清空未固定",
        .clearEverything: "清空全部",
        .quitApp: "退出 ClipCV",
        .ignoreNextTooltip: "将忽略下一次复制",
        .pausedTooltip: "记录已暂停。⌥ 点击继续",
        .capturingHotkey: "请按下快捷键…",
        .preview: "预览",
        .previewHelp: "显示带附加信息的预览。默认：⌃Space。",
        .openLabel: "打开：",
        .pinLabel: "置顶：",
        .deleteLabel: "删除：",
        .previewLabel: "预览：",
        .searchLabel: "搜索：",
        .notificationsAndSounds: "通知和声音",
        .openPreviewAutomatically: "自动打开预览",
        .previewDelay: "预览延迟：",
        .checkForUpdates: "自动检查更新",
        .checkNow: "检查更新",
        .contactDeveloperTitle: "无法检查更新",
        .contactDeveloperMessage: "当前版本未启用自动更新，请联系开发者。",
        .ocrAvailable: "已识别图片文字，可用于搜索",
        .previewEmpty: "无可预览内容",
        .copiesCount: "复制次数",
        .previewApp: "应用",
        .previewDimensions: "尺寸",
        .previewFileSize: "文件大小",
        .previewFirstCopied: "首次复制时间",
        .previewLastCopied: "上次复制时间",
        .previewRaw: "raw",
        .previewView: "view",
        .previewRendering: "渲染中…",
        .categoryAll: "全部",
        .categoryText: "文本",
        .categoryImage: "图片",
        .richTextTitle: "富文本",
        .clipboardContent: "剪贴板内容",
        .categoryLink: "链接",
        .categoryFile: "文件",
        .categoryColor: "颜色",
        .categoryPinned: "固定",
        .filterByApp: "来自 %@",
        .totalCountHelp: "历史总条数",
        .pinKeyOrder: "固定顺序：",
    ]

    private static let en: [Key: String] = [
        .language: "Language",
        .languageSystem: "System",
        .tabGeneral: "General",
        .tabHotkeys: "Hotkeys",
        .tabAppearance: "Appearance",
        .tabStorage: "Storage",
        .tabIgnore: "Ignore",
        .tabAdvanced: "Advanced",
        .launchAtLogin: "Launch at login",
        .launchNeedsApproval: "Login item requires approval in System Settings.",
        .hotkeys: "Global Hotkeys",
        .historyShortcuts: "History Shortcuts",
        .shortcutPrefixNone: "None",
        .unpinnedKeyOrder: "Unpinned order:",
        .unpinnedKeyOrderHelp: "Choose a prefix on the left; edit keys on the right (default ⌘ + 1234567890).",
        .pinnedKeyOrderHelp: "Choose a prefix on the left; edit letters on the right (default none + QWEASDZXC).",
        .open: "Open",
        .pin: "Pin",
        .delete: "Delete",
        .openHelp: "Global shortcut to open history. Default: ⇧⌘C.",
        .pinHelp: "Pin or unpin the selected item. Default: ⌥P.",
        .deleteHelp: "Delete the selected item. Default: ⌥⌫.",
        .behavior: "Behavior",
        .pasteAutomatically: "Paste automatically",
        .pasteWithoutFormatting: "Paste without formatting",
        .modifiersHelp: "Selection modifiers:\n• %@ → copy\n• %@ → copy and paste\n• %@ → copy and paste as plain text",
        .accessibility: "Accessibility",
        .authorized: "Authorized",
        .unauthorized: "Not authorized",
        .requestPermission: "Request Access",
        .systemSettings: "System Settings",
        .accessibilityFooter: "Automatic paste requires Accessibility access. Without it, ClipCV still copies to the clipboard.",
        .popupAt: "Popup at",
        .pinTo: "Pin to",
        .imageHeightLabel: "Image height:",
        .highlightMatches: "Highlight matches",
        .showSpecialSymbols: "Show special symbols",
        .showMenuIcon: "Show menu bar icon",
        .showRecentCopyInMenuBar: "Show recent copy next to menu icon",
        .showSearchField: "Show search field",
        .showTitleBeforeSearch: "Show title before search field",
        .showApplicationIcons: "Show application icons",
        .showHexColorSwatch: "Show hex color swatch",
        .showFooter: "Show footer",
        .footerHiddenWarning: "When the footer is hidden, press ⌘, to open Preferences.",
        .save: "Save",
        .files: "Files",
        .images: "Images",
        .text: "Text",
        .saveDescription: "Choose which content types are saved.",
        .capacity: "Capacity",
        .sortBy: "Sort by",
        .currentCount: "%d items",
        .currentSize: "%@ used",
        .historySizeLimit: "Size limit:",
        .historySizeLimitHelp: "In MB; 0 means unlimited. When over the limit, oldest unpinned items are removed first. Pins are kept. Works together with the item-count limit. Fresh installs default to 300 MB.",
        .historySizeUnlimited: "Unlimited",
        .imageStorageScale: "Image compression:",
        .imageStorageScaleHelp: "Enter a percent, e.g. 50. 0 or 100 means no compression.",
        .imageStorageScaleOff: "None",
        .capacityItems: "items",
        .ignoreApps: "Applications",
        .ignorePasteboardTypes: "Pasteboard Types",
        .ignoreRegexps: "Regular Expressions",
        .ignoreAllAppsExceptListed: "Ignore all apps except listed",
        .ignoredAppsDescription: "Ignore copies from specific apps. This is not always reliable; prefer ignoring pasteboard types.",
        .ignoredPasteboardTypesDescription: "Ignore specific pasteboard types. Defaults include known app types; add or remove as needed.",
        .ignoredRegexpsDescription: "Copies matching these regular expressions are ignored.",
        .reset: "Reset",
        .add: "Add",
        .pause: "Pause",
        .clearHistoryOnQuit: "Clear history on quit",
        .clearSystemClipboard: "Also clear system clipboard",
        .clearUnpinnedNow: "Clear Unpinned Now",
        .clearEverythingNow: "Clear Everything Now",
        .clearHelp: "Clear unpinned: ⌥⌘⌫. Clear all: ⇧⌥⌘⌫. Pins are kept when clearing unpinned.",
        .clearUnpinnedConfirm: "Delete all unpinned history items? Pinned items stay.",
        .clearEverythingConfirm: "Delete all history including pins? This can’t be undone.",
        .iCloud: "iCloud",
        .iCloudSync: "Sync history via iCloud",
        .iCloudUnavailable: "iCloud is unavailable. Check your account in System Settings.",
        .iCloudRestartTitle: "Restart required",
        .iCloudRestartMessage: "Restart to apply iCloud settings.",
        .iCloudRestartNow: "Restart Now",
        .iCloudRestartLater: "Later",
        .iCloudPendingRestart: "Restart to apply",
        .searchExact: "Exact",
        .searchFuzzy: "Fuzzy",
        .searchRegex: "Regex",
        .searchMixed: "Mixed",
        .popupCursor: "Cursor",
        .popupStatusItem: "Menu bar icon",
        .pinTop: "Top",
        .pinBottom: "Bottom",
        .sortLastCopied: "Last copied at",
        .sortFirstCopied: "First copied at",
        .sortNumberOfCopies: "Number of copies",
        .highlightBold: "Bold",
        .highlightItalic: "Italic",
        .highlightUnderline: "Underline",
        .highlightColor: "Color",
        .searchVisibilityAlways: "Always",
        .searchVisibilityDuringSearch: "During search",
        .unpin: "Unpin",
        .pinToDesktop: "Pin to Desktop",
        .pinToDesktopSession: "This session only — gone after quit",
        .revealInFinder: "Reveal in Finder",
        .dragToInsertHint: "Drag content to insert",
        .selectThenDragHint: "Select, then drag to insert · ⌘C to copy",
        .editItem: "Edit",
        .alias: "Alias",
        .aliasPlaceholder: "List title (optional)",
        .content: "Content",
        .contentNotEditable: "This item’s content isn’t editable text",
        .cancel: "Cancel",
        .done: "Done",
        .pinKeyLabel: "Key",
        .pinKeyTaken: "That shortcut is already in use",
        .pinKeyInvalid: "Use one letter or [];'./-=\\",
        .copyOCR: "Copy recognized text",
        .recognizeOCR: "Recognize text",
        .clear: "Clear",
        .settings: "Preferences…",
        .searchPlaceholder: "Search",
        .noHistory: "No clipboard history yet",
        .noMatches: "No matches",
        .needsAccessibility: "Accessibility Access Required",
        .accessibilityCopied: "Content was copied to the clipboard. Allow ClipCV in Accessibility to paste automatically.",
        .accessibilityCopiedPlain: "Plain text was copied to the clipboard. Allow ClipCV in Accessibility to paste automatically.",
        .fileAccessHint: "Allow ClipCV to access the file's folder in System Settings → Privacy & Security → Files & Folders, then try again.",
        .ok: "OK",
        .showHistory: "Show History",
        .resumeRecording: "Resume Recording",
        .pauseRecording: "Pause Recording",
        .ignoreNextCopy: "Ignore Next Copy",
        .clearUnpinned: "Clear Unpinned",
        .clearEverything: "Clear All",
        .quitApp: "Quit ClipCV",
        .ignoreNextTooltip: "The next copy will be ignored",
        .pausedTooltip: "Recording paused. ⌥-click to resume",
        .capturingHotkey: "Press shortcut…",
        .preview: "Preview",
        .previewHelp: "Show a preview with extra details. Default: ⌃Space.",
        .openLabel: "Open:",
        .pinLabel: "Pin:",
        .deleteLabel: "Delete:",
        .previewLabel: "Preview:",
        .searchLabel: "Search:",
        .notificationsAndSounds: "Notifications and Sounds",
        .openPreviewAutomatically: "Open preview automatically",
        .previewDelay: "Preview delay:",
        .checkForUpdates: "Check for updates automatically",
        .checkNow: "Check Now",
        .contactDeveloperTitle: "Updates Unavailable",
        .contactDeveloperMessage: "Automatic updates are not enabled in this build. Please contact the developer.",
        .ocrAvailable: "Image text recognized and searchable",
        .previewEmpty: "Nothing to preview",
        .copiesCount: "Copies",
        .previewApp: "Application",
        .previewDimensions: "Dimensions",
        .previewFileSize: "File size",
        .previewFirstCopied: "First copied",
        .previewLastCopied: "Last copied",
        .previewRaw: "raw",
        .previewView: "view",
        .previewRendering: "Rendering…",
        .categoryAll: "All",
        .categoryText: "Text",
        .categoryImage: "Image",
        .richTextTitle: "Rich Text",
        .clipboardContent: "Clipboard Content",
        .categoryLink: "Link",
        .categoryFile: "File",
        .categoryColor: "Color",
        .categoryPinned: "Pinned",
        .filterByApp: "From %@",
        .totalCountHelp: "Total history items",
        .pinKeyOrder: "Pinned order:",
    ]
}
