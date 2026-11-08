//
//  WindowGeometry.swift
//  ClipCV
//

import AppKit

enum WindowGeometry {
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
}
