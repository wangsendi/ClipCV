import SwiftUI

struct ItemImage: View {
    let item: ClipboardItem
    let maxSide: Int
    var fit = false
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
                } else { Rectangle().fill(ClipStyle.green.opacity(0.08)).overlay { ProgressView() } }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .task(id: item.identifier) {
            guard let data = item.imagePayloadData else { return }
            let decoded = await ThumbnailCache.image(data: data, id: item.identifier, maxSide: maxSide)
            if !Task.isCancelled { image = decoded }
        }
    }
}
