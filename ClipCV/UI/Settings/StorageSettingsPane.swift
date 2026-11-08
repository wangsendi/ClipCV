//
//  StorageSettingsPane.swift
//  ClipCV
//

import SwiftData
import SwiftUI

struct StorageSettingsPane: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var storageSummary = ""

    var body: some View {
        @Bindable var settings = settings
        let _ = settings.appLanguage
        let chinese = settings.appLanguage.resolvedIsChinese

        SettingsPage(contentWidth: 420) {
            SettingsSection(
                title: L10n.t(.save),
                footnote: L10n.t(.saveDescription)
            ) {
                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.save), chinese: chinese),
                    alignment: .top
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(L10n.t(.files), isOn: $settings.saveFiles)
                        Toggle(L10n.t(.images), isOn: $settings.saveImages)
                        Toggle(L10n.t(.text), isOn: $settings.saveText)
                    }
                }
            }

            SettingsSection(title: L10n.t(.capacity)) {
                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.capacity), chinese: chinese),
                    alignment: .center,
                    showsDivider: true
                ) {
                    HStack(spacing: 10) {
                        SettingsStepperField(value: $settings.historyLimit, range: 1...999, width: 72)
                        Text(L10n.t(.capacityItems))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.historySizeLimit), chinese: chinese),
                    alignment: .top,
                    showsDivider: true
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            SettingsStepperField(value: $settings.historySizeLimitMB, range: 0...10_240, width: 72)
                            Text(
                                settings.historySizeLimitMB > 0
                                    ? ByteCountFormatter.string(
                                        fromByteCount: Int64(settings.historySizeLimitMB) * 1024 * 1024,
                                        countStyle: .memory
                                    )
                                    : L10n.t(.historySizeUnlimited)
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                        SettingsFootnote(L10n.t(.historySizeLimitHelp))
                    }
                }

                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.imageStorageScale), chinese: chinese),
                    alignment: .top,
                    showsDivider: true
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            SettingsStepperField(value: $settings.imageStorageScalePercent, range: 0...100, width: 72)
                            Text(
                                (1..<100).contains(settings.imageStorageScalePercent)
                                    ? "\(settings.imageStorageScalePercent)%"
                                    : L10n.t(.imageStorageScaleOff)
                            )
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        }
                        SettingsFootnote(L10n.t(.imageStorageScaleHelp))
                    }
                }

                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.sortBy), chinese: chinese),
                    showsDivider: true
                ) {
                    SettingsMenuPicker(selection: $settings.sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                SettingsBlock(indent: false) {
                    Text(storageSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(settings.historyLimit)-\(settings.historySizeLimitMB)-\(settings.appLanguage.rawValue)") {
            let items = (try? modelContext.fetch(FetchDescriptor<ClipboardItem>())) ?? []
            let bytes = items.reduce(Int64(0)) { $0 + ClipboardRules.byteSize(of: $1) }
            let sizeText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            storageSummary = "\(L10n.format(.currentCount, items.count)) · \(L10n.format(.currentSize, sizeText))"
        }
    }
}
