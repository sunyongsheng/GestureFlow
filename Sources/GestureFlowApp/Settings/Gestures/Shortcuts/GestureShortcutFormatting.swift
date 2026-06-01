import AppKit
import GestureFlowCore

enum GestureShortcutFormatting {
    static func displayString(for shortcut: KeyboardShortcutAction) -> String {
        guard shortcut.isRecorded else {
            return AppServices.localization.string(.shortcutClickToRecord)
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
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥"
        case 49: return "␣"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "⎋"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return "Key\(keyCode)"
        }
    }
}
