import AppKit
import SwiftData
import SwiftUI

final class KeyablePanel: NSPanel {
    var suppressAutoClose = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        guard NSApp.modalWindow == nil, !suppressAutoClose else { return }
        orderOut(nil)
        NotificationCenter.default.post(name: .clipCVPanelDidClose, object: self)
    }
}

extension Notification.Name {
    static let clipCVPanelDidClose = Notification.Name("clipCVPanelDidClose")
}

enum PanelAnchor {
    case cursor, statusItem
}

@MainActor
final class HistoryPanelController {
    let panel: KeyablePanel
    weak var anchorButton: NSStatusBarButton?
    var onAnchorClick: (() -> Void)?
    var onDidHide: (() -> Void)?

    private let settings: AppSettings
    private var outsideGlobal: Any?
    private var closeObserver: NSObjectProtocol?
    private var previewLeading = false
    // Keep list X fixed when preview opens left/right.
    private var anchoredListMinX: CGFloat?
    private var lastShowAnchor: PanelAnchor = .cursor
    private var pendingItemCount: Int?
    private var resizeCoalesceTask: Task<Void, Never>?

    init(settings: AppSettings, actions: HistoryActions, container: ModelContainer) {
        self.settings = settings
        let panel = Self.makePanel()
        let hosting = NSHostingView(
            rootView: HistoryView()
                .environment(settings)
                .environment(actions)
                .modelContainer(container)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        )
        hosting.wantsLayer = true
        panel.contentView = hosting
        self.panel = panel
        PanelChrome.applyRoundedCorners(to: panel, radius: PopupStyle.panelCornerRadius)
        closeObserver = NotificationCenter.default.addObserver(
            forName: .clipCVPanelDidClose,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cleanupAfterHide() }
        }
    }

    // Keep panel chrome setup out of init so the observer wiring stays readable.
    private static func makePanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PopupStyle.defaultWidth,
                height: PopupStyle.defaultPanelHeight
            ),
            styleMask: [.nonactivatingPanel, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("wangsendi.ClipCV.history")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.backgroundColor = .clear
        panel.minSize = NSSize(width: 360, height: PopupStyle.minimumPanelHeight)
        [.closeButton, .miniaturizeButton, .zoomButton].forEach {
            panel.standardWindowButton($0)?.isHidden = true
        }
        return panel
    }

    deinit {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
    }

    func toggle(at anchor: PanelAnchor) {
        panel.isVisible ? hide() : show(at: anchor)
    }

    func show(at anchor: PanelAnchor) {
        previewLeading = false
        // Size from the real item count before the first frame: the cursor-anchored
        // origin depends on height, so a stale height would land the panel far away.
        setPanelFrame(
            NSRect(origin: panel.frame.origin, size: NSSize(width: PopupStyle.defaultWidth, height: openHeight)),
            display: false
        )
        let effective = resolvedAnchor(from: anchor)
        lastShowAnchor = effective
        position(using: effective)
        anchoredListMinX = panel.frame.minX
        PanelChrome.applyRoundedCorners(to: panel, radius: PopupStyle.panelCornerRadius)
        panel.orderFrontRegardless()
        panel.makeKey()
        if effective == .statusItem {
            anchorButton?.isHighlighted = true
        }
        installOutsideMonitors()
    }

    private var openHeight: CGFloat {
        let count = (try? AppRuntime.container.mainContext.fetchCount(
            FetchDescriptor<ClipboardItem>()
        )) ?? 0
        return max(PopupStyle.preferredHeight(itemCount: count), PopupStyle.minimumPanelHeight)
    }

    func hide() {
        // A coalesced resize firing on a hidden panel would jump it on reopen.
        resizeCoalesceTask?.cancel()
        resizeCoalesceTask = nil
        pendingItemCount = nil
        previewLeading = false
        anchoredListMinX = nil
        panel.orderOut(nil)
        cleanupAfterHide()
    }

    func hideForDrag() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeOutsideMonitors()
        anchorButton?.isHighlighted = false
    }

    func showAfterDrag() {
        guard !panel.isVisible else { return }
        show(at: lastShowAnchor)
    }

    func resizeForContent(itemCount: Int) {
        // Coalesce resize requests (Maccy pattern): several state changes in one
        // SwiftUI update would otherwise fire competing setFrames = visible jump.
        pendingItemCount = itemCount
        guard resizeCoalesceTask == nil else { return }
        resizeCoalesceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(10))
            resizeCoalesceTask = nil
            guard let count = pendingItemCount else { return }
            pendingItemCount = nil
            applyContentResize(itemCount: count)
        }
    }

    private func applyContentResize(itemCount: Int) {
        let geo = previewGeometry(in: panel.frame)
        let expanded = previewLeading || abs(panel.frame.width - (geo.listW + geo.previewW)) < 2
        let size = NSSize(
            width: expanded ? geo.listW + geo.previewW : geo.listW,
            height: PopupStyle.preferredHeight(itemCount: itemCount)
        )
        var origin = NSPoint(
            x: geo.originX(expanded: expanded, leading: previewLeading),
            y: panel.frame.origin.y + (panel.frame.height - size.height)
        )
        if let visible = (panel.screen ?? WindowGeometry.screenContaining(origin))?.visibleFrame {
            origin.y = WindowGeometry.clampY(origin.y, size: size, visible: visible)
            origin.x = geo.originX(expanded: expanded, leading: previewLeading)
        }
        anchoredListMinX = geo.listX
        let frame = NSRect(origin: origin, size: size)
        // Skip no-op setFrame to avoid nested layoutSubtreeIfNeeded warnings.
        let current = panel.frame
        guard abs(current.origin.x - frame.origin.x) > 1
            || abs(current.origin.y - frame.origin.y) > 1
            || abs(current.size.width - frame.size.width) > 1
            || abs(current.size.height - frame.size.height) > 1
        else { return }
        setPanelFrame(frame, display: true)
    }

    @discardableResult
    func setExpandedForPreview(_ expanded: Bool) -> Bool {
        let current = panel.frame
        let visible = (panel.screen ?? WindowGeometry.screenContaining(current.origin))?.visibleFrame ?? current
        let geo = previewGeometry(in: current)
        let size = NSSize(
            width: expanded ? geo.listW + geo.previewW : geo.listW,
            height: current.height
        )

        let origin: NSPoint
        guard expanded else {
            previewLeading = false
            var collapsed = NSPoint(x: geo.listX, y: current.minY)
            collapsed.y = WindowGeometry.clampY(collapsed.y, size: size, visible: visible)
            anchoredListMinX = geo.listX
            origin = collapsed
            setPanelFrame(NSRect(origin: origin, size: size), display: true)
            return false
        }

        let spaceLeft = geo.listX - visible.minX
        let spaceRight = visible.maxX - (geo.listX + geo.listW)
        let fitsLeft = spaceLeft >= geo.previewW - 0.5
        let fitsRight = spaceRight >= geo.previewW - 0.5
        previewLeading = (fitsLeft == fitsRight) ? spaceLeft > spaceRight : fitsLeft

        var expandedOrigin = NSPoint(x: geo.originX(expanded: true, leading: previewLeading), y: current.minY)
        expandedOrigin = constrainPreservingList(expandedOrigin, listMinX: geo.listX, size: size)
        anchoredListMinX = listMinX(in: NSRect(origin: expandedOrigin, size: size))
        setPanelFrame(NSRect(origin: expandedOrigin, size: size), display: true)
        return previewLeading
    }

    private struct PreviewGeometry {
        let listW: CGFloat
        let previewW: CGFloat
        let listX: CGFloat

        func originX(expanded: Bool, leading: Bool) -> CGFloat {
            expanded && leading ? listX - previewW : listX
        }
    }

    private func previewGeometry(in frame: NSRect) -> PreviewGeometry {
        PreviewGeometry(
            listW: PopupStyle.defaultWidth,
            previewW: PopupStyle.previewWidth,
            listX: anchoredListMinX ?? listMinX(in: frame)
        )
    }

    private func cleanupAfterHide() {
        removeOutsideMonitors()
        anchorButton?.isHighlighted = false
        onDidHide?()
    }

    private func setPanelFrame(_ frame: NSRect, display: Bool) {
        // Instant everywhere: animated resizes fought across show/content/preview
        // paths and read as jumping; instant is also snappiest for a utility popup.
        panel.setFrame(frame, display: display, animate: false)
        PanelChrome.applyRoundedCorners(to: panel, radius: PopupStyle.panelCornerRadius)
    }

    private func listMinX(in frame: NSRect) -> CGFloat {
        let expanded = abs(frame.width - (PopupStyle.defaultWidth + PopupStyle.previewWidth)) < 2
        return expanded && previewLeading ? frame.minX + PopupStyle.previewWidth : frame.minX
    }

    private func resolvedAnchor(from requested: PanelAnchor) -> PanelAnchor {
        settings.popupPosition == .statusItem ? .statusItem : requested
    }

    private func position(using anchor: PanelAnchor) {
        let size = panel.frame.size
        let origin: NSPoint = anchor == .statusItem
            ? originNearStatusItem(size: size)
            : originNearCursor(size: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func originNearCursor(size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = WindowGeometry.screenContaining(mouse)
        let gap = PopupStyle.cursorGap
        // Keep the pointer outside the panel so open-under-cursor doesn't hover-select a row.
        let preferred = NSPoint(x: mouse.x + gap, y: mouse.y - size.height - gap)
        let constrained = WindowGeometry.constrain(origin: preferred, size: size, to: screen)
        return clearOfCursor(constrained, size: size, mouse: mouse, screen: screen)
    }

    private func clearOfCursor(
        _ origin: NSPoint,
        size: NSSize,
        mouse: NSPoint,
        screen: NSScreen?
    ) -> NSPoint {
        let gap = PopupStyle.cursorGap
        guard NSRect(origin: origin, size: size).insetBy(dx: -1, dy: -1).contains(mouse) else {
            return origin
        }
        let visible = screen?.visibleFrame ?? NSRect(origin: origin, size: size)
        let below = NSPoint(x: origin.x, y: mouse.y - gap - size.height)
        if below.y >= visible.minY {
            return WindowGeometry.constrain(origin: below, size: size, to: screen)
        }
        let above = NSPoint(x: origin.x, y: mouse.y + gap)
        if above.y + size.height <= visible.maxY {
            return WindowGeometry.constrain(origin: above, size: size, to: screen)
        }
        let right = NSPoint(x: mouse.x + gap, y: origin.y)
        if right.x + size.width <= visible.maxX {
            return WindowGeometry.constrain(origin: right, size: size, to: screen)
        }
        return WindowGeometry.constrain(
            origin: NSPoint(x: mouse.x - gap - size.width, y: origin.y),
            size: size,
            to: screen
        )
    }

    private func originNearStatusItem(size: NSSize) -> NSPoint {
        guard let button = anchorButton, let window = button.window else {
            return originNearCursor(size: size)
        }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        return WindowGeometry.constrain(
            origin: NSPoint(x: rect.minX, y: rect.minY - size.height),
            size: size,
            to: window.screen ?? NSScreen.main
        )
    }

    private func constrainPreservingList(_ origin: NSPoint, listMinX: CGFloat, size: NSSize) -> NSPoint {
        guard let visible = (panel.screen ?? WindowGeometry.screenContaining(origin))?.visibleFrame else {
            return origin
        }
        var result = origin
        result.y = WindowGeometry.clampY(result.y, size: size, visible: visible)

        let leftX = listMinX - PopupStyle.previewWidth
        let rightX = listMinX
        let leftOK = leftX >= visible.minX - 0.5 && leftX + size.width <= visible.maxX + 0.5
        let rightOK = rightX >= visible.minX - 0.5 && rightX + size.width <= visible.maxX + 0.5

        if previewLeading, leftOK {
            result.x = leftX
        } else if !previewLeading, rightOK {
            result.x = rightX
        } else if rightOK {
            previewLeading = false
            result.x = rightX
        } else if leftOK {
            previewLeading = true
            result.x = leftX
        } else {
            result.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        }
        return result
    }

    private func installOutsideMonitors() {
        removeOutsideMonitors()
        outsideGlobal = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.panel.suppressAutoClose else { return }
                let hitsAnchor: Bool = {
                    guard let button = self.anchorButton, let window = button.window else { return false }
                    return window.convertToScreen(button.convert(button.bounds, to: nil))
                        .contains(NSEvent.mouseLocation)
                }()
                self.hide()
                if hitsAnchor { self.onAnchorClick?() }
            }
        }
    }

    private func removeOutsideMonitors() {
        guard let outsideGlobal else { return }
        NSEvent.removeMonitor(outsideGlobal)
        self.outsideGlobal = nil
    }
}
