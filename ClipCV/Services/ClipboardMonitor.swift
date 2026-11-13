import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardMonitor {
    let fileAccess: ClipboardFileAccess
    private let limits: HistoryLimitSync
    private let history: HistoryStore
    private let context: ModelContext
    private let settings: AppSettings
    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?

    init(context: ModelContext, settings: AppSettings, fileAccess: ClipboardFileAccess? = nil) {
        self.limits = HistoryLimitSync(enabled: !AppRuntime.isRunningTests && AppModelContainer.isCloudKitEnabled)
        self.history = HistoryStore(context: context)
        self.context = context
        self.settings = settings
        self.fileAccess = fileAccess ?? ClipboardFileAccess()
        settings.onHistoryLimitChanged = { [weak self] _ in self?.updateLimits() }
        limits.onReceive = { [weak self] count, megabytes in
            self?.settings.historyLimit = count
            self?.settings.historySizeLimitMB = megabytes
        }
        limits.onReady = { [weak self] in
            self?.trimIfNeeded()
            self?.save()
        }
        limits.start()
        settings.onPinKeyOrderChanged = { [weak self] _ in
            self?.reassignPinKeys()
        }
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        pruneFileBookmarks()
        ensurePinOrders()
        reassignPinKeys(onlyFillMissing: true)
    }

    func notePasteboardChangedByUs() {
        fileAccess.releaseIfNeeded()
        changeCount = NSPasteboard.general.changeCount
    }

    func recordUse(of item: ClipboardItem) {
        // Our pasteboard writes skip polling, so reuse must update the existing record directly.
        item.createdAt = .now
        item.numberOfCopies += 1
        save()
    }

    func delete(_ items: [ClipboardItem]) {
        guard !items.isEmpty else { return }
        items.forEach(remove)
        save()
    }

    private func remove(_ item: ClipboardItem) {
        fileAccess.remove(item.identifier)
        context.delete(item)
    }

    private func pruneFileBookmarks() {
        var descriptor = FetchDescriptor<ClipboardItem>()
        descriptor.propertiesToFetch = [\.identifier]
        guard let items = try? context.fetch(descriptor) else { return }
        fileAccess.prune(keeping: Set(items.map(\.identifier)))
    }

    @discardableResult
    func applyEdit(
        _ item: ClipboardItem,
        alias: String,
        content: String?,
        pinKey: String?
    ) -> ApplyEditResult {
        // A rejected key must leave the item's alias and contents unchanged.
        var validatedPinKey: String?
        if item.pinned {
            let trimmed = pinKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                guard let key = HotkeyFormatting.normalizePinKey(trimmed) else { return .pinKeyInvalid }
                let taken = fetchAll().contains {
                    $0.identifier != item.identifier && $0.pinned && $0.pinKey == key
                }
                if taken { return .pinKeyTaken }
                validatedPinKey = key
            }
        }

        item.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if let content { replaceContent(of: item, with: content) }
        if item.pinned { item.pinKey = validatedPinKey }
        save()
        return .saved
    }

    // Keep content replacement and its file authorization cleanup together.
    private func replaceContent(of item: ClipboardItem, with content: String) {
        fileAccess.remove(item.identifier)
        item.storedContents.forEach(context.delete)
        let payload = ClipboardPayload(type: ClipboardRules.Kind.string, data: Data(content.utf8))
        item.contents = [ClipboardContent(type: payload.type, value: payload.data, item: item)]
        if item.alias.isEmpty { item.title = ClipboardRules.title(for: [payload]) }
    }

    func togglePin(_ item: ClipboardItem) {
        item.pinned.toggle()
        if item.pinned {
            let items = fetchAll()
            let maxOrder = items.filter(\.pinned).map(\.pinOrder).max() ?? -1
            item.pinOrder = maxOrder + 1
            item.pinKey = HotkeyFormatting.nextPinKey(
                used: Set(items.compactMap(\.pinKey)),
                order: settings.pinKeyOrder
            )
        } else {
            item.pinKey = nil
            item.pinOrder = 0
        }
        save()
    }

    func reorderPins(moving: UUID, before: UUID) {
        let pins = fetchAll().filter(\.pinned).sorted { $0.pinOrder < $1.pinOrder }
        let ids = pins.map(\.identifier)
        guard let ordered = PinOrder.moving(ids, moving: moving, before: before) else { return }
        let byID = Dictionary(uniqueKeysWithValues: pins.map { ($0.identifier, $0) })
        renumberPinOrders(ordered.compactMap { byID[$0] })
    }

    private func ensurePinOrders() {
        let pinned = fetchAll().filter(\.pinned)
        guard !pinned.isEmpty else { return }
        let orders = pinned.map(\.pinOrder)
        let needsRenumber = Set(orders).count != orders.count
            || (pinned.count > 1 && orders.allSatisfy { $0 == 0 })
        guard needsRenumber else { return }
        let sorted = pinned.sorted {
            if $0.pinOrder != $1.pinOrder { return $0.pinOrder < $1.pinOrder }
            return $0.firstCopiedAt < $1.firstCopiedAt
        }
        renumberPinOrders(sorted)
    }

    private func renumberPinOrders(_ pins: [ClipboardItem]) {
        for (index, item) in pins.enumerated() where item.pinOrder != Double(index) {
            item.pinOrder = Double(index)
        }
        save()
    }

    private func reassignPinKeys(onlyFillMissing: Bool = false) {
        let pinned = fetchAll()
            .filter(\.pinned)
            .sorted { $0.pinOrder < $1.pinOrder }
        guard !pinned.isEmpty else { return }

        var used = Set<String>()
        var changed = false
        for item in pinned {
            if onlyFillMissing, let existing = item.pinKey, !existing.isEmpty {
                used.insert(existing)
                continue
            }
            guard let key = HotkeyFormatting.nextPinKey(used: used, order: settings.pinKeyOrder) else {
                guard item.pinKey != nil else { continue }
                item.pinKey = nil
                changed = true
                continue
            }
            used.insert(key)
            guard item.pinKey != key else { continue }
            item.pinKey = key
            changed = true
        }
        if changed { save() }
    }

    func clear(includingPinned: Bool) {
        delete(fetchAll().filter { includingPinned || !$0.pinned })
        guard settings.clearSystemClipboard else { return }
        NSPasteboard.general.clearContents()
        notePasteboardChangedByUs()
    }

    func clearUnpinnedOnQuit() {
        guard settings.clearOnQuit else { return }
        clear(includingPinned: false)
    }

    private func poll() {
        fileAccess.releaseIfNeeded()
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        if settings.ignoreNext {
            settings.ignoreNext = false
            return
        }
        guard !settings.paused else { return }
        capture(from: pasteboard)
    }

    func capture(from pasteboard: NSPasteboard) {
        guard let capture = readPasteboardCapture(from: pasteboard) else { return }
        upsert(capture)
    }

    private struct PasteboardCapture {
        var payloads: [ClipboardPayload]
        var source: String?
    }

    private func readPasteboardCapture(from pasteboard: NSPasteboard) -> PasteboardCapture? {
        let boardTypes = Set((pasteboard.types ?? []).map(\.rawValue))
        guard !settings.shouldIgnore(pasteboardTypes: boardTypes) else { return nil }

        let source = ClipboardRules.sourceBundleID(from: pasteboard)
        guard !settings.shouldIgnore(sourceApp: source) else { return nil }

        // Only fetch types we persist — probing proprietary pasteboard types triggers NSXPC decode warnings.
        let wanted = settings.enabledTypes.intersection(ClipboardRules.supportedTypes)
        let grouped = (pasteboard.pasteboardItems ?? []).map { item in
            wanted.compactMap { raw -> ClipboardPayload? in
                let type = NSPasteboard.PasteboardType(raw)
                guard item.types.contains(type), let data = item.data(forType: type) else { return nil }
                return ClipboardPayload(type: raw, data: data)
            }
        }
        let payloads = ClipboardRules.prepareForStorage(
            ClipboardRules.normalize(grouped, enabled: wanted),
            scalePercent: settings.imageStorageScalePercent
        )
        guard !payloads.isEmpty else { return nil }

        let title = ClipboardRules.title(for: payloads)
        guard !settings.shouldIgnore(title: title) else { return nil }
        return PasteboardCapture(payloads: payloads, source: source)
    }

    private func upsert(_ capture: PasteboardCapture) {
        guard let record = try? history.capture(capture.payloads, source: capture.source) else { return }
        fileAccess.capture(capture.payloads, for: record.identifier)
        trimIfNeeded()
        save()
        guard record.modelContext != nil, let imageData = record.imagePayloadData else { return }
        enrichImageItem(id: record.identifier, imageData: imageData)
    }

    private func enrichImageItem(id: UUID, imageData: Data) {
        Task.detached(priority: .utility) {
            if let thumb = ThumbnailCache.make(from: imageData, maxSide: 80) {
                ThumbnailCache.store(thumb, id: id, maxSide: 80)
            }
        }
    }

    /// On-demand OCR from the preview toolbar — not run for every new image.
    func recognizeOCR(for item: ClipboardItem) async -> String? {
        let existing = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existing.isEmpty { return existing }
        guard let data = item.imagePayloadData else { return nil }
        let itemID = item.identifier
        guard let text = await OCRService.recognizeText(in: data), !text.isEmpty else { return nil }
        applyOCR(text, to: itemID)
        return text
    }

    private func applyOCR(_ text: String, to id: UUID) {
        guard let item = item(with: id) else { return }
        item.ocrText = text
        if ClipboardRules.isGenericImageTitle(item.title),
           let title = ClipboardRules.collapsedTitle(from: text) {
            item.title = title
        }
        save()
    }

    private func item(with id: UUID) -> ClipboardItem? {
        try? context.fetch(FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.identifier == id })).first
    }

    private func fetchAll() -> [ClipboardItem] {
        (try? context.fetch(FetchDescriptor<ClipboardItem>())) ?? []
    }

    private func updateLimits() {
        limits.publish(count: settings.historyLimit, megabytes: settings.historySizeLimitMB)
        trimIfNeeded()
        save()
    }

    private func trimIfNeeded() {
        guard limits.allowsAutomaticTrim else { return }
        let descriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        guard let all = try? context.fetch(descriptor) else { return }

        let unpinned = all.filter { !$0.pinned }
        let byCount = ClipboardRules.deletionCount(
            total: all.count,
            unpinned: unpinned.count,
            limit: settings.historyLimit
        )
        unpinned.prefix(byCount).forEach(remove)

        let sizeLimitMB = settings.historySizeLimitMB
        guard sizeLimitMB > 0 else { return }
        let remaining = Array(unpinned.dropFirst(byCount))
        let unpinnedSizes = remaining.map(ClipboardRules.byteSize(of:))
        let pinnedBytes = all.lazy.filter(\.pinned).reduce(Int64(0)) {
            $0 + ClipboardRules.byteSize(of: $1)
        }
        let totalBytes = pinnedBytes + unpinnedSizes.reduce(0, +)
        let limitBytes = Int64(sizeLimitMB) * 1024 * 1024
        let bySize = ClipboardRules.deletionCountForSize(
            unpinnedSizesOldestFirst: unpinnedSizes,
            totalBytes: totalBytes,
            limitBytes: limitBytes
        )
        remaining.prefix(bySize).forEach(remove)
    }

    private func save() {
        try? context.save()
    }
}

enum PinOrder {
    static func moving(_ ids: [UUID], moving: UUID, before: UUID) -> [UUID]? {
        guard moving != before else { return ids }
        var pins = ids
        guard let fromIndex = pins.firstIndex(of: moving) else { return nil }
        pins.remove(at: fromIndex)
        if let toIndex = pins.firstIndex(of: before) {
            pins.insert(moving, at: toIndex)
        } else {
            pins.append(moving)
        }
        return pins
    }
}
