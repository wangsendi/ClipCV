//
//  ClipCVTests.swift
//  ClipCVTests
//
//  Created by wsd on 2026/11/7.
//

import Foundation
import SwiftData
import Testing
@testable import ClipCV

@MainActor
struct ClipCVTests {
    @Test func testRuntimeDoesNotStartCaptureOrOpenDiskStorage() {
        #expect(AppRuntime.isRunningTests)
        #expect(AppRuntime.monitor == nil)
        let usesMemoryStorage = AppRuntime.container.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(usesMemoryStorage)
    }

    @Test func sharedTestSettingsDoNotWriteApplicationPreferences() throws {
        let domain = try #require(Bundle.main.bundleIdentifier)
        let defaults = UserDefaults.standard
        let original = defaults.persistentDomain(forName: domain) ?? [:]
        let settings = AppSettings.shared
        let paused = settings.paused
        let sync = settings.iCloudSyncEnabled
        defer {
            settings.paused = paused
            settings.iCloudSyncEnabled = sync
        }

        settings.paused.toggle()
        settings.iCloudSyncEnabled.toggle()

        let current = defaults.persistentDomain(forName: domain) ?? [:]
        #expect(current["paused"] as? Bool == original["paused"] as? Bool)
        #expect(current["iCloudSyncEnabled"] as? Bool == original["iCloudSyncEnabled"] as? Bool)
    }

    @Test(arguments: [" w ", "12"])
    func rejectedEditsPreserveStoredItem(pinKey: String) throws {
        let (container, monitor, item) = try makeEditFixture()
        let context = container.mainContext
        let originalPayloads = item.payloads

        let result = monitor.applyEdit(item, alias: "", content: "Updated text", pinKey: pinKey)

        #expect(result == (pinKey == "12" ? .pinKeyInvalid : .pinKeyTaken))
        #expect(item.alias == "Original alias")
        #expect(item.title == "Original text")
        #expect(item.pinKey == "Q")
        #expect(item.payloads == originalPayloads)
        #expect(!context.hasChanges)

        // Later saves must not persist any part of the rejected edit.
        try context.save()
        let readContext = ModelContext(container)
        let stored = try readContext.fetch(FetchDescriptor<ClipboardItem>())
        let saved = try #require(stored.first { $0.identifier == item.identifier })
        #expect(saved.alias == "Original alias")
        #expect(saved.title == "Original text")
        #expect(saved.pinKey == "Q")
        #expect(saved.payloads == originalPayloads)
        #expect(try readContext.fetchCount(FetchDescriptor<ClipboardContent>()) == 1)
    }

    @Test(arguments: [" q ", " e ", " ", nil] as [String?])
    func acceptedEditsPersistContentAndPinKey(pinKey: String?) throws {
        let (container, monitor, item) = try makeEditFixture()

        let result = monitor.applyEdit(
            item, alias: " Updated alias ", content: "Updated text", pinKey: pinKey
        )

        #expect(result == .saved)
        #expect(!container.mainContext.hasChanges)
        let readContext = ModelContext(container)
        let stored = try readContext.fetch(FetchDescriptor<ClipboardItem>())
        let saved = try #require(stored.first { $0.identifier == item.identifier })
        let expectedKey = pinKey?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        #expect(saved.pinKey == (expectedKey == "" ? nil : expectedKey))
        #expect(saved.alias == "Updated alias")
        #expect(saved.payloads == [
            ClipboardPayload(type: ClipboardRules.Kind.string, data: Data("Updated text".utf8)),
        ])
        #expect(try readContext.fetchCount(FetchDescriptor<ClipboardContent>()) == 1)
    }

    private func makeEditFixture() throws -> (ModelContainer, ClipboardMonitor, ClipboardItem) {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let item = ClipboardItem(
            title: "Original text", alias: "Original alias", pinned: true, pinKey: "Q",
            contents: [ClipboardContent(type: ClipboardRules.Kind.string, value: Data("Original text".utf8))]
        )
        context.insert(item)
        context.insert(ClipboardItem(title: "Other item", pinned: true, pinKey: "W"))
        try context.save()
        let defaults = try #require(UserDefaults(suiteName: "ClipCVTests.\(UUID().uuidString)"))
        let monitor = ClipboardMonitor(context: context, settings: AppSettings(defaults: defaults))
        return (container, monitor, item)
    }
}

@MainActor
struct ModelContainerTests {
    @Test func syncConfigurationsUseTheSameStore() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let local = AppModelContainer.configuration(in: directory, sync: false)
        let cloud = AppModelContainer.configuration(in: directory, sync: true)

        #expect(local.url == cloud.url)
        #expect(local.cloudKitContainerIdentifier == nil)
        #expect(cloud.cloudKitContainerIdentifier == AppModelContainer.cloudKitContainerID)
    }

    @Test func localHistorySurvivesReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipCVTests-\(ProcessInfo.processInfo.processIdentifier)")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID()

        // SwiftData may close SQLite asynchronously; leave fixture cleanup to the system.
        try autoreleasepool {
            let container = AppModelContainer.make(in: directory, sync: false)
            let context = ModelContext(container)
            context.insert(ClipboardItem(identifier: id, title: "New history"))
            try context.save()
        }
        try autoreleasepool {
            let reopened = AppModelContainer.make(in: directory, sync: false)
            let saved = try ModelContext(reopened).fetch(FetchDescriptor<ClipboardItem>())
            #expect(saved.count == 1)
            #expect(saved.first?.identifier == id)
            #expect(saved.first?.title == "New history")
            #expect(!AppModelContainer.isCloudKitEnabled)
        }
    }
}
