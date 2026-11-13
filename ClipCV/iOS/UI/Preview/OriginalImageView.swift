import SwiftUI

struct OriginalImageView: View {
    let item: ClipboardItem
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image { ZoomableImage(image: image).ignoresSafeArea() }
            else { ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity) }
            Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(.white).padding(15).background(.black.opacity(0.5), in: Circle()) }
                .padding(20).accessibilityLabel("关闭")
        }.statusBarHidden()
        .task {
            guard let data = item.imagePayloadData else { return }
            let decoded = await ThumbnailCache.original(data: data)
            if !Task.isCancelled { image = decoded }
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ImageScrollView {
        let view = ImageScrollView()
        view.imageView.image = image
        view.imageView.frame.size = image.size
        view.contentSize = image.size
        view.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: ImageScrollView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ImageScrollView)?.imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { (scrollView as? ImageScrollView)?.centerImage() }
        @objc func doubleTap(_ tap: UITapGestureRecognizer) {
            guard let view = tap.view as? ImageScrollView else { return }
            if view.zoomScale > view.minimumZoomScale * 1.1 { view.setZoomScale(view.minimumZoomScale, animated: true); return }
            let scale = min(view.maximumZoomScale, view.minimumZoomScale * 3)
            let point = tap.location(in: view.imageView)
            let size = CGSize(width: view.bounds.width / scale, height: view.bounds.height / scale)
            view.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
        }
    }
}

private final class ImageScrollView: UIScrollView {
    let imageView = UIImageView()
    private var fittedSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        backgroundColor = .black
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedSize, let size = imageView.image?.size, size.width > 0, size.height > 0 {
            fittedSize = bounds.size
            minimumZoomScale = min(bounds.width / size.width, bounds.height / size.height)
            maximumZoomScale = max(1, minimumZoomScale * 6)
            zoomScale = minimumZoomScale
        }
        centerImage()
    }

    func centerImage() {
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}
