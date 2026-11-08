//
//  SettingsRootView.swift
//  ClipCV
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case hotkeys
    case storage
    case appearance
    case ignore
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .general: L10n.t(.tabGeneral)
        case .hotkeys: L10n.t(.tabHotkeys)
        case .storage: L10n.t(.tabStorage)
        case .appearance: L10n.t(.tabAppearance)
        case .ignore: L10n.t(.tabIgnore)
        case .advanced: L10n.t(.tabAdvanced)
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .hotkeys: "keyboard"
        case .storage: "externaldrive"
        case .appearance: "paintpalette"
        case .ignore: "nosign"
        case .advanced: "slider.horizontal.3"
        }
    }
}

struct SettingsRootView: View {
    @Environment(AppSettings.self) private var settings
    @State private var tab: SettingsTab = .general

    var body: some View {
        let _ = settings.appLanguage

        ZStack {
            PopupBackground()

            HStack(spacing: 0) {
                sidebar
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(
            width: SettingsMetrics.popoverSize.width,
            height: SettingsMetrics.popoverSize.height
        )
        .clipShape(RoundedRectangle(cornerRadius: PopupStyle.panelCornerRadius + 2, style: .continuous))
        .id(settings.appLanguage)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ClipCV")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(SettingsTab.allCases) { item in
                Button { tab = item } label: {
                    Label(item.title, systemImage: item.symbolName)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: tab == item ? .semibold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tab == item ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                        .foregroundStyle(tab == item ? Color.accentColor : Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .frame(width: SettingsMetrics.sidebarWidth, alignment: .topLeading)
        .background(Color.primary.opacity(0.04))
    }

    @ViewBuilder
    private var detail: some View {
        switch tab {
        case .general:
            GeneralSettingsPane()
        case .hotkeys:
            HotkeysSettingsPane()
        case .storage:
            StorageSettingsPane()
        case .appearance:
            AppearanceSettingsPane()
        case .ignore:
            IgnoreSettingsPane()
        case .advanced:
            AdvancedSettingsPane()
        }
    }
}
