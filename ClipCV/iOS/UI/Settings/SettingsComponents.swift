import SwiftUI

struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 6)
            VStack(spacing: 0) { content }.padding(.horizontal, 15).clipCard(padding: 0)
        }
    }
}

struct SettingsRow: View {
    let title: LocalizedStringKey
    let symbol: String
    var value = ""
    var chevron = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(ClipStyle.green)
                .frame(width: 27, height: 27).background(ClipStyle.green.opacity(0.1), in: Circle())
            Text(title).font(.system(size: 15))
            Spacer(minLength: 5)
            if !value.isEmpty { Text(value).font(.system(size: 12)).foregroundStyle(.secondary) }
            if chevron { Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary) }
        }.frame(minHeight: 54).contentShape(Rectangle())
    }
}

struct RecordingStatusLabel: View {
    @Environment(AppRuntime.self) private var runtime
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(runtime.settings.paused ? .secondary : ClipStyle.green).frame(width: 6, height: 6)
            if runtime.storageFailed || runtime.monitor.storageFailed { Text("存储不可用") }
            else if runtime.monitor.needsPermission { Text("需要粘贴权限") }
            else if !runtime.settings.hasStarted { Text("未开始") }
            else if runtime.settings.paused { Text("已暂停") }
            else { Text("前台记录中") }
        }
    }
}

struct CloudStatusLabel: View {
    @Environment(AppRuntime.self) private var runtime
    var body: some View {
        if runtime.syncAtLaunch && !runtime.cloud.enabled { Text("iCloud 不可用") }
        else if !runtime.cloud.enabled { Text("已关闭") }
        else if runtime.cloud.accountAvailable == nil { Text("正在检查") }
        else if runtime.cloud.accountAvailable == false { Text("iCloud 不可用") }
        else if runtime.cloud.failed { Text("同步遇到问题") }
        else if runtime.cloud.transferring { Text("正在传输") }
        else { Text("已启用") }
    }
}
