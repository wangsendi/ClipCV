import SwiftUI

struct HistoryItemRow: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            if item.hasImage { imageRow }
            else { textRow }
        }
        .clipCard(padding: 16)
        .overlay(alignment: .topLeading) {
            if item.pinned {
                RoundedRectangle(cornerRadius: 26).fill(ClipStyle.green.opacity(0.055)).allowsHitTesting(false)
            }
        }
    }

    private var textRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: symbol).font(.system(size: 13))
                    .foregroundStyle(ClipStyle.green).frame(width: 26, height: 26)
                    .background(ClipStyle.green.opacity(0.12), in: Circle())
                Text(item.displayTitle).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                if item.pinned { Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(ClipStyle.green) }
                if !ClipboardRules.isFileItem(item) { CopyButton(item: item) }
            }
            if let text = ClipboardRules.plainText(from: item.payloads), !ClipboardRules.isFileItem(item) {
                Text(String(text.prefix(240))).font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(2)
            }
            metadata
        }
    }

    private var imageRow: some View {
        HStack(spacing: 12) {
            ItemImage(item: item, maxSide: 160)
                .frame(width: 78, height: 78).clipShape(RoundedRectangle(cornerRadius: 17))
            VStack(alignment: .leading, spacing: 7) {
                Text(item.displayTitle).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text("图片").font(.system(size: 12)).foregroundStyle(.secondary)
                metadata
            }
            Spacer(minLength: 0)
            CopyButton(item: item)
        }
    }

    private var metadata: some View {
        HStack {
            if item.pinned { Label("钉选", systemImage: "pin").foregroundStyle(ClipStyle.green) }
            else { Text(item.createdAt, format: .dateTime.month().day().hour().minute()) }
        }.font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private var symbol: String {
        if ClipboardRules.isFileItem(item) { return "doc" }
        return ClipboardRules.isWebLinkItem(item) ? "link" : "textformat"
    }
}

struct HistoryItemMenu: View {
    let item: ClipboardItem
    @Environment(AppRuntime.self) private var runtime
    var edit: () -> Void
    var delete: () -> Void

    var body: some View {
        if !ClipboardRules.isFileItem(item) {
            Button("复制", systemImage: "square.on.square") { runtime.copy(item) }
            if ClipboardRules.hasTextContent(item), !item.hasImage {
                Button("复制纯文本", systemImage: "textformat") { runtime.copy(item, plain: true) }
            }
        }
        Button(item.pinned ? "取消钉选" : "钉选", systemImage: item.pinned ? "pin.slash" : "pin") {
            runtime.perform { try runtime.history.togglePin(item) }
        }
        Button("编辑", systemImage: "pencil", action: edit)
        Button("删除", systemImage: "trash", role: .destructive, action: delete)
    }
}
