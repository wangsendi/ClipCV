import AppKit

let clipCVPinReorderType = NSPasteboard.PasteboardType("wangsendi.ClipCV.pin-reorder")
let clipCVDragThreshold: CGFloat = 4

private let clipCVPinOnlyType = NSPasteboard.PasteboardType("wangsendi.ClipCV.pin-only")

enum ClipboardDragSupport {
    enum Intent {
        case pinToDesktop
        case insertContent
    }

    static func beginSession(
        from view: NSView,
        source: NSDraggingSource,
        snapshots: [DesktopPinSnapshot],
        reorderID: UUID?,
        event: NSEvent,
        intent: Intent
    ) -> NSDraggingSession {
        let items = dragItems(
            snapshots: intent == .insertContent ? coalesce(snapshots) : snapshots,
            reorderID: reorderID,
            intent: intent,
            in: view
        )
        let session = view.beginDraggingSession(with: items, event: event, source: source)
        session.animatesToStartingPositionsOnCancelOrFail = intent == .insertContent
        return session
    }

    static func applyDragChrome(to view: NSView?, dimmed: Bool, intent: Intent) {
        view?.alphaValue = dimmed ? 0.4 : 1
        guard dimmed else {
            NSCursor.pop()
            return
        }
        (intent == .pinToDesktop ? NSCursor.closedHand : NSCursor.dragCopy).push()
    }

    static func isOverClipCVWindow(_ point: NSPoint) -> Bool {
        NSApp.windows.contains { window in
            guard window.isVisible, window.frame.contains(point) else { return false }
            if window is KeyablePanel { return true }
            return window.identifier?.rawValue.hasPrefix("wangsendi.ClipCV") == true
        }
    }

    static func isOverHistoryPanel(_ point: NSPoint) -> Bool {
        NSApp.windows.contains {
            $0.isVisible && $0 is KeyablePanel && $0.frame.contains(point)
        }
    }

    static func exceededDragThreshold(from start: NSPoint, to end: NSPoint) -> Bool {
        hypot(end.x - start.x, end.y - start.y) >= clipCVDragThreshold
    }

    private static func coalesce(_ snapshots: [DesktopPinSnapshot]) -> [DesktopPinSnapshot] {
        guard snapshots.count > 1 else { return snapshots }
        let texts = snapshots.compactMap { snapshot -> String? in
            if case .text(let text) = snapshot { return text }
            return nil
        }
        guard texts.count == snapshots.count else { return snapshots }
        return [.text(texts.joined(separator: "\n\n"))]
    }

    private static func dragItems(
        snapshots: [DesktopPinSnapshot],
        reorderID: UUID?,
        intent: Intent,
        in view: NSView
    ) -> [NSDraggingItem] {
        snapshots.enumerated().map { index, snapshot in
            let writer = ClipboardPasteboardWriter(
                snapshot: snapshot,
                reorderID: index == 0 ? reorderID : nil,
                intent: intent
            )
            let item = NSDraggingItem(pasteboardWriter: writer)
            var (preview, frame) = DragGhost.make(for: snapshot, in: view, intent: intent)
            frame.origin.x += CGFloat(index) * 12
            frame.origin.y -= CGFloat(index) * 12
            item.setDraggingFrame(frame, contents: preview)
            return item
        }
    }
}

final class ClipboardPasteboardWriter: NSObject, NSPasteboardWriting {
    let snapshot: DesktopPinSnapshot
    let reorderID: UUID?
    let intent: ClipboardDragSupport.Intent

    init(snapshot: DesktopPinSnapshot, reorderID: UUID?, intent: ClipboardDragSupport.Intent) {
        self.snapshot = snapshot
        self.reorderID = reorderID
        self.intent = intent
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types: [NSPasteboard.PasteboardType] = []
        if reorderID != nil { types.append(clipCVPinReorderType) }
        switch intent {
        case .pinToDesktop:
            types.append(clipCVPinOnlyType)
        case .insertContent:
            switch snapshot {
            case .text: types.append(.string)
            case .image: types.append(contentsOf: [.tiff, .png])
            case .file: types.append(.fileURL)
            }
        }
        return types
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == clipCVPinReorderType { return reorderID?.uuidString }
        if type == clipCVPinOnlyType { return "1" }
        guard intent == .insertContent else { return nil }
        switch snapshot {
        case .text(let text) where type == .string:
            return text
        case .image(let data, _) where type == .tiff:
            return NSImage(data: data)?.tiffRepresentation
        case .image(let data, _) where type == .png:
            if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return data }
            guard let image = NSImage(data: data),
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff)
            else { return nil }
            return rep.representation(using: .png, properties: [:])
        case .file(_, let path) where type == .fileURL:
            return URL(fileURLWithPath: path).absoluteString
        default:
            return nil
        }
    }
}

enum DragGhost {
    static func make(
        for snapshot: DesktopPinSnapshot,
        in view: NSView,
        intent: ClipboardDragSupport.Intent
    ) -> (NSImage, NSRect) {
        let preview: NSImage = switch snapshot {
        case .image(_, let preview): imageGhost(preview)
        case .text(let text): textGhost(text)
        case .file(let name, let path):
            fileGhost(name: name, icon: NSWorkspace.shared.icon(forFile: path))
        }
        let tip: NSPoint = switch intent {
        case .pinToDesktop: NSPoint(x: -8, y: -8)
        case .insertContent: NSPoint(x: 14, y: -8)
        }
        let size = preview.size
        let mouseInWindow = view.window?.mouseLocationOutsideOfEventStream ?? .zero
        let mouse = view.convert(mouseInWindow, from: nil)
        let frame = NSRect(
            x: mouse.x + tip.x,
            y: mouse.y - size.height + tip.y,
            width: size.width,
            height: size.height
        )
        return (preview, frame)
    }

    private static func imageGhost(_ image: NSImage) -> NSImage {
        let maxSide: CGFloat = 120
        let src = image.size
        let scale = min(maxSide / max(src.width, 1), maxSide / max(src.height, 1), 1)
        let contentW = max(48, src.width * scale)
        let contentH = max(48, src.height * scale)
        return card(width: contentW + 12, height: contentH + 12, opacity: 0.88) { rect in
            let draw = rect.insetBy(dx: 6, dy: 6)
            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(roundedRect: draw, xRadius: 6, yRadius: 6).addClip()
            image.draw(in: draw, from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }

    private static func textGhost(_ text: String) -> NSImage {
        let line = ClipboardRules.collapsedTitle(from: text, limit: 80) ?? text
        return card(width: 200, height: 36, opacity: 0.82) { rect in
            NSColor.controlAccentColor.withAlphaComponent(0.92).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
            (line as NSString).draw(
                with: rect.insetBy(dx: 10, dy: 8),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: attrs
            )
        }
    }

    private static func fileGhost(name: String, icon: NSImage) -> NSImage {
        card(width: 200, height: 44, opacity: 0.88) { rect in
            icon.draw(in: NSRect(x: 8, y: 8, width: 28, height: 28))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
            (name as NSString).draw(
                with: NSRect(x: 44, y: 12, width: rect.width - 52, height: 20),
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: attrs
            )
        }
    }

    private static func card(
        width: CGFloat,
        height: CGFloat,
        opacity: CGFloat,
        paint: (NSRect) -> Void
    ) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.black.withAlphaComponent(0.2 * opacity).setFill()
        NSBezierPath(roundedRect: rect.offsetBy(dx: 2, dy: -2), xRadius: 8, yRadius: 8).fill()
        NSColor.windowBackgroundColor.withAlphaComponent(opacity).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        paint(rect)
        NSColor.separatorColor.withAlphaComponent(opacity).setStroke()
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()
        image.unlockFocus()
        return image
    }
}
