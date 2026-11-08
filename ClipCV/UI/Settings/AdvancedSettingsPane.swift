//
//  AdvancedSettingsPane.swift
//  ClipCV
//

import AppKit
import SwiftUI

struct AdvancedSettingsPane: View {
    @Environment(AppSettings.self) private var settings
    @State private var showRestartAlert = false
    @State private var confirmClearUnpinned = false
    @State private var confirmClearAll = false

    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var body: some View {
        @Bindable var settings = settings
        let _ = settings.appLanguage

        SettingsPage(contentWidth: 420) {
            SettingsSection(title: L10n.t(.iCloud)) {
                SettingsBlock(indent: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(L10n.t(.iCloudSync), isOn: iCloudSyncBinding)
                            .disabled(!iCloudAvailable && !settings.iCloudSyncEnabled)
                        if settings.iCloudSyncEnabled != AppModelContainer.isCloudKitEnabled {
                            Text(L10n.t(.iCloudPendingRestart))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        if !iCloudAvailable {
                            Text(L10n.t(.iCloudUnavailable))
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            SettingsSection(title: L10n.t(.pause)) {
                SettingsBlock(indent: false) {
                    Toggle(L10n.t(.pauseRecording), isOn: $settings.paused)
                }
            }

            SettingsSection(title: L10n.t(.clear)) {
                SettingsBlock(indent: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Button(L10n.t(.clearUnpinnedNow)) { confirmClearUnpinned = true }
                            Button(L10n.t(.clearEverythingNow), role: .destructive) {
                                confirmClearAll = true
                            }
                        }
                        Toggle(L10n.t(.clearHistoryOnQuit), isOn: $settings.clearOnQuit)
                        Toggle(L10n.t(.clearSystemClipboard), isOn: $settings.clearSystemClipboard)
                            .disabled(!settings.clearOnQuit)
                            .opacity(settings.clearOnQuit ? 1 : 0.45)
                    }
                }
            }
        }
        .alert(L10n.t(.iCloudRestartTitle), isPresented: $showRestartAlert) {
            Button(L10n.t(.iCloudRestartNow)) { relaunch() }
            Button(L10n.t(.iCloudRestartLater), role: .cancel) {}
        } message: {
            Text(L10n.t(.iCloudRestartMessage))
        }
        .confirmationDialog(L10n.t(.clearUnpinned), isPresented: $confirmClearUnpinned) {
            Button(L10n.t(.clearUnpinned), role: .destructive) {
                AppRuntime.monitor?.clear(includingPinned: false)
            }
            Button(L10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(L10n.t(.clearUnpinnedConfirm))
        }
        .confirmationDialog(L10n.t(.clearEverything), isPresented: $confirmClearAll) {
            Button(L10n.t(.clearEverything), role: .destructive) {
                AppRuntime.monitor?.clear(includingPinned: true)
            }
            Button(L10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(L10n.t(.clearEverythingConfirm))
        }
    }

    private var iCloudSyncBinding: Binding<Bool> {
        Binding(
            get: { settings.iCloudSyncEnabled },
            set: { newValue in
                guard newValue != settings.iCloudSyncEnabled else { return }
                guard !newValue || iCloudAvailable else { return }
                settings.iCloudSyncEnabled = newValue
                showRestartAlert = true
            }
        )
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.environment = ["CLIPCV_RELAUNCH_PID": String(ProcessInfo.processInfo.processIdentifier)]
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
