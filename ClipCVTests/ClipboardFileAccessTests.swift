import AppKit
import SwiftData
import Testing
@testable import ClipCV

@MainActor
struct ClipboardFileAccessTests {
    @Test(arguments: [false, true])
    func separateFileRecordsSurviveClipboardReplacementAndReopening(plain: Bool) throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.captureFiles()
        let records = try fixture.records()
        #expect(records.count == 2)
        #expect(try fixture.bookmarkFiles().count == 2)
        let reopened = ClipboardFileAccess(directory: fixture.bookmarks)

        for record in records {
            fixture.pasteboard.clearContents()
            fixture.pasteboard.setString("overwritten", forType: .string)
            let payloads = plain ? ClipboardRules.payloadsRemovingFormatting(record.payloads) : record.payloads
            #expect(reopened.write(payloads, for: record.identifier, to: fixture.pasteboard))

            #expect(fixture.pasteboard.pasteboardItems?.count == 1)
            #expect(fixture.pasteboard.pasteboardItems?.first?.types.first == .fileURL)
            let urls = try #require(fixture.pasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
            ) as? [URL])
            #expect(urls.count == 1)
            #expect(try Data(contentsOf: #require(urls.first)) == Data("fixture".utf8))
            #expect(fixture.pasteboard.string(forType: .string) == record.payloads.first {
                $0.type == ClipboardRules.Kind.string
            }.map { String(decoding: $0.data, as: UTF8.self) })
        }
        fixture.pasteboard.clearContents()
        reopened.releaseIfNeeded()
    }

    @Test func recopyingRefreshesAuthorizationWithoutDuplicatingTheRecord() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.copyToSource(fixture.files[0])
        fixture.monitor.capture(from: fixture.pasteboard)
        let record = try #require(fixture.records().first)
        fixture.access.remove(record.identifier)

        fixture.monitor.capture(from: fixture.pasteboard)

        #expect(try fixture.records().count == 1)
        #expect(record.numberOfCopies == 2)
        #expect(try fixture.bookmarkFiles().count == 1)
        let reopened = ClipboardFileAccess(directory: fixture.bookmarks)
        #expect(reopened.write(record.payloads, for: record.identifier, to: fixture.pasteboard))
    }

    @Test(arguments: [false, true])
    func deletingOrTrimmingHistoryRemovesOnlyItsBookmarks(trim: Bool) throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.captureFiles()
        let records = try fixture.records()
        let removed = try #require(records.first)
        let kept = try #require(records.last)

        if trim {
            fixture.settings.historyLimit = 1
        } else {
            fixture.monitor.delete([removed])
        }

        #expect(try fixture.records().map(\.identifier) == [kept.identifier])
        #expect(try fixture.bookmarkFiles().map { $0.deletingPathExtension().lastPathComponent } == [
            kept.identifier.uuidString,
        ])
    }

    @Test func pruningAndContentReplacementRemoveUnusedBookmarks() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.captureFiles()
        let records = try fixture.records()
        let kept = try #require(records.first)
        fixture.access.prune(keeping: [kept.identifier])
        #expect(try fixture.bookmarkFiles().count == 1)

        let result = fixture.monitor.applyEdit(kept, alias: "", content: "text", pinKey: nil)

        #expect(result == .saved)
        #expect(try fixture.bookmarkFiles().isEmpty)
        #expect(ClipboardRules.fileURLs(from: kept.payloads).isEmpty)
    }

    @Test(arguments: [false, true])
    func unavailableAuthorizationLeavesClipboardUntouched(missingFile: Bool) throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.copyToSource(fixture.files[0])
        fixture.monitor.capture(from: fixture.pasteboard)
        let record = try #require(fixture.records().first)
        if missingFile {
            try FileManager.default.removeItem(at: fixture.files[0])
        } else {
            fixture.access.remove(record.identifier)
        }
        fixture.pasteboard.clearContents()
        fixture.pasteboard.setString("keep me", forType: .string)
        let count = fixture.pasteboard.changeCount

        #expect(!fixture.access.write(record.payloads, for: record.identifier, to: fixture.pasteboard))

        #expect(fixture.pasteboard.changeCount == count)
        #expect(fixture.pasteboard.string(forType: .string) == "keep me")
    }

    @MainActor
    private struct Fixture {
        let root: URL
        let files: [URL]
        let bookmarks: URL
        let pasteboard = NSPasteboard.withUniqueName()
        let container: ModelContainer
        let settings: AppSettings
        let access: ClipboardFileAccess
        let monitor: ClipboardMonitor

        init() throws {
            let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            self.root = root
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            files = ["中文 100%.docx", "second.txt"].map { root.appendingPathComponent($0) }
            for file in files { try Data("fixture".utf8).write(to: file) }
            bookmarks = root.appendingPathComponent("bookmarks", isDirectory: true)
            access = ClipboardFileAccess(directory: bookmarks)
            let schema = Schema([ClipboardItem.self, ClipboardContent.self])
            container = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
            ])
            settings = AppSettings(defaults: try #require(UserDefaults(suiteName: UUID().uuidString)))
            monitor = ClipboardMonitor(context: container.mainContext, settings: settings, fileAccess: access)
        }

        func captureFiles() {
            for file in files {
                copyToSource(file)
                monitor.capture(from: pasteboard)
            }
        }

        func copyToSource(_ file: URL) {
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            item.setString(file.absoluteString, forType: .fileURL)
            item.setString(file.lastPathComponent, forType: .string)
            pasteboard.writeObjects([item])
        }

        func records() throws -> [ClipboardItem] {
            try container.mainContext.fetch(FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt)]))
        }

        func bookmarkFiles() throws -> [URL] {
            try FileManager.default.contentsOfDirectory(at: bookmarks, includingPropertiesForKeys: nil)
        }

        func cleanUp() {
            pasteboard.clearContents()
            access.releaseIfNeeded()
            pasteboard.releaseGlobally()
            try? FileManager.default.removeItem(at: root)
        }
    }
}
