import AppKit
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

    @Test(arguments: [false, true])
    func reusingHistoryMovesItToMostRecentWithoutDuplicatingIt(pinned: Bool) throws {
        let (container, monitor, item) = try makeEditFixture()
        let originalDate = Date(timeIntervalSince1970: 100)
        item.createdAt = originalDate
        item.firstCopiedAt = originalDate
        item.numberOfCopies = 3
        item.pinned = pinned
        item.pinKey = pinned ? "Q" : nil
        item.pinOrder = 2
        let originalPayloads = item.payloads
        try container.mainContext.save()

        monitor.recordUse(of: item)
        monitor.recordUse(of: item)

        let readContext = ModelContext(container)
        let items = try readContext.fetch(FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        let saved = try #require(items.first)
        #expect(items.count == 2)
        #expect(saved.identifier == item.identifier)
        #expect(saved.createdAt > originalDate)
        #expect(saved.firstCopiedAt == originalDate)
        #expect(saved.numberOfCopies == 5)
        #expect(saved.pinned == pinned)
        #expect(saved.pinKey == (pinned ? "Q" : nil))
        #expect(saved.pinOrder == 2)
        #expect(saved.alias == "Original alias")
        #expect(saved.payloads == originalPayloads)
        #expect(try readContext.fetchCount(FetchDescriptor<ClipboardContent>()) == 1)
        #expect(!container.mainContext.hasChanges)
    }

    @Test func deletingSelectionSavesOnceAndPreservesOtherThumbnails() async throws {
        let (container, monitor, _) = try makeEditFixture()
        let context = container.mainContext
        let targets = try context.fetch(FetchDescriptor<ClipboardItem>())
        let remaining = ClipboardItem(title: "Keep", contents: [
            ClipboardContent(type: ClipboardRules.Kind.png, value: Data([0x89, 0x50])),
        ])
        context.insert(remaining)
        try context.save()
        let thumbnail = NSImage(size: NSSize(width: 8, height: 8))
        ThumbnailCache.store(thumbnail, id: remaining.identifier, maxSide: 80)

        await confirmation("Batch deletion saves once", expectedCount: 1) { saved in
            let observer = NotificationCenter.default.addObserver(
                forName: ModelContext.didSave, object: context, queue: nil
            ) { _ in saved() }
            defer { NotificationCenter.default.removeObserver(observer) }
            monitor.delete(targets)
        }

        let readContext = ModelContext(container)
        let stored = try readContext.fetch(FetchDescriptor<ClipboardItem>())
        #expect(stored.map(\.identifier) == [remaining.identifier])
        #expect(try readContext.fetchCount(FetchDescriptor<ClipboardContent>()) == 1)
        #expect(!context.hasChanges)
        #expect(ThumbnailCache.cached(id: remaining.identifier, maxSide: 80) === thumbnail)
    }

    @Test(arguments: [
        (limit: 4, megabytes: 0, titles: ["Pinned", "Old", "Middle", "New"]),
        (limit: 3, megabytes: 0, titles: ["Pinned", "Middle", "New"]),
        (limit: 4, megabytes: 4, titles: ["Pinned", "Middle", "New"]),
        (limit: 4, megabytes: 3, titles: ["Pinned", "New"]),
        (limit: 3, megabytes: 3, titles: ["Pinned", "New"]),
        (limit: 1, megabytes: 0, titles: ["Pinned"]),
        (limit: 4, megabytes: 1, titles: ["Pinned"]),
        (limit: 4, megabytes: 5, titles: ["Pinned", "Old", "Middle", "New"]),
    ])
    func trimmingHonorsCountAndSizeLimits(
        _ testCase: (limit: Int, megabytes: Int, titles: [String])
    ) throws {
        let (container, settings, monitor) = try makeHistoryFixture()
        settings.historySizeLimitMB = testCase.megabytes
        for (index, title) in ["Pinned", "Old", "Middle", "New"].enumerated() {
            let bytes = (index == 0 ? 2 : 1) * 1024 * 1024
            container.mainContext.insert(ClipboardItem(
                createdAt: Date(timeIntervalSince1970: Double(index)),
                title: title, pinned: index == 0,
                contents: [ClipboardContent(type: ClipboardRules.Kind.png, value: Data(repeating: 0, count: bytes))]
            ))
        }
        try container.mainContext.save()

        withExtendedLifetime(monitor) {
            settings.historyLimit = testCase.limit
        }

        let readContext = ModelContext(container)
        let remaining = try readContext.fetch(FetchDescriptor<ClipboardItem>())
        #expect(Set(remaining.map(\.title)) == Set(testCase.titles))
        #expect(try readContext.fetchCount(FetchDescriptor<ClipboardContent>()) == remaining.count)
        #expect(!container.mainContext.hasChanges)
    }

    private func makeHistoryFixture() throws -> (ModelContainer, AppSettings, ClipboardMonitor) {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let defaults = try #require(UserDefaults(suiteName: "ClipCVTests.\(UUID().uuidString)"))
        let settings = AppSettings(defaults: defaults)
        return (container, settings, ClipboardMonitor(context: container.mainContext, settings: settings))
    }

    private func makeEditFixture() throws -> (ModelContainer, ClipboardMonitor, ClipboardItem) {
        let (container, _, monitor) = try makeHistoryFixture()
        let context = container.mainContext
        let item = ClipboardItem(
            title: "Original text", alias: "Original alias", pinned: true, pinKey: "Q",
            contents: [ClipboardContent(type: ClipboardRules.Kind.string, value: Data("Original text".utf8))]
        )
        context.insert(item)
        context.insert(ClipboardItem(title: "Other item", pinned: true, pinKey: "W"))
        try context.save()
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
