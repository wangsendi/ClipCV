import Foundation

enum SearchService {
    // Pasting huge JSON into the search field would otherwise freeze the main thread.
    private static let maxKeywordLength = 512
    private static let maxFuzzyLength = 64

    static func matches(_ item: ClipboardItem, query: String, mode: SearchMode) -> Bool {
        matches(haystacks: haystacks(for: item), query: query, mode: mode)
    }

    static func matches(haystacks: [String], query: String, mode: SearchMode) -> Bool {
        let keyword = normalizedKeyword(query)
        guard !keyword.isEmpty else { return true }
        let effective = effectiveMode(mode, keyword: keyword)
        switch effective {
        case .exact:
            return haystacks.contains { $0.localizedCaseInsensitiveContains(keyword) }
        case .fuzzy:
            return haystacks.contains { !fuzzyRanges(in: $0, pattern: keyword).isEmpty }
        case .regexp:
            return haystacks.contains { regexp($0, keyword) }
        case .mixed:
            return haystacks.contains {
                $0.localizedCaseInsensitiveContains(keyword)
                    || !fuzzyRanges(in: $0, pattern: keyword).isEmpty
            }
        }
    }

    static func highlightRanges(
        in display: String,
        query: String,
        mode: SearchMode
    ) -> [Range<String.Index>] {
        let keyword = normalizedKeyword(query)
        guard !keyword.isEmpty else { return [] }
        let effective = effectiveMode(mode, keyword: keyword)

        switch effective {
        case .exact:
            return display.range(of: keyword, options: .caseInsensitive).map { [$0] } ?? []
        case .mixed:
            if let range = display.range(of: keyword, options: .caseInsensitive) { return [range] }
            return fuzzyRanges(in: display, pattern: keyword)
        case .fuzzy:
            return fuzzyRanges(in: display, pattern: keyword)
        case .regexp:
            guard let regex = try? NSRegularExpression(pattern: keyword, options: [.caseInsensitive]) else {
                return display.range(of: keyword, options: .caseInsensitive).map { [$0] } ?? []
            }
            let nsRange = NSRange(display.startIndex..<display.endIndex, in: display)
            return regex.matches(in: display, range: nsRange).compactMap { Range($0.range, in: display) }
        }
    }

    private static func normalizedKeyword(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxKeywordLength else { return trimmed }
        return String(trimmed.prefix(maxKeywordLength))
    }

    private static func effectiveMode(_ mode: SearchMode, keyword: String) -> SearchMode {
        // Fuzzy over a long needle is O(needle × haystack) per item — force exact.
        if keyword.count > maxFuzzyLength, mode == .fuzzy || mode == .mixed { return .exact }
        return mode
    }

    private static func haystacks(for item: ClipboardItem) -> [String] {
        [
            item.alias,
            item.title,
            item.sourceApp,
            item.ocrText,
            ClipboardRules.plainText(from: item.payloads),
        ]
        .compactMap { $0 }.filter { !$0.isEmpty }
    }

    private static func fuzzyRanges(in text: String, pattern: String) -> [Range<String.Index>] {
        guard pattern.count <= maxFuzzyLength else { return [] }
        let lowerText = text.lowercased()
        let lowerPattern = pattern.lowercased()
        var ranges: [Range<String.Index>] = []
        var index = lowerText.startIndex
        for character in lowerPattern {
            guard let found = lowerText[index...].firstIndex(of: character) else { return [] }
            let source = text.index(text.startIndex, offsetBy: lowerText.distance(from: lowerText.startIndex, to: found))
            ranges.append(source..<text.index(after: source))
            index = lowerText.index(after: found)
        }
        return ranges
    }

    private static func regexp(_ text: String, _ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.localizedCaseInsensitiveContains(pattern)
        }
        return regex.firstMatch(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ) != nil
    }
}
