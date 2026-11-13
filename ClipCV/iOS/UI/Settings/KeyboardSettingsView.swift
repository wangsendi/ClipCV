import SwiftUI

struct KeyboardSettingsView: View {
    var body: some View {
        ScrollView {
            SettingsGroup(title: "启用") {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("添加 ClipCV 键盘").fontWeight(.medium)
                        Text("设置 → 通用 → 键盘 → 键盘\n添加新键盘 → ClipCV").font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("切换键盘").fontWeight(.medium)
                        Text("长按地球键，选择 ClipCV。").font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
            }.padding(20)
        }.clipPage().navigationTitle("剪贴板键盘")
            .safeAreaInset(edge: .bottom) {
                Button("打开设置", systemImage: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.buttonStyle(PrimaryButtonStyle()).padding(20).background(ClipStyle.background)
            }
    }
}
