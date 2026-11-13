import Foundation
import SwiftData

@Model
final class ClipboardItem {
    // Defaults / optional relationships required for CloudKit-backed SwiftData.
    var identifier: UUID = UUID()
    var createdAt: Date = Date.now
    var firstCopiedAt: Date = Date.now
    var numberOfCopies: Int = 1
    var title: String = ""
    var alias: String = ""
    var sourceApp: String?
    var pinned: Bool = false
    var pinKey: String?
    var pinOrder: Double = 0
    var ocrText: String?
    @Relationship(deleteRule: .cascade, inverse: \ClipboardContent.item)
    var contents: [ClipboardContent]? = []

    init(
        identifier: UUID = UUID(),
        createdAt: Date = .now,
        firstCopiedAt: Date? = nil,
        numberOfCopies: Int = 1,
        title: String,
        alias: String = "",
        sourceApp: String? = nil,
        pinned: Bool = false,
        pinKey: String? = nil,
        pinOrder: Double = 0,
        ocrText: String? = nil,
        contents: [ClipboardContent] = []
    ) {
        self.identifier = identifier
        self.createdAt = createdAt
        self.firstCopiedAt = firstCopiedAt ?? createdAt
        self.numberOfCopies = numberOfCopies
        self.title = title
        self.alias = alias
        self.sourceApp = sourceApp
        self.pinned = pinned
        self.pinKey = pinKey
        self.pinOrder = pinOrder
        self.ocrText = ocrText
        self.contents = contents
    }

    var displayTitle: String {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ClipboardRules.localizedTitle(title) : trimmed
    }

    var storedContents: [ClipboardContent] { contents ?? [] }

    var payloads: [ClipboardPayload] {
        storedContents.map { ClipboardPayload(type: $0.type, data: $0.value) }
    }

    var imagePayloadData: Data? {
        storedContents.first(where: {
            ClipboardRules.isImageType($0.type)
        })?.value
    }

    var hasImage: Bool { storedContents.contains { ClipboardRules.isImageType($0.type) } }

    func appendContent(_ content: ClipboardContent) {
        var next = storedContents
        next.append(content)
        contents = next
    }
}

@Model
final class ClipboardContent {
    var type: String = ""
    var value: Data = Data()
    var item: ClipboardItem?

    init(type: String, value: Data, item: ClipboardItem? = nil) {
        self.type = type
        self.value = value
        self.item = item
    }
}
