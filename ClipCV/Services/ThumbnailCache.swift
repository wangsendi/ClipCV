import AppKit
import ImageIO

enum ThumbnailCache: Sendable {
    // NSCache 支持并发访问，可安全跨 actor 共享。
    nonisolated(unsafe) private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    nonisolated static func cached(id: UUID, maxSide: CGFloat) -> NSImage? {
        cache.object(forKey: cacheKey(id, maxSide))
    }

    nonisolated static func store(_ image: NSImage, id: UUID, maxSide: CGFloat) {
        let pixels = max(1, image.size.width * image.size.height)
        cache.setObject(image, forKey: cacheKey(id, maxSide), cost: Int(pixels * 4))
    }

    nonisolated static func clear() {
        cache.removeAllObjects()
    }

    nonisolated static func makeCancellable(from data: Data, maxSide: CGFloat) async -> NSImage? {
        guard !Task.isCancelled else { return nil }
        let decode = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return nil as NSImage? }
            let image = make(from: data, maxSide: maxSide)
            return Task.isCancelled ? nil : image
        }
        return await withTaskCancellationHandler {
            await decode.value
        } onCancel: {
            decode.cancel()
        }
    }

    // 直接生成缩略图，避免先解码完整位图。
    nonisolated static func make(from data: Data, maxSide: CGFloat) -> NSImage? {
        let side = max(1, Int(maxSide.rounded()))
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    nonisolated static func resizedPNGData(from data: Data, maxSide: Int) -> Data? {
        guard maxSide > 0, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = props?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let longest = max(width, height)
        guard longest > maxSide else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    nonisolated static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }
        return (width, height)
    }

    nonisolated private static func cacheKey(_ id: UUID, _ maxSide: CGFloat) -> NSString {
        "\(id.uuidString)-\(Int(maxSide))" as NSString
    }
}
