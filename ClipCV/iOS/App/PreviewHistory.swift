import SwiftUI

enum PreviewHistory {
    static func insert(into history: HistoryStore) {
        let samples = [
            ("周末见面", "周六下午两点，我们在图书馆门口见。", false),
            ("下一版要做的事", "先做好自动记录，再把常用的句子钉起来。", false),
            ("ClipCV", "https://github.com/wangsendi/ClipCV", true),
            ("常用回复", "你好，资料已收到，我稍后回复你。", true),
        ]
        for (title, text, pinned) in samples {
            guard let item = try? history.capture([.init(type: ClipboardRules.Kind.string, data: Data(text.utf8))]) else { continue }
            item.alias = title
            if pinned { try? history.togglePin(item) }
        }
        let renderer = ImageRenderer(content: SeaPreview().frame(width: 900, height: 1_050))
        if let data = renderer.uiImage?.pngData(),
           let item = try? history.capture([.init(type: ClipboardRules.Kind.png, data: data)]) {
            item.alias = "周末的海边"
        }
        try? history.save()
    }
}

private struct SeaPreview: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.96, green: 0.86, blue: 0.81), .init(red: 0.83, green: 0.89, blue: 0.86)], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1, green: 0.95, blue: 0.8))
                    .frame(width: 210).position(x: geo.size.width * 0.72, y: geo.size.height * 0.3)
                Path { path in
                    path.move(to: .init(x: 0, y: geo.size.height * 0.6))
                    path.addQuadCurve(to: .init(x: geo.size.width, y: geo.size.height * 0.64), control: .init(x: geo.size.width * 0.3, y: geo.size.height * 0.44))
                    path.addLine(to: .init(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: .init(x: 0, y: geo.size.height))
                }.fill(Color(red: 0.65, green: 0.77, blue: 0.72))
                Ellipse().fill(Color(red: 0.86, green: 0.85, blue: 0.69))
                    .frame(width: geo.size.width * 1.6, height: geo.size.height * 0.5)
                    .position(x: geo.size.width * 0.35, y: geo.size.height * 1.02)
            }
        }
    }
}
