import SwiftData
import SwiftUI

struct OCRView: View {
    let item: ClipboardItem
    @Environment(AppRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var working = true
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ItemImage(item: item, maxSide: 900, fit: true).frame(height: 200).clipCard(padding: 8)
                    Text("识别结果").font(.caption).foregroundStyle(.secondary)
                    if working { ProgressView().frame(maxWidth: .infinity).frame(height: 100) }
                    else if text.isEmpty { ContentUnavailableView("未识别到文字", systemImage: "text.viewfinder") }
                    else { TextEditor(text: $text).scrollContentBackground(.hidden).frame(minHeight: 220).clipCard() }
                }.padding(20)
            }
            .clipPage().navigationTitle("识别文字")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if !working, !text.isEmpty {
                    Button(copied ? "已复制" : "复制文字", systemImage: copied ? "checkmark" : "square.on.square") {
                        copied = runtime.copyText(text)
                    }.buttonStyle(PrimaryButtonStyle()).padding(20).background(ClipStyle.background)
                }
            }
            .task { await recognize() }
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(1)); copied = false
            }
        }
    }

    private func recognize() async {
        if let existing = item.ocrText, !existing.isEmpty { text = existing; working = false; return }
        guard let data = item.imagePayloadData else { working = false; return }
        let recognized = await OCRService.recognizeText(in: data)
        guard !Task.isCancelled, item.modelContext != nil else { return }
        text = recognized ?? ""
        working = false
        if let recognized {
            runtime.perform { item.ocrText = recognized; try runtime.history.save() }
        }
    }
}
