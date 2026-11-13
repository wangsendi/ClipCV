import Foundation
import SwiftData
import Testing
#if os(iOS)
@testable import ClipCViOS
#else
@testable import ClipCV
#endif

@MainActor
struct SharedHistoryTests {
    private let container: ModelContainer

    init() throws {
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
        ])
    }

    @Test func aliasOnlyEditsPreserveOriginalRepresentations() throws {
        let history = makeHistory()
        let payloads = [
            ClipboardPayload(type: ClipboardRules.Kind.string, data: Data("Original".utf8)),
            ClipboardPayload(type: ClipboardRules.Kind.html, data: Data("<b>Original</b>".utf8)),
        ]
        let item = try #require(try history.capture(payloads))
        try history.edit(item, alias: "Name", text: "Original")
        #expect(item.payloads.sorted { $0.type < $1.type } == payloads.sorted { $0.type < $1.type })
        try history.edit(item, alias: "Name", text: "Edited")
        #expect(item.payloads == [.init(type: ClipboardRules.Kind.string, data: Data("Edited".utf8))])
    }

    @Test func reuseMovesRecentItemButKeepsPinOrder() throws {
        let history = makeHistory()
        let first = try #require(try history.capture([.init(type: ClipboardRules.Kind.string, data: Data("first".utf8))]))
        let second = try #require(try history.capture([.init(type: ClipboardRules.Kind.string, data: Data("second".utf8))]))
        try history.togglePin(first)
        let order = first.pinOrder
        try history.recordUse(first)
        #expect(first.createdAt > second.createdAt)
        #expect(first.numberOfCopies == 2)
        #expect(first.pinOrder == order)
    }

    @Test func trimmingPreservesPinsEvenIfTheyExceedSizeLimit() throws {
        let history = makeHistory()
        let pin = try #require(try history.capture([.init(type: ClipboardRules.Kind.png, data: Data(repeating: 1, count: 2_097_152))]))
        try history.togglePin(pin)
        let removable = try #require(try history.capture([.init(type: ClipboardRules.Kind.string, data: Data("remove".utf8))]))
        let removed = try history.trim(count: 1, megabytes: 1)
        #expect(removed == [removable.identifier])
        #expect(try history.all().map(\.identifier) == [pin.identifier])
    }

    @Test func keyboardSnapshotIsBoundedAndPreservesUnicode() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let text = String(repeating: "你好👨‍👩‍👧‍👦", count: 100)
        let valid = KeyboardEntry(id: UUID(), title: "Reply", text: text, pinned: true)
        let tooLong = KeyboardEntry(id: UUID(), title: "Long", text: String(repeating: "🌊", count: 3_000), pinned: false)
        try KeyboardSnapshot.write([tooLong] + Array(repeating: valid, count: 80), to: url)
        let saved = KeyboardSnapshot.read(from: url)
        #expect(saved.count <= KeyboardSnapshot.maximumEntries)
        #expect(saved.allSatisfy { $0.text == text })
        #expect(try Data(contentsOf: url).count <= KeyboardSnapshot.maximumFileBytes)
        try Data(repeating: 0, count: KeyboardSnapshot.maximumFileBytes + 1).write(to: url)
        #expect(KeyboardSnapshot.read(from: url).isEmpty)
    }

    @Test func cloudLimitsWaitForAnExistingOrExplicitPolicy() {
        #expect(HistoryLimitSync.limits(from: nil) == nil)
        #expect(HistoryLimitSync.limits(from: ["count": 0, "megabytes": 300]) == nil)
        #expect(HistoryLimitSync.limits(from: ["count": 999, "megabytes": -1]) == nil)
        let limits = HistoryLimitSync.limits(from: ["count": 500, "megabytes": 1_024])
        #expect(limits?.count == 500)
        #expect(limits?.megabytes == 1_024)
        #expect(!HistoryLimitSync(enabled: true).allowsAutomaticTrim)
        #expect(HistoryLimitSync(enabled: false).allowsAutomaticTrim)
    }

    private func makeHistory() -> HistoryStore {
        HistoryStore(context: container.mainContext)
    }
}
