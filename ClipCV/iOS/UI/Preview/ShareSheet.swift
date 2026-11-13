import SwiftUI
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let item: ClipboardItem

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let content: [Any]
        if let data = item.imagePayloadData,
           let type = item.storedContents.first(where: { ClipboardRules.isImageType($0.type) })?.type {
            let ext = UTType(type)?.preferredFilenameExtension ?? "png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).\(ext)")
            context.coordinator.url = url
            content = (try? data.write(to: url, options: .atomic)) != nil ? [url] : []
        } else {
            content = [ClipboardRules.plainText(from: item.payloads) ?? ""]
        }
        return UIActivityViewController(activityItems: content, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIActivityViewController, coordinator: Coordinator) {
        if let url = coordinator.url { try? FileManager.default.removeItem(at: url) }
    }

    final class Coordinator {
        var url: URL?
    }
}
