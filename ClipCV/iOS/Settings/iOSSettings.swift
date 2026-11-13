import Foundation
import Observation

@MainActor
@Observable
final class iOSSettings {
    private let defaults: UserDefaults
    var hasStarted: Bool { didSet { defaults.set(hasStarted, forKey: "hasStarted") } }
    var paused: Bool { didSet { defaults.set(paused, forKey: "paused") } }
    var saveText: Bool { didSet { defaults.set(saveText, forKey: "saveText") } }
    var saveLinks: Bool { didSet { defaults.set(saveLinks, forKey: "saveLinks") } }
    var saveRichText: Bool { didSet { defaults.set(saveRichText, forKey: "saveRichText") } }
    var saveImages: Bool { didSet { defaults.set(saveImages, forKey: "saveImages") } }
    var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: "historyLimit") } }
    var historySizeLimitMB: Int { didSet { defaults.set(historySizeLimitMB, forKey: "historySizeLimitMB") } }
    var syncEnabled: Bool { didSet { defaults.set(syncEnabled, forKey: "iCloudSyncEnabled") } }
    var language: String { didSet { defaults.set(language, forKey: "language") } }
    var appearance: String { didSet { defaults.set(appearance, forKey: "appearance") } }

    var enabledTypes: Set<String> {
        var types = Set<String>()
        if saveText || saveLinks { types.formUnion([ClipboardRules.Kind.string, ClipboardRules.Kind.url]) }
        if saveRichText { types.formUnion([ClipboardRules.Kind.rtf, ClipboardRules.Kind.html]) }
        if saveImages { types.formUnion(ClipboardRules.imageTypes) }
        return types
    }

    var locale: Locale { language == "system" ? .current : Locale(identifier: language) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "saveText": true, "saveLinks": true, "saveRichText": true, "saveImages": true,
            "historyLimit": 200, "historySizeLimitMB": 300, "language": "system", "appearance": "system",
        ])
        hasStarted = defaults.bool(forKey: "hasStarted")
        paused = defaults.bool(forKey: "paused")
        saveText = defaults.bool(forKey: "saveText")
        saveLinks = defaults.bool(forKey: "saveLinks")
        saveRichText = defaults.bool(forKey: "saveRichText")
        saveImages = defaults.bool(forKey: "saveImages")
        historyLimit = min(999, max(1, defaults.integer(forKey: "historyLimit")))
        historySizeLimitMB = min(10_240, max(0, defaults.integer(forKey: "historySizeLimitMB")))
        syncEnabled = defaults.bool(forKey: "iCloudSyncEnabled")
        language = defaults.string(forKey: "language") ?? "system"
        appearance = defaults.string(forKey: "appearance") ?? "system"
    }
}
