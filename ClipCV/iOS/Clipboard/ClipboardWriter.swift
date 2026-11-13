import UIKit

enum ClipboardWriter {
    @discardableResult
    static func write(_ payloads: [ClipboardPayload], to pasteboard: UIPasteboard = .general) -> Bool {
        guard !payloads.isEmpty, !payloads.contains(where: { $0.type == ClipboardRules.Kind.fileURL }) else {
            return false
        }
        var item: [String: Any] = [:]
        for payload in payloads { item[payload.type] = payload.data }
        item[ClipboardRules.Kind.internalMarker] = Data([1])
        pasteboard.setItems([item])
        return true
    }
}
