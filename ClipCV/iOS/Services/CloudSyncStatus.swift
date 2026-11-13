import CloudKit
import CoreData
import Observation

@MainActor
@Observable
final class CloudSyncStatus {
    let enabled: Bool
    var accountAvailable: Bool?
    var lastTransferAt: Date?
    var failed = false
    var transferring = false
    private var activeEvents = Set<UUID>()
    private var eventObserver: NSObjectProtocol?

    init(enabled: Bool) {
        self.enabled = enabled
        guard enabled else { return }
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated { self?.receive(event) }
        }
    }

    func refresh() async {
        guard enabled else { return }
        accountAvailable = (try? await CKContainer(identifier: AppModelContainer.cloudKitContainerID).accountStatus()) == .available
    }

    private func receive(_ event: NSPersistentCloudKitContainer.Event) {
        guard event.type != .setup else { return }
        if event.endDate == nil { activeEvents.insert(event.identifier) }
        else { activeEvents.remove(event.identifier) }
        transferring = !activeEvents.isEmpty
        if event.endDate != nil {
            failed = !event.succeeded
            if event.succeeded { lastTransferAt = event.endDate }
        }
    }
}
