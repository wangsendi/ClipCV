import Foundation
import Observation

@MainActor
@Observable
final class HistoryLimitSync {
    static let key = "historyRetentionLimits"
    let enabled: Bool
    private(set) var hasPolicy = false
    private var applying = false
    @ObservationIgnored private lazy var store = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?
    var onReceive: ((Int, Int) -> Void)?
    var onReady: (() -> Void)?

    var allowsAutomaticTrim: Bool { !enabled || (hasPolicy && !applying) }

    init(enabled: Bool) {
        self.enabled = enabled
    }

    func start() {
        guard enabled else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.receive() }
        }
        receive()
        store.synchronize()
    }

    func publish(count: Int, megabytes: Int) {
        guard enabled, !applying else { return }
        store.set(["count": count, "megabytes": megabytes], forKey: Self.key)
        hasPolicy = true
        store.synchronize()
    }

    static func limits(from dictionary: [String: Any]?) -> (count: Int, megabytes: Int)? {
        guard let dictionary, let count = dictionary["count"] as? Int,
              let megabytes = dictionary["megabytes"] as? Int,
              (1...999).contains(count), (0...10_240).contains(megabytes) else { return nil }
        return (count, megabytes)
    }

    private func receive() {
        guard let limits = Self.limits(from: store.dictionary(forKey: Self.key)) else {
            hasPolicy = false
            return
        }
        applying = true
        onReceive?(limits.count, limits.megabytes)
        applying = false
        hasPolicy = true
        onReady?()
    }
}
