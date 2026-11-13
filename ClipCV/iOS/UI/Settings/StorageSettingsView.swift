import SwiftData
import SwiftUI

struct StorageSettingsView: View {
    @Environment(AppRuntime.self) private var runtime
    @Query private var items: [ClipboardItem]
    @State private var bytes: Int64 = 0

    var body: some View {
        @Bindable var settings = runtime.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                storageChart
                SettingsGroup(title: "历史上限") {
                    Picker(selection: $settings.historyLimit) {
                        ForEach([200, 500, 999], id: \.self) { Text("\($0) 条").tag($0) }
                    } label: { SettingsRow(title: "最多保留", symbol: "internaldrive") }
                    Divider()
                    Picker(selection: $settings.historySizeLimitMB) {
                        Text("300 MB").tag(300)
                        Text("1 GB").tag(1_024)
                        Text("不限").tag(0)
                    } label: { SettingsRow(title: "存储上限", symbol: "photo") }
                }
                if runtime.limits.enabled && !runtime.limits.hasPolicy {
                    Text("设置上限后启用自动清理。").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
                }
                Text("自动清理保留钉选。").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
                SettingsGroup(title: "内容") {
                    SettingsRow(title: "钉选", symbol: "pin", value: "\(items.filter(\.pinned).count)")
                    Divider()
                    SettingsRow(title: "全部历史", symbol: "clock", value: "\(items.count)")
                }
                SettingsGroup(title: "清理") {
                    Button("清空未钉选", systemImage: "trash") { clear(all: false) }.frame(minHeight: 52)
                    Divider()
                    Button("清空全部历史", systemImage: "trash", role: .destructive) { clear(all: true) }.frame(minHeight: 52)
                }
                if runtime.cloud.enabled { Text("删除会同步到其他设备。").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6) }
            }.padding(20)
        }.clipPage().navigationTitle("历史与空间")
            .task(id: items.map(\.identifier)) { refreshSize() }
            .onChange(of: settings.historyLimit) { runtime.updateLimits(); refreshSize() }
            .onChange(of: settings.historySizeLimitMB) { runtime.updateLimits(); refreshSize() }
    }

    private var storageChart: some View {
        ZStack {
            Circle().stroke(ClipStyle.green.opacity(0.12), lineWidth: 11)
            Circle().trim(from: 0, to: min(1, Double(bytes) / Double(max(1, runtime.settings.historySizeLimitMB) * 1_048_576)))
                .stroke(ClipStyle.gradient, style: StrokeStyle(lineWidth: 11, lineCap: .round)).rotationEffect(.degrees(-90))
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                .font(.system(size: 23, weight: .semibold, design: .rounded))
        }.frame(width: 150, height: 150).frame(maxWidth: .infinity).padding(.vertical, 19)
    }

    private func clear(all: Bool) {
        runtime.perform { try runtime.history.delete(items.filter { all || !$0.pinned }) }
        refreshSize()
    }

    private func refreshSize() { bytes = items.reduce(0) { $0 + ClipboardRules.byteSize(of: $1) } }
}
