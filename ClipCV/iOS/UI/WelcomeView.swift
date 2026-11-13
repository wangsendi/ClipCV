import SwiftUI

struct WelcomeView: View {
    @Environment(AppRuntime.self) private var runtime

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("CV").font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.7)).frame(width: 76, height: 76)
                .background(ClipStyle.gradient, in: RoundedRectangle(cornerRadius: 25))
            Text("ClipCV").font(.system(size: 40, weight: .bold, design: .rounded))
            Text("剪贴板历史").font(.title3).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "square.on.square").font(.system(size: 66, weight: .light))
                .foregroundStyle(ClipStyle.green).frame(maxWidth: .infinity).frame(height: 180).clipCard()
            Text("打开应用时自动记录。").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("开始记录", systemImage: "play") { runtime.start() }.buttonStyle(PrimaryButtonStyle())
        }.padding(26).clipPage()
    }
}
