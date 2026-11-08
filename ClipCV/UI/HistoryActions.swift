//
//  HistoryActions.swift
//  ClipCV
//

import Foundation

enum ApplyEditResult: Equatable {
    case saved
    case pinKeyTaken
    case pinKeyInvalid
}

@MainActor
@Observable
final class HistoryActions {
    var presentationID = UUID()
    var copy: (ClipboardItem) -> Void = { _ in }
    var paste: (ClipboardItem) -> Void = { _ in }
    var pastePlain: (ClipboardItem) -> Void = { _ in }
    var delete: (ClipboardItem) -> Void = { _ in }
    var applyEdit: (ClipboardItem, String, String?, String?) -> ApplyEditResult = { _, _, _, _ in .saved }
    var copyText: (String) -> Void = { _ in }
    var recognizeOCR: (ClipboardItem) async -> String? = { _ in nil }
    var togglePin: (ClipboardItem) -> Void = { _ in }
    var reorderPin: (UUID, UUID) -> Void = { _, _ in }
    var clear: (Bool) -> Void = { _ in }
    var openSettings: () -> Void = {}
    var quit: () -> Void = {}
    var close: () -> Void = {}
    var hideForDrag: () -> Void = {}
    var showAfterDrag: () -> Void = {}
    var setSuppressAutoClose: (Bool) -> Void = { _ in }
    var resizePanelForContent: (Int) -> Void = { _ in }
    var resizePanelForPreview: (Bool) -> Void = { _ in }
    var previewLeading = false
    var cycleRequest = UUID()
}
