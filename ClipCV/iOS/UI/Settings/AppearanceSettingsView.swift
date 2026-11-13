import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppRuntime.self) private var runtime

    var body: some View {
        @Bindable var settings = runtime.settings
        ScrollView {
            VStack(spacing: 22) {
                SettingsGroup(title: "外观") {
                    Picker("外观", selection: $settings.appearance) {
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                        Text("跟随系统").tag("system")
                    }.pickerStyle(.segmented).padding(.vertical, 18)
                }
                SettingsGroup(title: "语言") {
                    Picker("显示语言", selection: $settings.language) {
                        Text("跟随系统").tag("system")
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }.frame(minHeight: 54)
                }
                Text("ClipCV").font(.title2.bold()).padding(.top, 25)
                Link(destination: URL(string: "https://github.com/wangsendi/ClipCV")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }.font(.callout)
            }.padding(20)
        }.clipPage().navigationTitle("语言与外观")
    }
}
