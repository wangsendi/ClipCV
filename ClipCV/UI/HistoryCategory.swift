//
//  HistoryCategory.swift
//  ClipCV
//

import AppKit
import Foundation
import SwiftUI

enum HistoryTypeFilter: String, CaseIterable, Identifiable {
    case all, text, image, link, file, color, pinned

    var id: Self { self }

    static var contentTypes: [HistoryTypeFilter] { [.text, .image, .link, .file, .color] }

    var title: String {
        switch self {
        case .all: L10n.t(.categoryAll)
        case .text: L10n.t(.categoryText)
        case .image: L10n.t(.categoryImage)
        case .link: L10n.t(.categoryLink)
        case .file: L10n.t(.categoryFile)
        case .color: L10n.t(.categoryColor)
        case .pinned: L10n.t(.categoryPinned)
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .text: "text.alignleft"
        case .image: "photo"
        case .link: "link"
        case .file: "doc"
        case .color: "paintpalette"
        case .pinned: "pin.fill"
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: true
        case .text:
            ClipboardRules.hasTextContent(item)
                && !item.hasImage
                && !ClipboardRules.isWebLinkItem(item)
                && !ClipboardRules.isFileItem(item)
                && !ClipboardRules.isColorItem(item)
        case .image: item.hasImage
        case .link: ClipboardRules.isWebLinkItem(item)
        case .file: ClipboardRules.isFileItem(item)
        case .color: ClipboardRules.isColorItem(item)
        case .pinned: item.pinned
        }
    }
}

struct HistoryTypeBar: View {
    @Binding var selection: HistoryTypeFilter
    @Binding var sourceApp: String?
    var apps: [String]
    var totalCount: Int

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                iconButton(HistoryTypeFilter.all.systemImage, selected: selection == .all, help: L10n.t(.categoryAll)) {
                    selection = .all
                }
                iconButton(HistoryTypeFilter.pinned.systemImage, selected: selection == .pinned, help: L10n.t(.categoryPinned)) {
                    selection = .pinned
                }
                Text(verbatim: "\(totalCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .padding(.leading, 4)
                    .help(L10n.t(.totalCountHelp))
                Spacer(minLength: 4)
                ForEach(HistoryTypeFilter.contentTypes) { filter in
                    iconButton(filter.systemImage, selected: selection == filter, help: filter.title) {
                        selection = selection == filter ? .all : filter
                    }
                }
            }
            if !apps.isEmpty {
                HStack(spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(apps, id: \.self) { appButton($0) }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func iconButton(
        _ systemImage: String,
        selected: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.55))
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func appButton(_ bundleID: String) -> some View {
        let selected = sourceApp == bundleID
        let name = ApplicationIconCache.displayName(forBundleID: bundleID) ?? bundleID
        return Button {
            sourceApp = selected ? nil : bundleID
        } label: {
            Group {
                if let icon = ApplicationIconCache.icon(forBundleID: bundleID, size: 14) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.primary.opacity(0.55))
                }
            }
            .frame(width: 24, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(L10n.format(.filterByApp, name))
    }
}
