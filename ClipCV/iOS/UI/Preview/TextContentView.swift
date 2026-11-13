import SwiftUI

struct TextContentView: View {
    let item: ClipboardItem
    @Environment(AppRuntime.self) private var runtime
    @Environment(\.openURL) private var openURL
    @State private var rendered: AttributedString?
    @State private var source = true
    @State private var kind = DeveloperPreviewKind.plain
    @State private var copied = false

    private var text: String { ClipboardRules.plainText(from: item.payloads) ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rgb = ClipboardRules.parseHexRGB(from: text) { colorPreview(rgb) }
            if ClipboardRules.isWebLinkItem(item), let url = URL(string: text) {
                Image(systemName: "link").font(.system(size: 44)).foregroundStyle(ClipStyle.green)
                    .frame(maxWidth: .infinity).frame(height: 150).clipCard()
                Button("打开链接", systemImage: "globe") { openURL(url) }.buttonStyle(.bordered)
            }
            if kind != .plain {
                Picker("预览", selection: $source) {
                    Text("原文").tag(true)
                    Text(kind == .json ? "格式化" : "预览").tag(false)
                }.pickerStyle(.segmented)
            }
            Group {
                if !source, let rendered { Text(rendered) }
                else { Text(String(text.prefix(120_000))) }
            }.font(.system(size: 16, design: kind == .json ? .monospaced : .default))
                .lineSpacing(7).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6).clipCard(padding: 22)
            if kind == .json, !source, let rendered {
                Button(copied ? "已复制" : "复制格式化结果", systemImage: copied ? "checkmark" : "square.on.square") {
                    copied = runtime.copyText(String(rendered.characters))
                }.buttonStyle(.bordered)
            }
        }
        .task(id: item.createdAt) { await renderContent() }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1)); copied = false
        }
    }

    private func colorPreview(_ rgb: UInt32) -> some View {
        RoundedRectangle(cornerRadius: 24).fill(Color(
            red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255
        )).frame(height: 190)
    }

    private func renderContent() async {
        let input = text
        let result = await Task.detached(priority: .userInitiated) {
            let kind = DeveloperPreview.kind(of: input)
            var rendered = DeveloperPreview.renderedAttributed(from: input, kind: kind)
            rendered.font = nil
            return (kind, rendered)
        }.value
        guard !Task.isCancelled else { return }
        kind = result.0
        rendered = result.1
        source = kind == .plain
    }
}
