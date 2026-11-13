import SwiftUI

struct ItemDetailView: View {
    let item: ClipboardItem
    @Environment(AppRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var viewingImage = false
    @State private var sharing = false
    @State private var ocr = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                content
                Text(item.displayTitle).font(.system(size: 25, weight: .semibold, design: .rounded))
                metadata
                if item.hasImage {
                    Button("识别文字", systemImage: "text.viewfinder") { ocr = true }.buttonStyle(.bordered)
                }
                if ClipboardRules.isFileItem(item) { Text("本机不可用").font(.callout).foregroundStyle(.secondary) }
            }.padding(20)
        }
        .clipPage().navigationTitle(item.hasImage ? "图片" : ClipboardRules.isWebLinkItem(item) ? "链接" : "文字")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    HistoryItemMenu(item: item, edit: { editing = true }, delete: {
                        dismiss()
                        runtime.perform { try runtime.history.delete([item]) }
                    })
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多操作")
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
        .sheet(isPresented: $editing) { ItemEditView(item: item) }
        .sheet(isPresented: $sharing) { ShareSheet(item: item) }
        .sheet(isPresented: $ocr) { OCRView(item: item) }
        .fullScreenCover(isPresented: $viewingImage) { OriginalImageView(item: item) }
    }

    @ViewBuilder private var content: some View {
        if item.hasImage {
            Button { viewingImage = true } label: {
                ItemImage(item: item, maxSide: 1_200, fit: true).frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 21)).clipCard(padding: 8)
                    .overlay(alignment: .bottomTrailing) { Image(systemName: "arrow.up.left.and.arrow.down.right").padding(16) }
            }.buttonStyle(.plain).accessibilityLabel("原图预览")
        } else if ClipboardRules.isFileItem(item) {
            Image(systemName: "doc").font(.system(size: 54)).foregroundStyle(ClipStyle.green)
                .frame(maxWidth: .infinity).frame(height: 180).clipCard()
        } else {
            TextContentView(item: item)
        }
    }

    private var metadata: some View {
        VStack(spacing: 13) {
            if let data = item.imagePayloadData {
                HStack { Text(ThumbnailCache.dimensions(data) ?? ""); Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) }
            }
            HStack { Text("首次复制"); Spacer(); Text(item.firstCopiedAt, format: .dateTime.month().day().hour().minute()) }
            HStack { Text("使用次数"); Spacer(); Text("\(item.numberOfCopies)") }
        }.font(.caption).foregroundStyle(.secondary).clipCard()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !ClipboardRules.isFileItem(item) {
                CopyButton(item: item, prominent: true).buttonStyle(PrimaryButtonStyle())
                Button { sharing = true } label: { CircleControl(symbol: "square.and.arrow.up") }
                    .accessibilityLabel("分享")
            }
        }.padding(.horizontal, 20).padding(.vertical, 10).background(ClipStyle.background)
    }
}
