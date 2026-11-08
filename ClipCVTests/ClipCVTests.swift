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
