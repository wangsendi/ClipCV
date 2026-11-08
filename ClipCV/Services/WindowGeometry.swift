//
//  WindowGeometry.swift
//  ClipCV
//

import AppKit
import ApplicationServices

enum WindowGeometry {
    // AX focused window → Cocoa coords (Y flipped from Quartz).
    static func frontmostWindowFrame() -> NSRect? {
        let fallback = NSScreen.main?.visibleFrame
        guard let app = NSWorkspace.shared.frontmostApplication else { return fallback }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            axApp, kAXFocusedWindowAttribute as CFString, &windowRef
        ) == .success, let window = windowRef else { return fallback }

        var positionRef: AnyObject?
        var sizeRef: AnyObject?
        let axWindow = window as! AXUIElement
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef)
        guard let positionValue = positionRef, let sizeValue = sizeRef else { return fallback }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        guard size.width > 1, size.height > 1 else { return fallback }

        let screenHeight = NSScreen.screens.map(\.frame.maxY).max() ?? fallback?.maxY ?? 0
        return NSRect(
            x: position.x,
            y: screenHeight - position.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    static func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    }

    static func constrain(origin: NSPoint, size: NSSize, to screen: NSScreen?) -> NSPoint {
        guard let visible = screen?.visibleFrame else { return origin }
        return NSPoint(
            x: min(max(origin.x, visible.minX), visible.maxX - size.width),
            y: min(max(origin.y, visible.minY), visible.maxY - size.height)
        )
    }

    static func clampY(_ y: CGFloat, size: NSSize, visible: NSRect) -> CGFloat {
        min(max(y, visible.minY), visible.maxY - size.height)
    }

    static func originCentered(in frame: NSRect?, size: NSSize, fallback: () -> NSPoint) -> NSPoint {
        guard let frame else { return fallback() }
        return constrain(
            origin: NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2),
            size: size,
            to: screenContaining(NSPoint(x: frame.midX, y: frame.midY))
        )
    }
}
