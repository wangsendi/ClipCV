import AppKit
import SwiftUI

private enum PreviewDisplayMode: String, CaseIterable, Identifiable {
    case raw, view
    var id: Self { self }
}

struct ItemPreviewPane: View {
    @Environment(AppSettings.self) private var settings
    let item: ClipboardItem
    let usedPinKeys: Set<String>
    @Binding var isEditing: Bool
    var onSave: (String, String?, String?) -> ApplyEditResult = { _, _, _ in .saved }
    var onPin: () -> Void = {}
    var onDelete: () -> Void = {}
    var onOCR: () async -> Void = {}

    @State private var mode: PreviewDisplayMode = .raw
    @State private var kind: DeveloperPreviewKind = .plain
    @State private var rendered: AttributedString?
    @State private var isRendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var displayImage: NSImage?
    @State private var imagePixelSize: (width: Int, height: Int)?
    @State private var isRecognizingOCR = false

    private var ocrText: String? {
        guard let text = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        return text
    }

    var body: some View {
        let _ = settings.appLanguage
        let text = ClipboardRules.previewText(for: item)
        VStack(spacing: 0) {
            toolbar
            if isEditing {
                editForm
            } else {
                browsePane(text: text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.04))
        .onAppear { refresh(for: text) }
        .task(id: item.identifier) { await loadDisplayImage() }
        .onChange(of: item.identifier) { _, _ in
            isEditing = false
            displayImage = nil
            imagePixelSize = nil
            refreshCurrent()
        }
        .onChange(of: item.alias) { _, _ in refreshCurrent() }
        .onChange(of: item.title) { _, _ in refreshCurrent() }
        .onChange(of: mode) { _, _ in scheduleRender(ClipboardRules.previewText(for: item)) }
        .onDisappear {
            renderTask?.cancel()
            renderTask = nil
            displayImage = nil
        }
    }

    private func loadDisplayImage() async {
        // 连续选择时跳过途经图片，避免无用的解码和预览刷新。
        do { try await Task.sleep(for: .milliseconds(60)) }
        catch { return }
        guard let data = item.imagePayloadData else { return }
        let image = await ThumbnailCache.makeCancellable(from: data, maxSide: 640)
        guard !Task.isCancelled else { return }
        displayImage = image
        imagePixelSize = ThumbnailCache.pixelSize(of: data)
    }

    private var editForm: some View {
        ItemEditForm(
            item: item,
            usedPinKeys: usedPinKeys,
            onSave: { alias, content, pinKey in
                let result = onSave(alias, content, pinKey)
                if result == .saved { isEditing = false }
                return result
            },
            onCancel: { isEditing = false }
        )
    }

    private func browsePane(text: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                previewContent(text: text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            metadataFooter
        }
    }

    private func refreshCurrent() {
        refresh(for: ClipboardRules.previewText(for: item))
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            if !isEditing {
                if item.hasImage {
                    toolbarButton(
                        "text.viewfinder",
                        help: ocrText == nil ? L10n.t(.recognizeOCR) : L10n.t(.copyOCR),
                        disabled: isRecognizingOCR
                    ) {
                        Task {
                            isRecognizingOCR = true
                            defer { isRecognizingOCR = false }
                            await onOCR()
                        }
                    }
                }
                toolbarButton(
                    item.pinned ? "pin.slash.fill" : "pin",
                    help: item.pinned ? L10n.t(.unpin) : L10n.t(.pin),
                    action: onPin
                )
                toolbarButton("pencil.and.list.clipboard", help: L10n.t(.editItem)) {
                    isEditing = true
                }
                toolbarButton("trash", help: L10n.t(.delete), action: onDelete)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 28)
    }

    private func toolbarButton(
        _ systemName: String,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
                .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    @ViewBuilder
    private func previewContent(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind != .plain { modeToggle }
            if let image = displayImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if ocrText != nil {
                Text(L10n.t(.ocrAvailable))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if !text.isEmpty {
                Text((mode == .view ? rendered : nil) ?? DeveloperPreview.rawAttributed(text))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if mode == .view, isRendering {
                    Text(L10n.t(.previewRendering))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else if !item.hasImage {
                Text(L10n.t(.previewEmpty))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !item.alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                meta(L10n.t(.alias), item.alias)
            }
            HStack(spacing: 6) {
                Text("\(L10n.t(.previewApp)):").foregroundStyle(.secondary)
                if let icon = ApplicationIconCache.icon(forBundleID: item.sourceApp, size: 14) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 14, height: 14)
                }
                Text(ApplicationIconCache.displayName(forBundleID: item.sourceApp) ?? item.sourceApp ?? "—")
                    .lineLimit(1)
            }
            if let size = imagePixelSize {
                meta(L10n.t(.previewDimensions), "\(size.width.formatted())×\(size.height.formatted())")
            }
            if let bytes = contentByteCount {
                meta(L10n.t(.previewFileSize), ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
            }
            meta(L10n.t(.previewFirstCopied), item.firstCopiedAt.formatted(date: .abbreviated, time: .shortened))
            meta(L10n.t(.previewLastCopied), item.createdAt.formatted(date: .abbreviated, time: .shortened))
            HStack(spacing: 12) {
                meta(L10n.t(.copiesCount), "\(item.numberOfCopies)")
                if item.pinned, let pinKey = item.pinKey {
                    meta(L10n.t(.pin), pinKey)
                }
            }
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(PreviewDisplayMode.allCases) { option in
                let selected = mode == option
                Button { mode = option } label: {
                    Text(option == .raw ? L10n.t(.previewRaw) : L10n.t(.previewView))
                        .font(.system(size: 11, weight: selected ? .semibold : .regular).monospaced())
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func refresh(for text: String) {
        renderTask?.cancel()
        rendered = nil
        isRendering = false
        kind = text.isEmpty ? .plain : DeveloperPreview.kind(of: text)
        if kind == .plain { mode = .raw }
        scheduleRender(text)
    }

    private func scheduleRender(_ text: String) {
        renderTask?.cancel()
        rendered = nil
        guard mode == .view, kind != .plain, !text.isEmpty else {
            isRendering = false
            return
        }
        isRendering = true
        let renderKind = kind
        renderTask = Task.detached(priority: .userInitiated) {
            let attributed = DeveloperPreview.renderedAttributed(from: text, kind: renderKind)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                rendered = attributed
                isRendering = false
            }
        }
    }

    private func meta(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(label):").foregroundStyle(.secondary)
            Text(value)
        }
    }

    private var contentByteCount: Int64? {
        let total = item.storedContents.reduce(Int64(0)) { $0 + Int64($1.value.count) }
        return total > 0 ? total : nil
    }
}
