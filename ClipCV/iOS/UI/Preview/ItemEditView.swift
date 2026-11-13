import SwiftUI

struct ItemEditView: View {
    let item: ClipboardItem
    @Environment(AppRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    @State private var alias = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("标题").font(.caption).foregroundStyle(.secondary)
                        TextField("标题", text: $alias).accessibilityIdentifier("edit-alias")
                    }.clipCard()
                    if ClipboardRules.isContentEditable(item) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("内容").font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $text).accessibilityIdentifier("edit-content").scrollContentBackground(.hidden).frame(minHeight: 220)
                        }.clipCard()
                        if item.storedContents.contains(where: { $0.type == ClipboardRules.Kind.rtf || $0.type == ClipboardRules.Kind.html }) {
                            Text("修改内容后转为纯文本。").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(20)
            }
            .clipPage().navigationTitle("编辑")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        runtime.perform {
                            try runtime.history.edit(item, alias: alias, text: ClipboardRules.isContentEditable(item) ? text : nil)
                        }
                        if !runtime.storageFailed { dismiss() }
                    }.fontWeight(.semibold)
                }
            }
            .onAppear {
                alias = item.alias.isEmpty ? item.displayTitle : item.alias
                text = ClipboardRules.plainText(from: item.payloads) ?? ""
            }
        }
    }
}
