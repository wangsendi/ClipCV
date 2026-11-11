import AppKit

enum ClipboardWriter {
    static func write(_ payloads: [ClipboardPayload]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let marker = NSPasteboard.PasteboardType(ClipboardRules.Kind.internalMarker)
        let files = payloads.filter { $0.type == ClipboardRules.Kind.fileURL }
        let others = payloads.filter { $0.type != ClipboardRules.Kind.fileURL }

        guard !files.isEmpty else {
            others.forEach { pasteboard.setData($0.data, forType: .init($0.type)) }
            pasteboard.setData(Data([1]), forType: marker)
            return
        }

        let first = NSPasteboardItem()
        others.forEach { first.setData($0.data, forType: .init($0.type)) }
        if let file = files.first { first.setData(file.data, forType: .fileURL) }
        first.setData(Data([1]), forType: marker)

        let extras = files.dropFirst().map { file -> NSPasteboardItem in
            let item = NSPasteboardItem()
            item.setData(file.data, forType: .fileURL)
            item.setData(Data([1]), forType: marker)
            return item
        }
        pasteboard.writeObjects([first] + extras)
    }
}
