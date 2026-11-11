import AppKit
import SwiftUI

@MainActor
final class DesktopPinController {
    static let shared = DesktopPinController()

    private var panels: [UUID: DesktopPinPanel] = [:]
    private var escapeMonitor: Any?

    func pin(_ snapshot: DesktopPinSnapshot, at screenPoint: NSPoint) {
        let id = UUID()
        let size = preferredSize(for: snapshot)
        let origin = WindowGeometry.constrain(
            origin: NSPoint(x: screenPoint.x - size.width / 2, y: screenPoint.y - size.height / 2),
            size: size,
            to: WindowGeometry.screenContaining(screenPoint)
        )
        let panel = DesktopPinPanel(id: id, snapshot: snapshot) { [weak self] closedID in
            self?.panels[closedID] = nil
            self?.updateEscapeMonitor()
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        panels[id] = panel
        updateEscapeMonitor()
    }

    private func preferredSize(for snapshot: DesktopPinSnapshot) -> NSSize {
        switch snapshot {
        case .text:
            return NSSize(width: 320, height: 240)
        case .image(_, let preview):
            let maxSide: CGFloat = 320
            let imageSize = preview.size
            guard imageSize.width > 1, imageSize.height > 1 else {
                return NSSize(width: 240, height: 180)
            }
            let scale = min(maxSide / imageSize.width, maxSide / imageSize.height, 1)
            return NSSize(
                width: max(160, imageSize.width * scale + 16),
                height: max(120, imageSize.height * scale + 36)
            )
        case .file:
            return NSSize(width: 300, height: 110)
        }
    }

    private func updateEscapeMonitor() {
        if panels.isEmpty {
            if let escapeMonitor {
                NSEvent.removeMonitor(escapeMonitor)
                self.escapeMonitor = nil
            }
            return
        }
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Local monitors run on the main thread; avoid touching NSEvent across
            // concurrency boundaries (NSEvent is not Sendable in Swift 6).
            guard event.keyCode == 53 else { return event }
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let panel = NSApp.keyWindow as? DesktopPinPanel else { return false }
                panel.dismiss()
                return true
            }
            return handled ? nil : event
        }
    }
}


private final class DesktopPinPanel: NSPanel {
    private let pinID: UUID
    private let onClose: (UUID) -> Void

    init(id: UUID, snapshot: DesktopPinSnapshot, onClose: @escaping (UUID) -> Void) {
        self.pinID = id
        self.onClose = onClose
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 180),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        identifier = NSUserInterfaceItemIdentifier("wangsendi.ClipCV.desktopPin.\(id.uuidString)")
        title = snapshot.title
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        hasShadow = true
        let hosting = NSHostingView(
            rootView: DesktopPinView(snapshot: snapshot) { [weak self] in
                self?.dismiss()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        hosting.wantsLayer = true
        contentView = hosting
        PanelChrome.applyRoundedCorners(to: self, radius: 10, clearBackground: true)
    }

    override var canBecomeKey: Bool { true }

    func dismiss() {
        orderOut(nil)
        onClose(pinID)
    }

    override func cancelOperation(_ sender: Any?) { dismiss() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dismiss(); return }
        super.keyDown(with: event)
    }
}


private struct PinSelectableTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true

        let textView = PinDragTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 12)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? PinDragTextView else { return }
        if textView.string != text { textView.string = text }
    }
}

private final class PinTextInsertDragSource: NSObject, NSDraggingSource {
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}

private final class PinDragTextView: NSTextView {
    private let insertDragSource = PinTextInsertDragSource()
    private var mouseDownEvent: NSEvent?
    private var pendingSelectionDrag = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func cancelOperation(_ sender: Any?) {
        (window as? DesktopPinPanel)?.dismiss()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let sel = selectedRange()
        if event.clickCount == 1, sel.length > 0, NSLocationInRange(index, sel) {
            mouseDownEvent = event
            pendingSelectionDrag = true
            return
        }
        pendingSelectionDrag = false
        mouseDownEvent = nil
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if pendingSelectionDrag, let down = mouseDownEvent {
            let start = convert(down.locationInWindow, from: nil)
            let loc = convert(event.locationInWindow, from: nil)
            guard ClipboardDragSupport.exceededDragThreshold(from: start, to: loc) else { return }
            pendingSelectionDrag = false
            mouseDownEvent = nil
            let sel = selectedRange()
            guard sel.length > 0 else { return }
            _ = ClipboardDragSupport.beginSession(
                from: self,
                source: insertDragSource,
                snapshots: [.text((string as NSString).substring(with: sel))],
                reorderID: nil,
                event: down,
                intent: .insertContent
            )
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if pendingSelectionDrag, let down = mouseDownEvent {
            pendingSelectionDrag = false
            mouseDownEvent = nil
            super.mouseDown(with: down)
            super.mouseUp(with: event)
            return
        }
        pendingSelectionDrag = false
        mouseDownEvent = nil
        super.mouseUp(with: event)
    }
}


private struct WindowMoveHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowMoveNSView { WindowMoveNSView() }
    func updateNSView(_ nsView: WindowMoveNSView, context: Context) {}
}

private final class WindowMoveNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.performDrag(with: event)
    }
}

private struct PinContentDragHandle: NSViewRepresentable {
    let snapshot: DesktopPinSnapshot

    func makeCoordinator() -> PinContentDragCoordinator {
        PinContentDragCoordinator(snapshot: snapshot)
    }

    func makeNSView(context: Context) -> PinContentDragNSView {
        let view = PinContentDragNSView()
        view.coordinator = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: PinContentDragNSView, context: Context) {
        context.coordinator.snapshot = snapshot
        context.coordinator.view = nsView
        nsView.coordinator = context.coordinator
    }
}

@MainActor
private final class PinContentDragCoordinator: NSObject, NSDraggingSource {
    var snapshot: DesktopPinSnapshot
    weak var view: PinContentDragNSView?

    init(snapshot: DesktopPinSnapshot) {
        self.snapshot = snapshot
    }

    func beginDrag(with event: NSEvent) {
        guard let view else { return }
        _ = ClipboardDragSupport.beginSession(
            from: view,
            source: self,
            snapshots: [snapshot],
            reorderID: nil,
            event: event,
            intent: .insertContent
        )
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        ClipboardDragSupport.applyDragChrome(to: view, dimmed: true, intent: .insertContent)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        ClipboardDragSupport.applyDragChrome(to: view, dimmed: false, intent: .insertContent)
    }
}

private final class PinContentDragNSView: NSView {
    var coordinator: PinContentDragCoordinator?
    private var mouseDownEvent: NSEvent?
    private var mouseDownPoint: NSPoint?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        mouseDownEvent = event
        mouseDownPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, let down = mouseDownEvent else { return }
        let loc = convert(event.locationInWindow, from: nil)
        guard ClipboardDragSupport.exceededDragThreshold(from: start, to: loc) else { return }
        mouseDownPoint = nil
        mouseDownEvent = nil
        coordinator?.beginDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownPoint = nil
        mouseDownEvent = nil
    }
}


private struct DesktopPinView: View {
    let snapshot: DesktopPinSnapshot
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            bodyContent
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
            Text(snapshot.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .background(WindowMoveHandle())
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch snapshot {
        case .text(let text):
            PinSelectableTextView(text: text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .image(let data, let preview):
            dragOverlay {
                DesktopPinImageView(data: data, preview: preview)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .allowsHitTesting(false)
            }
        case .file(let name, let path):
            dragOverlay {
                HStack(alignment: .top, spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 36, height: 36)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                            .allowsHitTesting(false)
                        Text(path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .allowsHitTesting(false)
                        Button(L10n.t(.revealInFinder)) {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
                }
            }
        }
    }

    private func dragOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            PinContentDragHandle(snapshot: snapshot)
            content()
        }
    }
}

private struct DesktopPinImageView: View {
    let data: Data
    let preview: NSImage
    @Environment(\.displayScale) private var displayScale
    @State private var displayImage: NSImage?

    var body: some View {
        GeometryReader { geometry in
            let pixelSide = max(1, Int(ceil(max(geometry.size.width, geometry.size.height) * displayScale)))
            Image(nsImage: displayImage ?? preview)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .task(id: pixelSide) {
                    // Decode after resizing settles so full-resolution work stays off the drag path.
                    try? await Task.sleep(for: .milliseconds(80))
                    guard !Task.isCancelled else { return }
                    let image = await Task.detached(priority: .userInitiated) { [data] in
                        ThumbnailCache.make(from: data, maxSide: CGFloat(pixelSide))
                    }.value
                    guard !Task.isCancelled, let image else { return }
                    displayImage = image
                }
        }
    }
}
