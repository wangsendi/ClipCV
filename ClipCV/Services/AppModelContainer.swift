//
//  AppModelContainer.swift
//  ClipCV
//

import Foundation
import SwiftData

enum AppModelContainer {
    static let cloudKitContainerID = "iCloud.wangsendi.ClipCV"
    /// Snapshot of the sync preference used when the store was opened.
    private(set) static var isCloudKitEnabled = false

    static func make() -> ModelContainer {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipCV", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        let sync = UserDefaults.standard.bool(forKey: AppSettings.iCloudSyncDefaultsKey)
        isCloudKitEnabled = sync
        let storeName = sync ? "clipboard-icloud-v1.store" : "clipboard-v3.store"
        let storeURL = support.appendingPathComponent(storeName)
        let cloudKit: ModelConfiguration.CloudKitDatabase = sync ? .private(cloudKitContainerID) : .none
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: cloudKit)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // Corrupt store: wipe matching files then recreate.
        let prefix = storeURL.lastPathComponent
        let directory = storeURL.deletingLastPathComponent()
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .forEach { try? FileManager.default.removeItem(at: $0) }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // CloudKit misconfiguration: fall back to local-only so the app still launches.
            if sync {
                isCloudKitEnabled = false
                let localURL = support.appendingPathComponent("clipboard-v3.store")
                let local = ModelConfiguration(schema: schema, url: localURL, cloudKitDatabase: .none)
                if let container = try? ModelContainer(for: schema, configurations: [local]) {
                    return container
                }
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
