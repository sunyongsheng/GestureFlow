import AppKit
import GestureFlowCore

enum GestureShortcutFormatting {
    static func displayString(for shortcut: KeyboardShortcutAction) -> String {
        guard shortcut.isRecorded else {
            return "点击录制"
        }

        let modifierSymbols = shortcut.modifiers.map(symbol(for:)).joined()
        let keySymbol = keySymbol(for: shortcut.keyCode)
        return modifierSymbols + keySymbol
    }

    static func captureShortcut(from event: NSEvent) -> KeyboardShortcutAction? {
        guard let characters = event.charactersIgnoringModifiers?.uppercased(),
              let firstCharacter = characters.first,
              !firstCharacter.isWhitespace else {
            return nil
        }

        guard let keyCode = keyCode(for: firstCharacter) else {
            return nil
        }

        var modifiers: [KeyboardModifier] = []
        if event.modifierFlags.contains(.command) {
            modifiers.append(.command)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.append(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.append(.control)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.append(.shift)
        }

        return KeyboardShortcutAction(keyCode: keyCode, modifiers: modifiers)
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

    private static func keyCode(for character: Character) -> UInt16? {
        switch character {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "O": return 31
        case "U": return 32
        case "I": return 34
        case "P": return 35
        case "L": return 37
        case "J": return 38
        case "K": return 40
        case "N": return 45
        case "M": return 46
        default:
            return nil
        }
    }
}
