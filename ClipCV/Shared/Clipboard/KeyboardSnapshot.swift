import Foundation

struct KeyboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let text: String
    let pinned: Bool
}

enum KeyboardSnapshot {
    static let groupID = "group.wangsendi.ClipCV"
    static let fileName = "keyboard-history.json"
    static let maximumEntries = 60
    static let maximumTextBytes = 8_192
    static let maximumFileBytes = 524_288

    static func url() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(fileName)
    }

    static func read(from url: URL) -> [KeyboardEntry] {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumFileBytes, let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([KeyboardEntry].self, from: data)
        else { return [] }
        return Array(entries.filter { !$0.text.isEmpty && $0.text.utf8.count <= maximumTextBytes }.prefix(maximumEntries))
    }

    static func write(_ entries: [KeyboardEntry], to url: URL) throws {
        let bounded = entries.lazy.filter { !$0.text.isEmpty && $0.text.utf8.count <= maximumTextBytes }.prefix(maximumEntries).map {
            KeyboardEntry(id: $0.id, title: String($0.title.prefix(80)), text: $0.text, pinned: $0.pinned)
        }
        var result = Array(bounded)
        var data = try JSONEncoder().encode(result)
        while data.count > maximumFileBytes, !result.isEmpty {
            result.removeLast()
            data = try JSONEncoder().encode(result)
        }
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

}
