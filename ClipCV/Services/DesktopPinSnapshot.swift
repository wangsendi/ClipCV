//
//  DesktopPinSnapshot.swift
//  ClipCV
//

import AppKit
import Foundation

enum DesktopPinSnapshot {
    case text(String)
    /// `data` keeps fidelity for insert; `preview` is a small bitmap for UI only.
    case image(data: Data, preview: NSImage)
    case file(name: String, path: String)

    var previewImage: NSImage? {
        if case .image(_, let preview) = self { return preview }
        return nil
    }

    static func make(from item: ClipboardItem, previewMaxSide: CGFloat = 320) -> DesktopPinSnapshot? {
        if let data = item.imagePayloadData {
            let preview = ThumbnailCache.make(from: data, maxSide: previewMaxSide)
                ?? NSImage(size: NSSize(width: 48, height: 48))
            return .image(data: data, preview: preview)
        }
        if let url = ClipboardRules.fileURLs(from: item.payloads).first {
            let name = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
            return .file(name: name.isEmpty ? url.path : name, path: url.path)
        }
        if let text = ClipboardRules.plainText(from: item.payloads)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return .text(text)
        }
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return .text(title)
    }
}
