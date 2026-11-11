import AppKit
import Carbon
import Foundation

struct Hotkey: Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt

    static let popupDefault = Hotkey(keyCode: 0x08, modifiers: NSEvent.ModifierFlags.command.union(.shift).rawValue)
    static let pinDefault = Hotkey(keyCode: 0x23, modifiers: NSEvent.ModifierFlags.option.rawValue)
    static let deleteDefault = Hotkey(keyCode: 0x33, modifiers: NSEvent.ModifierFlags.option.rawValue)
    static let previewDefault = Hotkey(keyCode: 0x31, modifiers: NSEvent.ModifierFlags.control.rawValue)
    static let none = Hotkey(keyCode: .max, modifiers: 0)

    var flagSet: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if flagSet.contains(.command) { value |= UInt32(cmdKey) }
        if flagSet.contains(.shift) { value |= UInt32(shiftKey) }
        if flagSet.contains(.option) { value |= UInt32(optionKey) }
        if flagSet.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var isCleared: Bool { keyCode == .max }

    var display: String {
        isCleared ? "—" : HotkeyFormatting.string(keyCode: keyCode, modifiers: flagSet)
    }

    func matches(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard !isCleared else { return false }
        let normalized = flags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .shift, .option, .control])
        // Compare only the four modifiers we care about (ignore leftover bits from storage).
        let expected = flagSet.intersection([.command, .shift, .option, .control])
        return self.keyCode == keyCode && expected == normalized
    }
}

enum HotkeyCaptureTarget: Equatable {
    case popup, pin, delete, preview
}

enum HotkeyFormatting {
    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    private static let names: [UInt16: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
        0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
        0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z",
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
        0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
        0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10",
        0x67: "F11", 0x6F: "F12",
    ]

    static func isModifierOnly(_ keyCode: UInt16) -> Bool { modifierKeyCodes.contains(keyCode) }

    static func string(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        [
            modifiers.contains(.control) ? "⌃" : nil,
            modifiers.contains(.option) ? "⌥" : nil,
            modifiers.contains(.shift) ? "⇧" : nil,
            modifiers.contains(.command) ? "⌘" : nil,
            names[keyCode] ?? "键\(keyCode)",
        ].compactMap { $0 }.joined()
    }

    static func letter(for keyCode: UInt16) -> String? {
        guard let name = keyName(for: keyCode),
              let scalar = name.unicodeScalars.first,
              CharacterSet.letters.contains(scalar)
        else { return nil }
        return name
    }

    static func keyName(for keyCode: UInt16) -> String? {
        guard let name = names[keyCode], name.count == 1 else { return nil }
        return name.uppercased()
    }

    static let defaultPinKeyOrder = "QWEASDZXC"
    static let defaultUnpinnedKeyOrder = "1234567890"

    static func normalizePinOrder(_ raw: String) -> String {
        normalizeKeyOrder(raw, allowingDigits: false)
    }

    static func normalizeUnpinnedOrder(_ raw: String) -> String {
        normalizeKeyOrder(raw, allowingDigits: true)
    }

    private static func normalizeKeyOrder(_ raw: String, allowingDigits: Bool) -> String {
        var seen = Set<Character>()
        return String(raw.uppercased().filter { char in
            guard seen.insert(char).inserted else { return false }
            if char.isLetter { return true }
            return allowingDigits && char.isNumber
        })
    }

    static func nextPinKey(used: Set<String>, order: String = defaultPinKeyOrder) -> String? {
        let preferred = normalizePinOrder(order).map(String.init)
        if let key = preferred.first(where: { !used.contains($0) }) { return key }
        return (0x00...0x2E)
            .compactMap { letter(for: UInt16($0)) }
            .first { !used.contains($0) }
    }

    private static let pinKeySymbols = Set(Array("[];'./-=\\"))

    static func normalizePinKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let char = trimmed.first else { return nil }
        if char.isLetter { return String(char).uppercased() }
        if pinKeySymbols.contains(char) { return String(char) }
        return nil
    }

    static func availablePinKeys(used: Set<String>, current: String?, order: String) -> [String] {
        var seen = Set<String>()
        var keys: [String] = []
        func append(_ key: String) {
            guard seen.insert(key).inserted else { return }
            keys.append(key)
        }
        normalizePinOrder(order).forEach { append(String($0)) }
        (0x00...0x2E).compactMap { letter(for: UInt16($0)) }.forEach(append)
        pinKeySymbols.sorted().forEach { append(String($0)) }
        if let current { append(current) }
        return keys.filter { $0 == current || !used.contains($0) }
    }

    static func decoratedShortcut(
        key: String,
        prefix: ShortcutModifierPrefix,
        optionHeld: Bool,
        shiftHeld: Bool,
        commandHeld: Bool
    ) -> String {
        let secondary = prefix.secondaryFlagSet
        let holdingSecondary =
            (secondary == .option && optionHeld && !commandHeld)
            || (secondary == .command && commandHeld && !optionHeld)
        if holdingSecondary {
            let symbol = secondary == .command ? "⌘" : "⌥"
            return shiftHeld ? "\(symbol)⇧\(key)" : "\(symbol)\(key)"
        }
        if prefix == .none {
            return commandHeld ? (shiftHeld ? "⌘⇧\(key)" : "⌘\(key)") : key
        }
        let holdingPrimary = switch prefix {
        case .none: !commandHeld && !optionHeld
        case .command: commandHeld && !optionHeld
        case .option: optionHeld && !commandHeld
        case .control: true
        }
        return shiftHeld && holdingPrimary ? "\(prefix.symbol)⇧\(key)" : "\(prefix.symbol)\(key)"
    }
}

enum ShortcutModifierPrefix: String, CaseIterable, Identifiable, Sendable {
    case none
    case command
    case option
    case control

    var id: Self { self }

    var title: String {
        switch self {
        case .none: L10n.t(.shortcutPrefixNone)
        case .command: "⌘"
        case .option: "⌥"
        case .control: "⌃"
        }
    }

    var symbol: String {
        switch self {
        case .none: ""
        case .command: "⌘"
        case .option: "⌥"
        case .control: "⌃"
        }
    }

    var flagSet: NSEvent.ModifierFlags {
        switch self {
        case .none: []
        case .command: .command
        case .option: .option
        case .control: .control
        }
    }

    // Other of ⌘/⌥ so copy ↔ paste still works with a custom primary prefix.
    var secondaryFlagSet: NSEvent.ModifierFlags {
        self == .option ? .command : .option
    }
}
