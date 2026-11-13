import SwiftUI

struct RecordingSettingsView: View {
    @Environment(AppRuntime.self) private var runtime

    var body: some View {
        @Bindable var settings = runtime.settings
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 18) {
                    Image(systemName: settings.paused ? "pause" : "clock")
                        .font(.system(size: 32)).foregroundStyle(ClipStyle.green)
                        .frame(width: 80, height: 80).background(ClipStyle.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 27))
                    RecordingStatusLabel().font(.title2.bold())
                }.padding(.vertical, 20)
                if runtime.monitor.needsPermission {
                    Button("粘贴权限", systemImage: "gearshape") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.buttonStyle(.bordered)
                    Button("重试") { runtime.start() }.buttonStyle(.bordered)
                }
                SettingsGroup(title: "记录") {
                    Toggle(isOn: Binding(get: { !settings.paused }, set: { settings.paused = !$0 })) {
                        SettingsRow(title: "前台自动记录", symbol: "clock")
                    }
                    Divider()
                    NavigationLink { RecordingTypesView() } label: { SettingsRow(title: "记录类型", symbol: "photo", chevron: true) }
                }
                SettingsGroup(title: "同步") {
                    HStack { SettingsRow(title: "iCloud", symbol: "icloud"); CloudStatusLabel().font(.caption).foregroundStyle(.secondary) }
                }
            }.padding(20)
        }.clipPage().navigationTitle("记录").toolbar(.visible, for: .navigationBar).toggleStyle(PlushToggleStyle())
            .safeAreaInset(edge: .bottom) {
                Button(settings.paused ? "继续记录" : "暂停记录", systemImage: settings.paused ? "play" : "pause") {
                    settings.paused.toggle()
                }.buttonStyle(PrimaryButtonStyle()).padding(20).background(ClipStyle.background)
            }
    }
}

struct RecordingTypesView: View {
    @Environment(AppRuntime.self) private var runtime
    var body: some View {
        @Bindable var settings = runtime.settings
        ScrollView {
            SettingsGroup(title: "收录") {
                Toggle(isOn: $settings.saveText) { SettingsRow(title: "文字", symbol: "textformat") }
                Divider()
                Toggle(isOn: $settings.saveLinks) { SettingsRow(title: "链接", symbol: "link") }
                Divider()
                Toggle(isOn: $settings.saveRichText) { SettingsRow(title: "富文本", symbol: "pencil") }
                Divider()
                Toggle(isOn: $settings.saveImages) { SettingsRow(title: "图片", symbol: "photo") }
            }.padding(20)
        }.clipPage().navigationTitle("记录类型").toggleStyle(PlushToggleStyle())
    }
}
