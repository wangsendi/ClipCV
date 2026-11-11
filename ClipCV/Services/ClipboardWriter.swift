import AppKit

enum ClipboardWriter {
    @discardableResult
    static func write(_ payloads: [ClipboardPayload], to pasteboard: NSPasteboard = .general) -> Bool {
        let files = payloads.filter { $0.type == ClipboardRules.Kind.fileURL }
        let others = payloads.filter { $0.type != ClipboardRules.Kind.fileURL }
        let marker = NSPasteboard.PasteboardType(ClipboardRules.Kind.internalMarker)
        guard !files.isEmpty else {
            // Rich text must stay on one item to avoid duplicate pastes in some apps.
            pasteboard.clearContents()
            for payload in others {
                guard pasteboard.setData(payload.data, forType: .init(payload.type)) else { return false }
            }
            return pasteboard.setData(Data([1]), forType: marker)
        }

        let items = files.enumerated().map { index, payload in
            let item = NSPasteboardItem()
            item.setData(payload.data, forType: .fileURL)
            if index == 0 {
                // A separate text item before the files makes some receivers ignore the files.
                others.forEach { item.setData($0.data, forType: .init($0.type)) }
                item.setData(Data([1]), forType: marker)
            }
            return item
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects(items)
    }
}
