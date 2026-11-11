import AppKit
import SwiftUI

struct HistoryItemDragContainer<Content: View>: NSViewRepresentable {
    /// Built on beginDrag so list rows don't keep decoded full images in memory.
    var makeSnapshots: () -> [DesktopPinSnapshot]
    var reorderID: UUID?
    var onActivate: () -> Void
    var onHover: (Bool) -> Void
    var onReorder: ((UUID) -> Void)?
    var onHidePanelForDrag: () -> Void
    var onShowPanelAfterDrag: () -> Void
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> DragCoordinator { DragCoordinator() }

    func makeNSView(context: Context) -> DragHostView {
        let host = DragHostView(rootView: content())
        context.coordinator.bind(host: host, from: self)
        host.coordinator = context.coordinator
        return host
    }

    func updateNSView(_ nsView: DragHostView, context: Context) {
        context.coordinator.bind(host: nsView, from: self)
        nsView.coordinator = context.coordinator
        nsView.setRootView(content())
    }
}

@MainActor
final class DragCoordinator: NSObject, NSDraggingSource {
    var makeSnapshots: () -> [DesktopPinSnapshot] = { [] }
    var reorderID: UUID?
    var onActivate: () -> Void = {}
    var onHover: (Bool) -> Void = { _ in }
    var onReorder: ((UUID) -> Void)?
    var onHidePanelForDrag: () -> Void = {}
    var onShowPanelAfterDrag: () -> Void = {}
    weak var host: DragHostView?
    private var activeSnapshots: [DesktopPinSnapshot] = []
    private var didDrag = false
    private var hidPanel = false

    func bind<Content: View>(host: DragHostView, from container: HistoryItemDragContainer<Content>) {
        self.host = host
        makeSnapshots = container.makeSnapshots
        reorderID = container.reorderID
        onActivate = container.onActivate
        onHover = container.onHover
        onReorder = container.onReorder
        onHidePanelForDrag = container.onHidePanelForDrag
        onShowPanelAfterDrag = container.onShowPanelAfterDrag
    }

    func beginDrag(with event: NSEvent) {
        guard let host else { return }
        let snapshots = makeSnapshots()
        guard !snapshots.isEmpty else { return }
        activeSnapshots = snapshots
        didDrag = true
        hidPanel = false
        _ = ClipboardDragSupport.beginSession(
            from: host,
            source: self,
            snapshots: snapshots,
            reorderID: reorderID,
            event: event,
            intent: .pinToDesktop
        )
    }

    func handleClickIfNeeded() {
        guard !didDrag else {
            didDrag = false
            return
        }
        onActivate()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        ClipboardDragSupport.applyDragChrome(to: host, dimmed: true, intent: .pinToDesktop)
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard !hidPanel, !ClipboardDragSupport.isOverHistoryPanel(screenPoint) else { return }
        hidPanel = true
        onHidePanelForDrag()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation _: NSDragOperation
    ) {
        ClipboardDragSupport.applyDragChrome(to: host, dimmed: false, intent: .pinToDesktop)
        defer {
            didDrag = false
            activeSnapshots = []
            if hidPanel {
                hidPanel = false
                onShowPanelAfterDrag()
            }
        }
        guard !ClipboardDragSupport.isOverClipCVWindow(screenPoint) else { return }
        activeSnapshots.enumerated().forEach { index, snapshot in
            DesktopPinController.shared.pin(
                snapshot,
                at: NSPoint(
                    x: screenPoint.x + CGFloat(index) * 24,
                    y: screenPoint.y - CGFloat(index) * 24
                )
            )
        }
    }
}

final class DragHostView: NSView {
    var coordinator: DragCoordinator?
    private let hosting: NSHostingView<AnyView>
    private var mouseDownEvent: NSEvent?
    private var mouseDownPoint: NSPoint?
    private var tracking: NSTrackingArea?

    init<V: View>(rootView: V) {
        hosting = NSHostingView(rootView: AnyView(rootView))
        super.init(frame: .zero)
        wantsLayer = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        registerForDraggedTypes([clipCVPinReorderType])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setRootView<V: View>(_ view: V) {
        hosting.rootView = AnyView(view)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        tracking = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) { coordinator?.onHover(true) }
    override func mouseExited(with event: NSEvent) { coordinator?.onHover(false) }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, let down = mouseDownEvent else { return }
        if down.modifierFlags.contains(.command) { return }
        let loc = convert(event.locationInWindow, from: nil)
        guard ClipboardDragSupport.exceededDragThreshold(from: start, to: loc) else { return }
        mouseDownPoint = nil
        mouseDownEvent = nil
        coordinator?.beginDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownPoint = nil
        mouseDownEvent = nil
        coordinator?.handleClickIfNeeded()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard coordinator?.onReorder != nil,
              sender.draggingPasteboard.availableType(from: [clipCVPinReorderType]) != nil
        else { return [] }
        return .move
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let onReorder = coordinator?.onReorder,
              let raw = sender.draggingPasteboard.string(forType: clipCVPinReorderType),
              let from = UUID(uuidString: raw)
        else { return false }
        onReorder(from)
        return true
    }
}
