import Foundation
import SwiftData

@MainActor
final class HistoryStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func capture(_ payloads: [ClipboardPayload], source: String? = nil) throws -> ClipboardItem? {
        guard !ClipboardRules.isIgnorableEmpty(payloads) else { return nil }
        let title = ClipboardRules.title(for: payloads)
        if let latest = try latest(), ClipboardRules.isDuplicate(latest: latest.payloads, new: payloads) {
            latest.title = title
            latest.sourceApp = latest.sourceApp ?? source
            try recordUse(latest)
            return latest
        }
        let item = ClipboardItem(title: title, sourceApp: source)
        context.insert(item)
        item.contents = payloads.map { ClipboardContent(type: $0.type, value: $0.data, item: item) }
        try save()
        return item
    }

    func recordUse(_ item: ClipboardItem) throws {
        item.createdAt = .now
        item.numberOfCopies += 1
        try save()
    }

    func delete(_ items: [ClipboardItem]) throws {
        guard !items.isEmpty else { return }
        items.forEach(context.delete)
        try save()
    }

    func edit(_ item: ClipboardItem, alias: String, text: String?) throws {
        item.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, ClipboardRules.isContentEditable(item), text != ClipboardRules.plainText(from: item.payloads) {
            item.storedContents.forEach(context.delete)
            let payload = ClipboardPayload(type: ClipboardRules.Kind.string, data: Data(text.utf8))
            item.contents = [ClipboardContent(type: payload.type, value: payload.data, item: item)]
            item.title = ClipboardRules.title(for: [payload])
        }
        try save()
    }

    func togglePin(_ item: ClipboardItem) throws {
        item.pinned.toggle()
        if item.pinned {
            item.pinOrder = (try all().filter(\.pinned).map(\.pinOrder).max() ?? -1) + 1
        } else {
            item.pinOrder = 0
            item.pinKey = nil
        }
        try save()
    }

    func movePins(from offsets: IndexSet, to destination: Int) throws {
        var pins = try all().filter(\.pinned).sorted { $0.pinOrder < $1.pinOrder }
        let moving = offsets.sorted().compactMap { pins.indices.contains($0) ? pins[$0] : nil }
        guard !moving.isEmpty else { return }
        let insertion = destination - offsets.filter { $0 < destination }.count
        offsets.sorted(by: >).forEach { if pins.indices.contains($0) { pins.remove(at: $0) } }
        pins.insert(contentsOf: moving, at: min(max(0, insertion), pins.count))
        for (index, item) in pins.enumerated() { item.pinOrder = Double(index) }
        try save()
    }

    @discardableResult
    func trim(count: Int, megabytes: Int) throws -> [UUID] {
        let items = try all().sorted { $0.createdAt < $1.createdAt }
        let unpinned = items.filter { !$0.pinned }
        let byCount = ClipboardRules.deletionCount(total: items.count, unpinned: unpinned.count, limit: count)
        let remaining = Array(unpinned.dropFirst(byCount))
        let sizes = remaining.map(ClipboardRules.byteSize(of:))
        let pinnedSize = items.filter(\.pinned).reduce(Int64(0)) { $0 + ClipboardRules.byteSize(of: $1) }
        let bySize = ClipboardRules.deletionCountForSize(
            unpinnedSizesOldestFirst: sizes,
            totalBytes: pinnedSize + sizes.reduce(0, +), limitBytes: Int64(megabytes) * 1_048_576
        )
        let removed = Array(unpinned.prefix(byCount)) + remaining.prefix(bySize)
        let ids = removed.map(\.identifier)
        try delete(removed)
        return ids
    }

    func all() throws -> [ClipboardItem] {
        try context.fetch(FetchDescriptor<ClipboardItem>())
    }

    func save() throws {
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    private func latest() throws -> ClipboardItem? {
        var descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
