//
//  GeneralSettingsPane.swift
//  ClipCV
//

import AppKit
import ServiceManagement
import SwiftUI

struct GeneralSettingsPane: View {
    @Environment(AppSettings.self) private var settings
    @State private var launchError: String?
    @State private var accessibilityTrusted = PasteService.isTrusted(prompt: false)
    @State private var showContactDeveloper = false
    private let notificationsURL = URL(
        string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
    )!

    var body: some View {
        @Bindable var settings = settings
        @Bindable var updater = SoftwareUpdater.shared
        let _ = settings.appLanguage
        let chinese = settings.appLanguage.resolvedIsChinese

        SettingsPage {
            SettingsSection {
                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.language), chinese: chinese),
                    showsDivider: true
                ) {
                    SettingsMenuPicker(selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                }

                SettingsBlock(showsDivider: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(L10n.t(.launchAtLogin), isOn: launchAtLogin)
                        if let launchError {
                            Text(launchError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if SMAppService.mainApp.status == .requiresApproval {
                            SettingsFootnote(L10n.t(.launchNeedsApproval))
                        }
                    }
                }

                SettingsBlock(showsDivider: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            L10n.t(.checkForUpdates),
                            isOn: $updater.automaticallyChecksForUpdates
                        )
                        .disabled(!updater.isAvailable)
                        .opacity(updater.isAvailable ? 1 : 0.45)
                        Button(L10n.t(.checkNow)) {
                            if updater.isAvailable {
                                updater.checkForUpdates()
                            } else {
                                showContactDeveloper = true
                            }
                        }
                        .opacity(updater.isAvailable ? 1 : 0.45)
                    }
                }

                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.accessibility), chinese: chinese),
                    alignment: .center
                ) {
                    HStack(spacing: 8) {
                        Text(accessibilityTrusted ? L10n.t(.authorized) : L10n.t(.unauthorized))
                            .foregroundStyle(accessibilityTrusted ? Color.secondary : Color.orange)
                            .font(.system(size: 12, weight: .medium))
                        Button(L10n.t(.requestPermission)) {
                            _ = PasteService.isTrusted(prompt: true)
                            accessibilityTrusted = PasteService.isTrusted(prompt: false)
                        }
                        Button(L10n.t(.systemSettings)) {
                            PasteService.openAccessibilitySettings()
                        }
                    }
                }

                SettingsBlock {
                    SettingsFootnote(L10n.t(.accessibilityFooter))
                }
            }

            SettingsSection(title: L10n.t(.behavior)) {
                SettingsRow(title: L10n.t(.searchLabel), showsDivider: true) {
                    SettingsMenuPicker(selection: $settings.searchMode, width: 180) {
                        ForEach(SearchMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                SettingsBlock {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(L10n.t(.pasteAutomatically), isOn: $settings.pasteByDefault)
                        Toggle(L10n.t(.pasteWithoutFormatting), isOn: $settings.removeFormattingByDefault)
                        SettingsFootnote(settings.modifierHelpText)
                    }
                }
            }

            Link(destination: notificationsURL) {
                Label(L10n.t(.notificationsAndSounds), systemImage: "bell.badge")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 4)
        }
        .onAppear { accessibilityTrusted = PasteService.isTrusted(prompt: false) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = PasteService.isTrusted(prompt: false)
        }
        .alert(L10n.t(.contactDeveloperTitle), isPresented: $showContactDeveloper) {
            Button(L10n.t(.ok), role: .cancel) {}
        } message: {
            Text(L10n.t(.contactDeveloperMessage))
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchError = nil
                } catch {
                    launchError = error.localizedDescription
                }
            }
        )
    }
}
