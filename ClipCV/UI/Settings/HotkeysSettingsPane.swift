//
//  HotkeysSettingsPane.swift
//  ClipCV
//

import SwiftUI

struct HotkeysSettingsPane: View {
    @Environment(AppSettings.self) private var settings
    @State private var pinKeyOrderDraft = ""
    @State private var unpinnedKeyOrderDraft = ""

    var body: some View {
        @Bindable var settings = settings
        let chinese = settings.appLanguage.resolvedIsChinese
        let _ = settings.appLanguage

        SettingsPage {
            SettingsSection(title: L10n.t(.hotkeys)) {
                SettingsHotkeyRow(
                    label: L10n.t(.openLabel), title: L10n.t(.open), help: L10n.t(.openHelp),
                    value: settings.hotkey, target: .popup, showsDivider: true
                )
                SettingsHotkeyRow(
                    label: L10n.t(.pinLabel), title: L10n.t(.pin), help: L10n.t(.pinHelp),
                    value: settings.pinHotkey, target: .pin, showsDivider: true
                )
                SettingsHotkeyRow(
                    label: L10n.t(.deleteLabel), title: L10n.t(.delete), help: L10n.t(.deleteHelp),
                    value: settings.deleteHotkey, target: .delete, showsDivider: true
                )
                SettingsHotkeyRow(
                    label: L10n.t(.previewLabel), title: L10n.t(.preview), help: L10n.t(.previewHelp),
                    value: settings.previewHotkey, target: .preview
                )
            }

            SettingsSection(title: L10n.t(.historyShortcuts)) {
                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.unpinnedKeyOrder), chinese: chinese),
                    alignment: .top,
                    showsDivider: true
                ) {
                    ShortcutOrderField(
                        prefix: $settings.unpinnedShortcutPrefix,
                        order: $unpinnedKeyOrderDraft,
                        placeholder: HotkeyFormatting.defaultUnpinnedKeyOrder,
                        help: L10n.t(.unpinnedKeyOrderHelp),
                        allowingDigits: true,
                        onCommit: commitDrafts
                    )
                }

                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.pinKeyOrder), chinese: chinese),
                    alignment: .top
                ) {
                    ShortcutOrderField(
                        prefix: $settings.pinnedShortcutPrefix,
                        order: $pinKeyOrderDraft,
                        placeholder: HotkeyFormatting.defaultPinKeyOrder,
                        help: L10n.t(.pinnedKeyOrderHelp),
                        allowingDigits: false,
                        onCommit: commitDrafts
                    )
                }
            }
        }
        .installsHotkeyCapture()
        .onAppear {
            pinKeyOrderDraft = settings.pinKeyOrder
            unpinnedKeyOrderDraft = settings.unpinnedKeyOrder
        }
        .onDisappear(perform: commitDrafts)
    }

    private func commitDrafts() {
        let unpinned = HotkeyFormatting.normalizeUnpinnedOrder(unpinnedKeyOrderDraft)
        unpinnedKeyOrderDraft = unpinned.isEmpty ? HotkeyFormatting.defaultUnpinnedKeyOrder : unpinned
        settings.unpinnedKeyOrder = unpinnedKeyOrderDraft

        let pinned = HotkeyFormatting.normalizePinOrder(pinKeyOrderDraft)
        pinKeyOrderDraft = pinned.isEmpty ? HotkeyFormatting.defaultPinKeyOrder : pinned
        settings.pinKeyOrder = pinKeyOrderDraft
    }
}

private struct ShortcutOrderField: View {
    @Binding var prefix: ShortcutModifierPrefix
    @Binding var order: String
    let placeholder: String
    let help: String
    let allowingDigits: Bool
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SettingsMenuPicker(selection: $prefix, width: 64) {
                    ForEach(ShortcutModifierPrefix.allCases) { Text($0.title).tag($0) }
                }
                TextField(placeholder, text: $order)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 168)
                    .font(.system(size: 13, design: .monospaced))
                    .onSubmit(onCommit)
                    .onChange(of: order) { _, value in
                        let filtered = String(value.uppercased().filter {
                            $0.isLetter || (allowingDigits && $0.isNumber)
                        })
                        if filtered != value { order = filtered }
                    }
            }
            SettingsFootnote(help)
        }
    }
}
