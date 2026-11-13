import UIKit

extension ClipboardRules {
    static func localizedTitle(_ stored: String) -> String {
        let language = UserDefaults.standard.string(forKey: "language") ?? "system"
        let locale = language == "system" ? Locale.current : Locale(identifier: language)
        return switch stored {
        case TitleToken.image: String(localized: "图片", locale: locale)
        case TitleToken.richText: String(localized: "富文本", locale: locale)
        case TitleToken.generic: String(localized: "剪贴板内容", locale: locale)
        default: stored
        }
    }

    static func plainText(from contents: [ClipboardPayload]) -> String? {
        if let text = stringText(from: contents) { return text }
        for (type, documentType) in [(Kind.rtf, NSAttributedString.DocumentType.rtf), (Kind.html, .html)] {
            guard var data = contents.first(where: { $0.type == type })?.data else { continue }
            guard data.count <= 2 * 1_048_576 else { continue }
            if type == Kind.html { data = safeHTMLText(data) }
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: documentType, .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            if let text = nonEmpty((try? NSAttributedString(data: data, options: options, documentAttributes: nil))?.string) {
                return text
            }
        }
        return nil
    }

    private static func safeHTMLText(_ data: Data) -> Data {
        var text = String(data: data, encoding: .utf8) ?? ""
        text = text.replacingOccurrences(of: #"(?is)<(script|style)\b[^>]*>.*?</\1\s*>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)</?(p|div|br|li|h[1-6])\b[^>]*>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        return Data("<pre>\(text)</pre>".utf8)
    }
}
