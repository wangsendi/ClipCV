import AppKit
import SwiftUI

enum PopupStyle {
    static let verticalSeparatorPadding: CGFloat = 6
    static let horizontalSeparatorPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 5
    static let horizontalPadding: CGFloat = 5
    static let cornerRadius: CGFloat = 7
    static let itemHeight: CGFloat = 24
    static let panelCornerRadius: CGFloat = cornerRadius + horizontalPadding

    static let listWidth: CGFloat = 450
    static let maxPanelHeight: CGFloat = 800
    static let previewWidth: CGFloat = 320
    static let minimumVisibleItems = 3
    static let cursorGap: CGFloat = 12

    static let headerHeight: CGFloat = 34
    // 两行筛选栏都需要保留高度，避免应用图标被裁切。
    static let typeBarHeight: CGFloat = 70
    static var defaultPanelHeight: CGFloat { preferredHeight(itemCount: 10) }
    static var minimumPanelHeight: CGFloat { preferredHeight(itemCount: minimumVisibleItems) }
    private static var emptyPanelHeight: CGFloat { chromeHeight + itemHeight * CGFloat(minimumVisibleItems) }

    private static var chromeHeight: CGFloat {
        headerHeight + typeBarHeight + verticalPadding * 2 + verticalSeparatorPadding + 8
    }

    private static var maxVisibleItems: Int {
        max(minimumVisibleItems, Int((maxPanelHeight - chromeHeight) / itemHeight))
    }

    // 少量搜索结果也要为标题和筛选栏保留足够高度。
    static func preferredHeight(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return emptyPanelHeight }
        let rows = min(max(itemCount, minimumVisibleItems), maxVisibleItems)
        return min(chromeHeight + CGFloat(rows) * itemHeight, maxPanelHeight)
    }
}

struct PopupBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {}
}

enum PanelChrome {
    static func applyRoundedCorners(to panel: NSPanel, radius: CGFloat, clearBackground: Bool = false) {
        [panel.contentView, panel.contentView?.superview].compactMap { $0 }.forEach { view in
            view.wantsLayer = true
            view.layer?.cornerRadius = radius
            view.layer?.cornerCurve = .continuous
            view.layer?.masksToBounds = true
            if clearBackground { view.layer?.backgroundColor = NSColor.clear.cgColor }
        }
    }
}

enum ApplicationIconCache {
    private static var cache: [String: NSImage] = [:]
    private static var nameCache: [String: String] = [:]

    static func icon(forBundleID bundleID: String?, size: CGFloat = 15) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        cache[bundleID] = icon
        return icon
    }

    static func displayName(forBundleID bundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = nameCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            nameCache[bundleID] = bundleID
            return bundleID
        }
        let name = FileManager.default.displayName(atPath: url.path)
        nameCache[bundleID] = name
        return name
    }
}
