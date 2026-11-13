import SwiftData
import Testing
import UIKit
@testable import ClipCViOS

@MainActor
struct ClipboardTests {
    @Test func capturesDeduplicatesAndPauses() throws {
        let fixture = try CaptureFixture()
        defer { fixture.close() }
        fixture.set("hello")
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().count == 1)
        fixture.set("hello")
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().first?.numberOfCopies == 2)
        fixture.settings.paused = true
        fixture.set("paused")
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().count == 1)
        fixture.settings.paused = false
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().count == 2)
    }

    @Test func blanksAndUnsupportedContentDoNotBecomePermissionFailures() throws {
        let fixture = try CaptureFixture()
        defer { fixture.close() }
        fixture.set(" \n ")
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().isEmpty)
        #expect(!fixture.monitor.needsPermission)
        fixture.board.setItems([["example.unsupported": Data([1])]])
        fixture.monitor.update(active: true)
        #expect(!fixture.monitor.needsPermission)
    }

    @Test func urlOnlyAndMultipleItemsKeepOriginalOrder() throws {
        let fixture = try CaptureFixture()
        defer { fixture.close() }
        fixture.board.setItems([
            [ClipboardRules.Kind.url: Data("https://example.com/first".utf8)],
            [ClipboardRules.Kind.string: Data("second".utf8)],
        ])
        fixture.monitor.update(active: true)
        let items = try fixture.history.all().sorted { $0.createdAt > $1.createdAt }
        #expect(items.count == 2)
        #expect(ClipboardRules.plainText(from: items[0].payloads) == "https://example.com/first")
        #expect(ClipboardRules.isWebLinkItem(items[0]))
    }

    @Test func ownWritesAndFilesNeverBecomeFilenameText() throws {
        let fixture = try CaptureFixture()
        defer { fixture.close() }
        let original = [ClipboardPayload(type: ClipboardRules.Kind.string, data: Data("hello".utf8))]
        #expect(ClipboardWriter.write(original, to: fixture.board))
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().isEmpty)
        let file = ClipboardPayload(type: ClipboardRules.Kind.fileURL, data: Data("file:///tmp/report.docx".utf8))
        #expect(!ClipboardWriter.write(original + [file], to: fixture.board))
        fixture.board.setItems([[file.type: file.data, original[0].type: original[0].data]])
        fixture.monitor.update(active: true)
        #expect(try fixture.history.all().isEmpty)
    }

    @Test func richTextExtractionDoesNotExposeScripts() {
        let html = "<style>secret</style><script>secret</script><p>Hello &amp; goodbye</p><img src='https://example.com/tracker'>"
        let text = ClipboardRules.plainText(from: [.init(type: ClipboardRules.Kind.html, data: Data(html.utf8))])
        #expect(text?.contains("Hello & goodbye") == true)
        #expect(text?.contains("secret") == false)
    }
}

@MainActor
private struct CaptureFixture {
    let suite = "ClipCV.CaptureTests.\(UUID())"
    let settings: iOSSettings
    let container: ModelContainer
    let history: HistoryStore
    let monitor: ClipboardMonitor
    let board = UIPasteboard.withUniqueName()

    init() throws {
        settings = iOSSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.hasStarted = true
        let schema = Schema([ClipboardItem.self, ClipboardContent.self])
        container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
        ])
        history = HistoryStore(context: container.mainContext)
        monitor = ClipboardMonitor(settings: settings, history: history, pasteboard: board)
    }

    func set(_ text: String) { board.setItems([[ClipboardRules.Kind.string: Data(text.utf8)]]) }
    func close() {
        monitor.update(active: false)
        UIPasteboard.remove(withName: board.name)
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}
