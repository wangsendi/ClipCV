import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppRuntime {
    let container: ModelContainer
    let settings: iOSSettings
    let history: HistoryStore
    let monitor: ClipboardMonitor
    let limits: HistoryLimitSync
    let cloud: CloudSyncStatus
    let isPreview: Bool
    let syncAtLaunch: Bool
    var storageFailed = false
    private var active = false

    init() {
        isPreview = ProcessInfo.processInfo.arguments.contains("--design-preview") || NSClassFromString("XCTestCase") != nil
        let defaults = isPreview ? UserDefaults(suiteName: "ClipCV.iOS.DesignPreview")! : .standard
        if isPreview { defaults.removePersistentDomain(forName: "ClipCV.iOS.DesignPreview") }
        settings = iOSSettings(defaults: defaults)
        syncAtLaunch = settings.syncEnabled
        container = isPreview ? Self.memoryContainer() : AppModelContainer.make()
        history = HistoryStore(context: container.mainContext)
        monitor = ClipboardMonitor(settings: settings, history: history)
        cloud = CloudSyncStatus(enabled: !isPreview && AppModelContainer.isCloudKitEnabled)
        limits = HistoryLimitSync(enabled: !isPreview && AppModelContainer.isCloudKitEnabled)
        limits.onReceive = { [weak self] count, megabytes in
            self?.settings.historyLimit = count
            self?.settings.historySizeLimitMB = megabytes
        }
        limits.onReady = { [weak self] in self?.didChangeHistory() }
        limits.start()
        monitor.onChange = { [weak self] in self?.didChangeHistory() }
        if isPreview {
            settings.hasStarted = true
            PreviewHistory.insert(into: history)
        }
    }

    func setActive(_ active: Bool) {
        self.active = active
        if !isPreview { monitor.update(active: active) }
        if active {
            publishKeyboardSnapshot()
            Task { await cloud.refresh() }
        }
    }

    func updateRecording() {
        if !isPreview { monitor.update(active: active) }
    }

    func start() {
        settings.hasStarted = true
        settings.paused = false
        if !isPreview { monitor.retryPermission(active: active) }
    }

    func perform(_ operation: () throws -> Void) {
        do { try operation(); storageFailed = false; didChangeHistory() }
        catch { storageFailed = true }
    }

    @discardableResult
    func copy(_ item: ClipboardItem, plain: Bool = false) -> Bool {
        guard !ClipboardRules.isFileItem(item) else { return false }
        let payloads = plain ? ClipboardRules.payloadsRemovingFormatting(item.payloads) : item.payloads
        guard isPreview || ClipboardWriter.write(payloads) else { return false }
        monitor.noteOwnWrite()
        perform { try history.recordUse(item) }
        return true
    }

    func copyText(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let payload = ClipboardPayload(type: ClipboardRules.Kind.string, data: Data(text.utf8))
        guard isPreview || ClipboardWriter.write([payload]) else { return false }
        monitor.noteOwnWrite()
        return true
    }

    func updateLimits() {
        limits.publish(count: settings.historyLimit, megabytes: settings.historySizeLimitMB)
        didChangeHistory()
    }

    func didChangeHistory() {
        if limits.allowsAutomaticTrim {
            do { try history.trim(count: settings.historyLimit, megabytes: settings.historySizeLimitMB) }
            catch { storageFailed = true }
        }
        publishKeyboardSnapshot()
    }

    func publishKeyboardSnapshot() {
        guard !isPreview, let url = KeyboardSnapshot.url(), let items = try? history.all() else { return }
        let sorted = items.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.pinned ? $0.pinOrder < $1.pinOrder : $0.createdAt > $1.createdAt
        }
        let entries = sorted.lazy.filter { !$0.hasImage && !ClipboardRules.isFileItem($0) }.compactMap { item -> KeyboardEntry? in
            guard let text = ClipboardRules.plainText(from: item.payloads), text.utf8.count <= KeyboardSnapshot.maximumTextBytes else { return nil }
            return KeyboardEntry(id: item.identifier, title: item.displayTitle, text: text, pinned: item.pinned)
        }.prefix(KeyboardSnapshot.maximumEntries)
        try? KeyboardSnapshot.write(Array(entries), to: url)
    }

    private static func memoryContainer() -> ModelContainer {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        return try! ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
        ])
    }
}
