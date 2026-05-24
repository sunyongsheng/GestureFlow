import AppKit
import GestureFlowCore

enum GestureShortcutFormatting {
    static func displayString(for shortcut: KeyboardShortcutAction) -> String {
        guard shortcut.isRecorded else {
            return "点击录制"
        }

        let modifierSymbols = shortcut.modifiers.map(symbol(for:)).joined(separator: " ")
        let keySymbol = keySymbol(for: shortcut.keyCode)
        return modifierSymbols + " " + keySymbol
    }

    static func captureShortcut(from event: NSEvent) -> KeyboardShortcutAction? {
        guard event.type == .keyDown else { return nil }

        let keyCode = event.keyCode
        if keyCode == 53 || Self.modifierKeyCodes.contains(keyCode) {
            return nil
        }

        let modifiers = modifiers(from: event.modifierFlags)
        guard !modifiers.isEmpty else {
            return nil
        }

        return KeyboardShortcutAction(keyCode: keyCode, modifiers: modifiers)
    }

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61]

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> [KeyboardModifier] {
        var modifiers: [KeyboardModifier] = []
        if flags.contains(.command) {
            modifiers.append(.command)
        }
        if flags.contains(.option) {
            modifiers.append(.option)
        }
        if flags.contains(.control) {
            modifiers.append(.control)
        }
        if flags.contains(.shift) {
            modifiers.append(.shift)
        }
        return modifiers
    }

    private static func symbol(for modifier: KeyboardModifier) -> String {
        switch modifier {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        case .shift:
            return "⇧"
        }
    }

    private static func keySymbol(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        default:
            return "Key\(keyCode)"
        }
    }
}
