import Foundation
import SwiftData

enum AppModelContainer {
    static let cloudKitContainerID = "iCloud.wangsendi.ClipCV"
    static let storeName = "clipboard-v4.store"
    /// Snapshot of the sync preference used when the store was opened.
    private(set) static var isCloudKitEnabled = false

    static func make() -> ModelContainer {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipCV", isDirectory: true)
        let sync = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        return make(in: support, sync: sync)
    }

    static func configuration(in directory: URL, sync: Bool) -> ModelConfiguration {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        let cloudKit: ModelConfiguration.CloudKitDatabase = sync ? .private(cloudKitContainerID) : .none
        return ModelConfiguration(
            schema: schema, url: directory.appendingPathComponent(storeName), cloudKitDatabase: cloudKit
        )
    }

    static func make(in directory: URL, sync: Bool) -> ModelContainer {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        isCloudKitEnabled = sync
        return open(configuration(in: directory, sync: sync), sync: sync)
    }

    // Keep store recovery separate from configuration so sync always uses the same file.
    private static func open(_ config: ModelConfiguration, sync: Bool) -> ModelContainer {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        removeStoreFiles(at: config.url)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // CloudKit misconfiguration: fall back to local-only so the app still launches.
            if sync {
                isCloudKitEnabled = false
                let local = ModelConfiguration(schema: schema, url: config.url, cloudKitDatabase: .none)
                if let container = try? ModelContainer(for: schema, configurations: [local]) {
                    return container
                }
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private static func removeStoreFiles(at url: URL) {
        let files = FileManager.default
        (try? files.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix(url.lastPathComponent) }
            .forEach { try? files.removeItem(at: $0) }
    }
}
