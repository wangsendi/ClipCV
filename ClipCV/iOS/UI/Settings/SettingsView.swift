import SwiftUI

struct SettingsView: View {
    @Environment(AppRuntime.self) private var runtime

    var body: some View {
        @Bindable var settings = runtime.settings
        ScrollView {
            VStack(spacing: 22) {
                SettingsGroup(title: "记录") {
                    Toggle(isOn: Binding(get: { !settings.paused }, set: { settings.paused = !$0 })) {
                        SettingsRow(title: "前台自动记录", symbol: "clock")
                    }
                    Divider()
                    NavigationLink { RecordingTypesView() } label: { SettingsRow(title: "记录类型", symbol: "photo", chevron: true) }
                    Divider()
                    NavigationLink { KeyboardSettingsView() } label: { SettingsRow(title: "剪贴板键盘", symbol: "keyboard", chevron: true) }
                }
                SettingsGroup(title: "同步") {
                    Toggle(isOn: $settings.syncEnabled) { SettingsRow(title: "iCloud 同步", symbol: "icloud") }
                    Divider()
                    NavigationLink { SyncSettingsView() } label: {
                        HStack { SettingsRow(title: "当前状态", symbol: "checkmark"); CloudStatusLabel().font(.caption).foregroundStyle(.secondary); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
                    }
                }
                if settings.syncEnabled != runtime.syncAtLaunch { Text("重开后生效").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                SettingsGroup(title: "存储") {
                    NavigationLink { StorageSettingsView() } label: { SettingsRow(title: "历史与空间", symbol: "internaldrive", chevron: true) }
                }
                SettingsGroup(title: "通用") {
                    NavigationLink { AppearanceSettingsView() } label: { SettingsRow(title: "语言与外观", symbol: "globe", chevron: true) }
                }
                Text("ClipCV · iOS").font(.caption).foregroundStyle(.tertiary).padding(.top, 12)
            }.padding(20)
        }.clipPage().navigationTitle("设置").toolbar(.visible, for: .navigationBar)
            .toggleStyle(PlushToggleStyle()).buttonStyle(.plain)
    }
}
