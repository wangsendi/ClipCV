import SwiftUI

struct AppearanceSettingsPane: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        let _ = settings.appLanguage
        let chinese = settings.appLanguage.resolvedIsChinese

        SettingsPage {
            SettingsSection(title: L10n.t(.popupAt)) {
                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.popupAt), chinese: chinese),
                    alignment: .center,
                    showsDivider: true
                ) {
                    HStack(spacing: 8) {
                        SettingsMenuPicker(selection: $settings.popupPosition, width: 150) {
                            ForEach(PopupPositionSetting.allCases) { position in
                                Text(position.title).tag(position)
                            }
                        }
                    }
                }

                SettingsRow(
                    title: SettingsLabelStyle.titled(L10n.t(.pinTo), chinese: chinese),
                    showsDivider: true
                ) {
                    SettingsMenuPicker(selection: $settings.pinTo, width: 150) {
                        ForEach(PinPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                }

                SettingsRow(
                    title: L10n.t(.imageHeightLabel),
                    alignment: .center
                ) {
                    SettingsStepperField(value: $settings.imageMaxHeight, range: 1...200, width: 72)
                }
            }

            SettingsSection(title: L10n.t(.preview)) {
                SettingsBlock(showsDivider: true) {
                    Toggle(L10n.t(.openPreviewAutomatically), isOn: $settings.openPreviewAutomatically)
                }

                SettingsRow(
                    title: L10n.t(.previewDelay),
                    alignment: .center,
                    showsDivider: true
                ) {
                    SettingsStepperField(value: $settings.previewDelay, range: 200...100_000, width: 96)
                        .disabled(!settings.openPreviewAutomatically)
                        .opacity(settings.openPreviewAutomatically ? 1 : 0.45)
                }

                SettingsRow(title: SettingsLabelStyle.titled(L10n.t(.highlightMatches), chinese: chinese)) {
                    SettingsMenuPicker(selection: $settings.highlightMatch, width: 150) {
                        ForEach(HighlightMatchStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }
            }

            SettingsSection(title: L10n.t(.tabAppearance)) {
                SettingsBlock {
                    VStack(alignment: .leading, spacing: 7) {
                        Toggle(L10n.t(.showSpecialSymbols), isOn: $settings.showSpecialSymbols)

                        HStack(spacing: 8) {
                            Toggle(L10n.t(.showMenuIcon), isOn: $settings.showInStatusBar)
                            Picker("", selection: $settings.menuIcon) {
                                ForEach(MenuBarIconStyle.allCases) { icon in
                                    if let symbol = icon.systemImage {
                                        Image(systemName: symbol).tag(icon)
                                    } else {
                                        Image("MenuBarIcon")
                                            .renderingMode(.template)
                                            .tag(icon)
                                    }
                                }
                            }
                            .labelsHidden()
                            .scaledToFit()
                            .controlSize(.small)
                            .disabled(!settings.showInStatusBar)
                        }

                        Toggle(L10n.t(.showRecentCopyInMenuBar), isOn: $settings.showRecentCopyInMenuBar)
                            .disabled(!settings.showInStatusBar)

                        HStack(spacing: 8) {
                            Toggle(L10n.t(.showSearchField), isOn: $settings.showSearch)
                            Picker("", selection: $settings.searchVisibility) {
                                ForEach(SearchVisibility.allCases) { visibility in
                                    Text(visibility.title).tag(visibility)
                                }
                            }
                            .labelsHidden()
                            .scaledToFit()
                            .controlSize(.small)
                            .disabled(!settings.showSearch)
                        }

                        Toggle(L10n.t(.showTitleBeforeSearch), isOn: $settings.showTitle)
                        Toggle(L10n.t(.showApplicationIcons), isOn: $settings.showApplicationIcons)
                        Toggle(L10n.t(.showHexColorSwatch), isOn: $settings.showHexColorSwatch)
                        Toggle(L10n.t(.showFooter), isOn: $settings.showFooter)

                        if !settings.showFooter {
                            SettingsFootnote(L10n.t(.footerHiddenWarning))
                                .frame(maxWidth: 360, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}
