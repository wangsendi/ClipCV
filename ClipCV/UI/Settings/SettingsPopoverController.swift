//
//  SettingsPopoverController.swift
//  ClipCV
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class SettingsPopoverController {
    private let panel: NSPanel
    private var outsideGlobal: Any?
    private weak var anchorButton: NSStatusBarButton?
    var onDidClose: (() -> Void)?

    init(settings: AppSettings, container: ModelContainer) {
        let size = SettingsMetrics.popoverSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("wangsendi.ClipCV.settings")
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false

        let hosting = NSHostingView(
            rootView: SettingsRootView()
                .environment(settings)
                .modelContainer(container)
                .ignoresSafeArea()
        )
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        self.panel = panel
        PanelChrome.applyRoundedCorners(
            to: panel,
            radius: PopupStyle.panelCornerRadius + 2,
            clearBackground: true
        )
    }

    var isShown: Bool { panel.isVisible }

    func show(relativeTo button: NSStatusBarButton) {
        anchorButton = button
        guard let window = button.window else { return }
        let size = SettingsMetrics.popoverSize
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let preferred = NSPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 4)
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame
        let origin = visible.map {
            NSPoint(
                x: min(max(preferred.x, $0.minX + 6), $0.maxX - size.width - 6),
                y: min(max(preferred.y, $0.minY + 6), $0.maxY - size.height - 6)
            )
        } ?? preferred
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        PanelChrome.applyRoundedCorners(
            to: panel,
            radius: PopupStyle.panelCornerRadius + 2,
            clearBackground: true
        )
        panel.orderFrontRegardless()
        panel.makeKey()
        button.isHighlighted = true
        installOutsideMonitors()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeOutsideMonitors()
        anchorButton?.isHighlighted = false
        onDidClose?()
    }

    private func installOutsideMonitors() {
        removeOutsideMonitors()
        outsideGlobal = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let point = NSEvent.mouseLocation
                guard !self.panel.frame.contains(point) else { return }
                if let button = self.anchorButton, let window = button.window,
                   window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point) {
                    return
                }
                self.hide()
            }
        }
    }

    private func removeOutsideMonitors() {
        if let outsideGlobal {
            NSEvent.removeMonitor(outsideGlobal)
            self.outsideGlobal = nil
        }
    }
}
