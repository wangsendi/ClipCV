//
//  HistoryItemRow.swift
//  ClipCV
//

import AppKit
import SwiftUI

struct HistoryItemRow: View {
    @Environment(AppSettings.self) private var settings
    let item: ClipboardItem
    let isSelected: Bool
    let shortcut: String?
    let query: String

    @State private var listImage: NSImage?

    private var listMaxSide: CGFloat {
        CGFloat(max(settings.imageMaxHeight, 40)) * 2
    }

    var body: some View {
        HStack(spacing: 0) {
            appIcon
            Spacer()
                .frame(width: settings.showApplicationIcons && item.sourceApp != nil ? 5 : 10)
            mainContent
            colorSwatch
            Spacer(minLength: 8)
            trailingBadges
        }
        .frame(minHeight: max(PopupStyle.itemHeight, CGFloat(settings.imageMaxHeight) + 4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Color.white : .primary)
        .background(
            isSelected ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.001),
            in: RoundedRectangle(cornerRadius: PopupStyle.cornerRadius, style: .continuous)
        )
        .contentShape(Rectangle())
        .task(id: "\(item.identifier.uuidString)-\(Int(listMaxSide))") {
            listImage = await loadListThumbnail()
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if settings.showApplicationIcons,
           let icon = ApplicationIconCache.icon(forBundleID: item.sourceApp) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 15, height: 15)
                .padding(.leading, 4)
                .padding(.vertical, 5)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if item.hasImage {
            listThumbnail
                .padding(.trailing, 5)
                .padding(.vertical, 2)
        } else {
            Text(titleAttributed)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.trailing, 5)
        }
    }

    @ViewBuilder
    private var colorSwatch: some View {
        if settings.showHexColorSwatch, let color = ClipboardRules.nsColor(fromHexTitle: item.title) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(nsColor: color))
                .frame(width: 12, height: 12)
                .padding(.trailing, 6)
        }
    }

    @ViewBuilder
    private var trailingBadges: some View {
        if item.pinned {
            Image(systemName: "pin.fill")
                .font(.system(size: 10))
                .opacity(0.8)
                .padding(.trailing, shortcut == nil ? 10 : 4)
        }
        if let shortcut {
            Text(shortcut)
                .font(.system(size: 12))
                .opacity(0.7)
                .padding(.trailing, 10)
        }
    }

    @ViewBuilder
    private var listThumbnail: some View {
        Group {
            if let listImage {
                Image(nsImage: listImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            }
        }
        .frame(maxWidth: 150, maxHeight: CGFloat(settings.imageMaxHeight))
    }

    private func loadListThumbnail() async -> NSImage? {
        let id = item.identifier
        let maxSide = listMaxSide
        if let cached = ThumbnailCache.cached(id: id, maxSide: maxSide) { return cached }
        guard let data = item.imagePayloadData else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let image = ThumbnailCache.make(from: data, maxSide: maxSide) else { return nil }
            ThumbnailCache.store(image, id: id, maxSide: maxSide)
            return image
        }.value
    }

    private var displayTitle: String {
        let base = item.displayTitle
        guard settings.showSpecialSymbols else { return base }
        return base
            .replacingOccurrences(of: "\t", with: "⇥")
            .replacingOccurrences(of: "\n", with: "↵")
            .replacingOccurrences(of: " ", with: "·")
    }

    private var titleAttributed: AttributedString {
        let text = displayTitle
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AttributedString(text)
        }
        var attributed = AttributedString(text)
        SearchService.highlightRanges(in: text, query: query, mode: settings.searchMode).forEach { range in
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { return }
            let attrRange = lower..<upper
            switch settings.highlightMatch {
            case .bold: attributed[attrRange].inlinePresentationIntent = .stronglyEmphasized
            case .italic: attributed[attrRange].inlinePresentationIntent = .emphasized
            case .underline: attributed[attrRange].underlineStyle = .single
            case .color: attributed[attrRange].backgroundColor = .yellow.opacity(isSelected ? 0.35 : 0.55)
            }
        }
        return attributed
    }
}
