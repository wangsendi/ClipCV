import UIKit

@MainActor
@Observable
final class ClipboardMonitor {
    private let settings: iOSSettings
    private let history: HistoryStore
    private let pasteboard: UIPasteboard
    private var timer: Timer?
    private var changeCount = -1
    var needsPermission = false
    var storageFailed = false
    var onChange: (() -> Void)?

    init(settings: iOSSettings, history: HistoryStore, pasteboard: UIPasteboard = .general) {
        self.settings = settings
        self.history = history
        self.pasteboard = pasteboard
    }

    func update(active: Bool) {
        timer?.invalidate()
        timer = nil
        guard active, settings.hasStarted, !settings.paused, !needsPermission else { return }
        poll()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func retryPermission(active: Bool) {
        needsPermission = false
        changeCount = -1
        update(active: active)
    }

    func noteOwnWrite() { changeCount = pasteboard.changeCount }

    private func poll() {
        guard !settings.paused, !needsPermission, pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        let types = Set(pasteboard.types)
        guard !ClipboardRules.shouldIgnore(types: types) else { return }
        var received = false
        var remainingBytes = 64 * 1_048_576
        do {
            for index in (0..<min(pasteboard.numberOfItems, 32)).reversed() {
                let result = readItem(at: index, budget: &remainingBytes)
                received = received || result.received
                if accepts(result.payloads) { _ = try history.capture(result.payloads) }
            }
            storageFailed = false
            if received { onChange?() }
        } catch { storageFailed = true }
        if !received, !types.isDisjoint(with: settings.enabledTypes) {
            needsPermission = true
            timer?.invalidate()
            timer = nil
        }
    }

    private func readItem(at index: Int, budget: inout Int) -> (payloads: [ClipboardPayload], received: Bool) {
        let indexSet = IndexSet(integer: index)
        let types = Set(pasteboard.types(forItemSet: indexSet)?.flatMap { $0 } ?? [])
        guard !types.contains(ClipboardRules.Kind.fileURL) else { return ([], true) }
        let wanted = types.intersection(settings.enabledTypes)
        let imageType = ClipboardRules.imageTypes.first { wanted.contains($0) }
        var received = false
        var payloads: [ClipboardPayload] = []
        for type in wanted.sorted() {
            if ClipboardRules.isImageType(type), type != imageType { continue }
            guard let data = pasteboard.data(forPasteboardType: type, inItemSet: indexSet)?.first else { continue }
            received = true
            guard data.count <= budget else { continue }
            budget -= data.count
            payloads.append(ClipboardPayload(type: type, data: data))
        }
        return (payloads, received)
    }

    private func accepts(_ payloads: [ClipboardPayload]) -> Bool {
        if payloads.contains(where: { ClipboardRules.isImageType($0.type) }) { return settings.saveImages }
        if payloads.contains(where: { $0.type == ClipboardRules.Kind.rtf || $0.type == ClipboardRules.Kind.html }) {
            return settings.saveRichText
        }
        guard let text = ClipboardRules.plainText(from: payloads) else { return false }
        let scheme = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme?.lowercased()
        return ["http", "https", "mailto"].contains(scheme ?? "") ? settings.saveLinks : settings.saveText
    }
}
