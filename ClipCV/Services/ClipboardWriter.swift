import AppKit

enum ClipboardWriter {
    static func write(_ payloads: [ClipboardPayload], to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let marker = NSPasteboard.PasteboardType(ClipboardRules.Kind.internalMarker)
        let files = ClipboardRules.fileURLs(from: payloads)

        if files.isEmpty {
            payloads.forEach { pasteboard.setData($0.data, forType: .init($0.type)) }
        } else {
            // Filename text can make receivers paste text instead of the copied files.
            pasteboard.writeObjects(files as [NSURL])
        }
        pasteboard.setData(Data([1]), forType: marker)
    }
}
