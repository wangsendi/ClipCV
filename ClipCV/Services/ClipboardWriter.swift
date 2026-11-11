import AppKit

enum ClipboardWriter {
    static func write(_ payloads: [ClipboardPayload], to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let marker = NSPasteboard.PasteboardType(ClipboardRules.Kind.internalMarker)
        let files = payloads.filter { $0.type == ClipboardRules.Kind.fileURL }
        let others = payloads.filter { $0.type != ClipboardRules.Kind.fileURL }

        if files.isEmpty {
            payloads.forEach { pasteboard.setData($0.data, forType: .init($0.type)) }
        } else {
            // Preserve Finder's file references; converting through URL rewrites them as paths.
            let items = files.enumerated().map { index, file in
                let item = NSPasteboardItem()
                item.setData(file.data, forType: .fileURL)
                if index == 0 {
                    // Finder advertises files before filename text so receivers can prefer files.
                    others.forEach { item.setData($0.data, forType: .init($0.type)) }
                }
                return item
            }
            pasteboard.writeObjects(items)
        }
        pasteboard.setData(Data([1]), forType: marker)
    }
}
