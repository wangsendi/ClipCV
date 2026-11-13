import ImageIO
import UIKit

enum ThumbnailCache {
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1_048_576
        return cache
    }()

    nonisolated static func image(data: Data, id: UUID, maxSide: Int) async -> UIImage? {
        let key = "\(id)-\(maxSide)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let task = Task.detached(priority: .userInitiated) { decode(data, maxSide: maxSide) }
        let image = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard !Task.isCancelled, let image else { return nil }
        let bytes = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: key, cost: bytes)
        return image
    }

    nonisolated static func original(data: Data) async -> UIImage? {
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
            else { return nil }
            let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let orientation = metadata?[kCGImagePropertyOrientation] as? Int ?? 1
            let orientations: [UIImage.Orientation] = [.up, .upMirrored, .down, .downMirrored, .leftMirrored, .right, .rightMirrored, .left]
            return UIImage(cgImage: cg, scale: 1, orientation: orientations[min(8, max(1, orientation)) - 1])
        }
        return await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    nonisolated static func dimensions(_ data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let values = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = values[kCGImagePropertyPixelWidth] as? Int,
              let height = values[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return "\(width) × \(height)"
    }

    nonisolated private static func decode(_ data: Data, maxSide: Int) -> UIImage? {
        guard !Task.isCancelled, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
