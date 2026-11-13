import Foundation
import SwiftUI

enum DeveloperPreviewKind: Equatable, Sendable {
    case plain, json, markdown
}

enum DeveloperPreview {
    // Full JSON highlight / Markdown parse on huge blobs stalls selection.
    nonisolated private static let maxRenderCharacters = 120_000

    nonisolated static func kind(of text: String) -> DeveloperPreviewKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Avoid full JSON parse on the main thread for huge blobs.
        if trimmed.first == "{" || trimmed.first == "[" {
            if trimmed.count > 64_000 || isJSON(trimmed) { return .json }
        }
        if looksLikeMarkdown(trimmed) { return .markdown }
        return .plain
    }

    nonisolated static func rawAttributed(_ text: String) -> AttributedString {
        var plain = AttributedString(text)
        plain.font = .system(size: 12, design: .monospaced)
        return plain
    }

    nonisolated static func renderedAttributed(from text: String, kind: DeveloperPreviewKind) -> AttributedString {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.count > maxRenderCharacters
            ? String(trimmed.prefix(maxRenderCharacters)) + "\n…"
            : trimmed
        switch kind {
        case .json:
            return highlightedJSON(from: source) ?? rawAttributed(source)
        case .markdown:
            return markdown(from: source) ?? rawAttributed(source)
        case .plain:
            return rawAttributed(source)
        }
    }

    nonisolated private static func isJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    nonisolated private static func highlightedJSON(from text: String) -> AttributedString? {
        guard text.first == "{" || text.first == "[",
              let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: prettyData, encoding: .utf8)
        else { return nil }

        var result = AttributedString(pretty)
        result.font = .system(size: 12, design: .monospaced)
        let full = NSRange(location: 0, length: (pretty as NSString).length)
        let rules: [(String, Color)] = [
            (#""(?:\\.|[^"\\])*"(?=\s*:)"#, Color.purple.opacity(0.9)),
            (#"(?<![\\w$])"(?:\\.|[^"\\])*""#, Color.green.opacity(0.85)),
            (#"\b-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .orange),
            (#"\b(?:true|false|null)\b"#, .pink),
        ]
        rules.forEach { pattern, color in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            regex.matches(in: pretty, range: full).forEach { match in
                guard let range = Range(match.range, in: pretty),
                      let lower = AttributedString.Index(range.lowerBound, within: result),
                      let upper = AttributedString.Index(range.upperBound, within: result)
                else { return }
                result[lower..<upper].foregroundColor = color
            }
        }
        return result
    }

    nonisolated private static func markdown(from text: String) -> AttributedString? {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        guard var attributed = try? AttributedString(markdown: text, options: options) else { return nil }
        attributed.font = .system(size: 12)
        return attributed
    }

    nonisolated private static func looksLikeMarkdown(_ text: String) -> Bool {
        let signalPrefixes = ["#", "```", "> ", "- ", "* ", "1. ", "|"]
        let head = text.prefix(8_000)
        let signals = head.split(whereSeparator: \.isNewline).prefix(40).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return signalPrefixes.contains { trimmed.hasPrefix($0) } || trimmed.contains("](")
        }
        if signals.count >= 2 || head.contains("```") { return true }
        if head.range(of: #"^\s{0,3}#{1,6}\s+\S"#, options: .regularExpression) != nil { return true }
        return head.count > 40
            && head.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression) != nil
    }
}
