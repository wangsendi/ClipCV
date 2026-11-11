import Foundation

enum SearchMode: String, CaseIterable, Identifiable {
    case exact, fuzzy, regexp, mixed
    var id: Self { self }
    var title: String {
        switch self {
        case .exact: L10n.t(.searchExact)
        case .fuzzy: L10n.t(.searchFuzzy)
        case .regexp: L10n.t(.searchRegex)
        case .mixed: L10n.t(.searchMixed)
        }
    }
}

enum PopupPositionSetting: String, CaseIterable, Identifiable {
    case cursor, statusItem
    var id: Self { self }
    var title: String {
        switch self {
        case .cursor: L10n.t(.popupCursor)
        case .statusItem: L10n.t(.popupStatusItem)
        }
    }
}

enum PinPosition: String, CaseIterable, Identifiable {
    case top, bottom
    var id: Self { self }
    var title: String { self == .top ? L10n.t(.pinTop) : L10n.t(.pinBottom) }
}

enum SortMode: String, CaseIterable, Identifiable {
    case lastCopiedAt, firstCopiedAt, numberOfCopies
    var id: Self { self }
    var title: String {
        switch self {
        case .lastCopiedAt: L10n.t(.sortLastCopied)
        case .firstCopiedAt: L10n.t(.sortFirstCopied)
        case .numberOfCopies: L10n.t(.sortNumberOfCopies)
        }
    }
}

enum HighlightMatchStyle: String, CaseIterable, Identifiable {
    case bold, italic, underline, color
    var id: Self { self }
    var title: String {
        switch self {
        case .bold: L10n.t(.highlightBold)
        case .italic: L10n.t(.highlightItalic)
        case .underline: L10n.t(.highlightUnderline)
        case .color: L10n.t(.highlightColor)
        }
    }
}

enum SearchVisibility: String, CaseIterable, Identifiable {
    case always, duringSearch
    var id: Self { self }
    var title: String {
        self == .always ? L10n.t(.searchVisibilityAlways) : L10n.t(.searchVisibilityDuringSearch)
    }
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case clipcv, clipboard, paperclip, scissors
    var id: Self { self }

    /// SF Symbol name; `nil` means the custom `MenuBarIcon` asset (template).
    var systemImage: String? {
        switch self {
        case .clipcv: nil
        case .clipboard: "doc.on.clipboard"
        case .paperclip: "paperclip"
        case .scissors: "scissors"
        }
    }
}
