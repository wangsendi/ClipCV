import AppKit
import OSLog

@MainActor
final class ClipboardFileAccess {
    private struct Bookmark: Codable {
        var data: Data
        var originalPath: String
    }

    private let directory: URL
    private let logger = Logger(subsystem: "wangsendi.ClipCV", category: "FileAccess")
    private var activeURLs: [URL] = []
    private var activePasteboard: NSPasteboard?
    private var activeChangeCount = 0

    init(directory: URL = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
    )[0].appendingPathComponent("ClipCV/file-bookmarks", isDirectory: true)) {
        self.directory = directory
    }

    deinit {
        activeURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    }

    func capture(_ payloads: [ClipboardPayload], for id: UUID) {
        let files = payloads.filter { $0.type == ClipboardRules.Kind.fileURL }
        guard !files.isEmpty else { return }
        let keys = Set(files.map { $0.data.base64EncodedString() })
        var bookmarks = load(id).filter { keys.contains($0.key) }
        for payload in files {
            guard let url = ClipboardRules.fileURLs(from: [payload]).first else { continue }
            do {
                bookmarks[payload.data.base64EncodedString()] = Bookmark(
                    data: try makeBookmark(url), originalPath: url.path
                )
            } catch {
                logger.error("Could not save file access: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try store(bookmarks, for: id)
        } catch {
            logger.error("Could not persist file access: \(error.localizedDescription, privacy: .public)")
        }
    }

    func write(_ payloads: [ClipboardPayload], for id: UUID, to pasteboard: NSPasteboard = .general) -> Bool {
        var urls: [URL] = []
        do {
            let restored = try restore(payloads, for: id, accessing: &urls)
            guard ClipboardWriter.write(restored, to: pasteboard) else { throw CocoaError(.fileWriteUnknown) }
        } catch {
            urls.forEach { $0.stopAccessingSecurityScopedResource() }
            logger.error("Could not restore file access: \(error.localizedDescription, privacy: .public)")
            return false
        }
        release()
        // Recipients need the grant after writeObjects returns, until the clipboard is replaced.
        activeURLs = urls
        activePasteboard = urls.isEmpty ? nil : pasteboard
        activeChangeCount = pasteboard.changeCount
        return true
    }

    func releaseIfNeeded() {
        guard let activePasteboard, activePasteboard.changeCount != activeChangeCount else { return }
        release()
    }

    func remove(_ id: UUID) {
        try? FileManager.default.removeItem(at: location(for: id))
    }

    func prune(keeping ids: Set<UUID>) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        for file in files where file.pathExtension == "plist" {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                  !ids.contains(id) else { continue }
            remove(id)
        }
    }

    // Resolve only the selected record; activating every historical grant exhausts sandbox resources.
    private func restore(
        _ payloads: [ClipboardPayload], for id: UUID, accessing urls: inout [URL]
    ) throws -> [ClipboardPayload] {
        guard payloads.contains(where: { $0.type == ClipboardRules.Kind.fileURL }) else { return payloads }
        var bookmarks = load(id)
        var refreshed = false
        let restored = try payloads.map { payload -> ClipboardPayload in
            guard payload.type == ClipboardRules.Kind.fileURL else { return payload }
            let key = payload.data.base64EncodedString()
            guard var bookmark = bookmarks[key] else { throw CocoaError(.fileReadNoPermission) }
            var stale = false
            let url = try URL(
                resolvingBookmarkData: bookmark.data,
                options: [.withSecurityScope, .withoutUI, .withoutMounting],
                bookmarkDataIsStale: &stale
            )
            guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
            urls.append(url)
            guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
            if stale {
                bookmark.data = try makeBookmark(url)
                bookmarks[key] = bookmark
                refreshed = true
            }
            guard url.path != bookmark.originalPath else { return payload }
            return ClipboardPayload(type: payload.type, data: Data(url.absoluteString.utf8))
        }
        if refreshed { try store(bookmarks, for: id) }
        return restored
    }

    private func makeBookmark(_ url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
    }

    private func load(_ id: UUID) -> [String: Bookmark] {
        guard let data = try? Data(contentsOf: location(for: id)) else { return [:] }
        return (try? PropertyListDecoder().decode([String: Bookmark].self, from: data)) ?? [:]
    }

    private func store(_ bookmarks: [String: Bookmark], for id: UUID) throws {
        guard !bookmarks.isEmpty else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try PropertyListEncoder().encode(bookmarks).write(to: location(for: id), options: .atomic)
    }

    private func location(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("plist")
    }

    private func release() {
        activeURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        activeURLs.removeAll()
        activePasteboard = nil
    }
}
