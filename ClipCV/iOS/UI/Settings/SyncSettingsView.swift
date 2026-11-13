import SwiftUI

struct SyncSettingsView: View {
    @Environment(AppRuntime.self) private var runtime

    var body: some View {
        @Bindable var settings = runtime.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroup(title: "同步") {
                    Toggle(isOn: $settings.syncEnabled) { SettingsRow(title: "iCloud 同步", symbol: "icloud") }
                }
                Text(settings.syncEnabled != runtime.syncAtLaunch ? "重开后生效" : "更改后需重开应用。")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
                SettingsGroup(title: "状态") {
                    HStack { SettingsRow(title: "当前状态", symbol: "checkmark"); CloudStatusLabel().font(.caption).foregroundStyle(.secondary) }
                    if let date = runtime.cloud.lastTransferAt {
                        Divider()
                        HStack { Text("最近传输"); Spacer(); Text(date, format: .dateTime.month().day().hour().minute()) }.font(.caption).foregroundStyle(.secondary).frame(minHeight: 44)
                    }
                }
            }.padding(20)
        }.clipPage().navigationTitle("iCloud 同步").toggleStyle(PlushToggleStyle())
            .task { await runtime.cloud.refresh() }
    }
}
