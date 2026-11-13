import AppKit

extension ClipboardRules {
    static func sourceBundleID(from pasteboard: NSPasteboard) -> String? {
        let type = NSPasteboard.PasteboardType(Kind.source)
        return [
            pasteboard.string(forType: type),
            pasteboard.data(forType: type).flatMap { String(data: $0, encoding: .utf8) },
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
        ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    static func prepareForStorage(
        _ payloads: [ClipboardPayload],
        scalePercent: Int
    ) -> [ClipboardPayload] {
        let deduped = preferPNGOverTIFF(payloads)
        guard (1..<100).contains(scalePercent) else { return deduped }
        return deduped.map { payload in
            guard isImageType(payload.type),
                  let size = ThumbnailCache.pixelSize(of: payload.data)
            else { return payload }
            let maxSide = max(1, max(size.width, size.height) * scalePercent / 100)
            guard let png = ThumbnailCache.resizedPNGData(from: payload.data, maxSide: maxSide)
            else { return payload }
            return ClipboardPayload(type: Kind.png, data: png)
        }
    }

    static func localizedTitle(_ stored: String) -> String {
        switch stored {
        case TitleToken.image:
            return L10n.t(.categoryImage)
        case TitleToken.richText:
            return L10n.t(.richTextTitle)
        case TitleToken.generic:
            return L10n.t(.clipboardContent)
        default:
            return stored
        }
    }

    static func plainText(from contents: [ClipboardPayload]) -> String? {
        if let text = stringText(from: contents) { return text }
        if let data = contents.first(where: { $0.type == Kind.rtf })?.data,
           let text = nonEmpty(NSAttributedString(rtf: data, documentAttributes: nil)?.string) {
            return text
        }
        guard let data = contents.first(where: { $0.type == Kind.html })?.data else { return nil }
        return nonEmpty(
            NSAttributedString(
                html: data,
                options: [.characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            )?.string
        )
    }

    static func nsColor(fromHexTitle title: String) -> NSColor? {
        guard let value = parseHexRGB(from: title) else { return nil }
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
