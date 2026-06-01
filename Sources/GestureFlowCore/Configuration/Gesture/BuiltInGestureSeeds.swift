import Foundation

public enum BuiltInGestureSeeds {

    // MARK: - Stable IDs

    public static let closeWindowID  = UUID(uuidString: "A7C4E1B2-3D5F-4A89-9C0E-1F2A3B4C5D6E")!
    public static let backID         = UUID(uuidString: "B1A2C3D4-E5F6-4A01-B234-567890ABCDE1")!
    public static let forwardID      = UUID(uuidString: "B1A2C3D4-E5F6-4A02-B234-567890ABCDE2")!
    public static let newTabID       = UUID(uuidString: "B1A2C3D4-E5F6-4A03-B234-567890ABCDE3")!
    public static let refreshID      = UUID(uuidString: "B1A2C3D4-E5F6-4A04-B234-567890ABCDE4")!
    public static let minimizeID     = UUID(uuidString: "B1A2C3D4-E5F6-4A05-B234-567890ABCDE5")!
    public static let undoID         = UUID(uuidString: "B1A2C3D4-E5F6-4A06-B234-567890ABCDE6")!
    public static let redoID         = UUID(uuidString: "B1A2C3D4-E5F6-4A07-B234-567890ABCDE7")!
    public static let copyID         = UUID(uuidString: "B1A2C3D4-E5F6-4A08-B234-567890ABCDE8")!
    public static let pasteID        = UUID(uuidString: "B1A2C3D4-E5F6-4A09-B234-567890ABCDE9")!
    public static let findID         = UUID(uuidString: "B1A2C3D4-E5F6-4A0A-B234-567890ABCDEA")!
    public static let quitAppID      = UUID(uuidString: "B1A2C3D4-E5F6-4A0B-B234-567890ABCDEB")!

    public static let chromeScrollToTopID      = UUID(uuidString: "C4B0E2A1-7D3F-4C01-9A8B-1E2F3A4B5C61")!
    public static let chromeScrollToBottomID   = UUID(uuidString: "C4B0E2A1-7D3F-4C02-9A8B-1E2F3A4B5C62")!
    public static let chromeReopenClosedTabID  = UUID(uuidString: "C4B0E2A1-7D3F-4C03-9A8B-1E2F3A4B5C63")!
    public static let chromeFocusAddressBarID  = UUID(uuidString: "C4B0E2A1-7D3F-4C04-9A8B-1E2F3A4B5C64")!

    public static let finderParentFolderID = UUID(uuidString: "F1D2E3A4-5B6C-4F01-8D9E-0A1B2C3D4E71")!
    public static let finderOpenItemID     = UUID(uuidString: "F1D2E3A4-5B6C-4F02-8D9E-0A1B2C3D4E72")!
    public static let finderNewFolderID    = UUID(uuidString: "F1D2E3A4-5B6C-4F03-8D9E-0A1B2C3D4E73")!

    public static let allIDs: Set<UUID> = [
        closeWindowID, backID, forwardID, newTabID, refreshID, minimizeID,
        undoID, redoID, copyID, pasteID, findID, quitAppID,
        chromeScrollToTopID, chromeScrollToBottomID, chromeReopenClosedTabID, chromeFocusAddressBarID,
        finderParentFolderID, finderOpenItemID, finderNewFolderID,
    ]

    // MARK: - Bundle Identifiers

    private static let chrome = "com.google.Chrome"
    private static let finder = "com.apple.finder"

    // MARK: - macOS Virtual Key Codes

    private enum Key {
        static let w: UInt16        = 13
        static let t: UInt16        = 17
        static let r: UInt16        = 15
        static let m: UInt16        = 46
        static let z: UInt16        = 6
        static let c: UInt16        = 8
        static let v: UInt16        = 9
        static let f: UInt16        = 3
        static let q: UInt16        = 12
        static let l: UInt16        = 37
        static let n: UInt16        = 45
        static let leftBracket: UInt16  = 33
        static let rightBracket: UInt16 = 30
        static let upArrow: UInt16      = 126
        static let downArrow: UInt16    = 125
    }

    // MARK: - Factory

    public static func factoryGestures() -> [GestureDefinition] {
        globalGestures + chromeGestures + finderGestures
    }

    public static func factoryBuiltinConfiguration() -> GestureConfiguration {
        GestureConfiguration(
            applicationBundleIdentifiers: [chrome, finder],
            gestures: factoryGestures()
        )
    }

    // MARK: - Global

    private static let globalGestures: [GestureDefinition] = [
        // ← Back  ⌘[
        GestureDefinition(
            id: backID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            shortcut: KeyboardShortcutAction(keyCode: Key.leftBracket, modifiers: [.command])
        ),
        // → Forward  ⌘]
        GestureDefinition(
            id: forwardID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.right]),
            shortcut: KeyboardShortcutAction(keyCode: Key.rightBracket, modifiers: [.command])
        ),
        // ↓→ Close Window  ⌘W
        GestureDefinition(
            id: closeWindowID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            shortcut: KeyboardShortcutAction(keyCode: Key.w, modifiers: [.command])
        ),
        // ↑→ New Tab  ⌘T
        GestureDefinition(
            id: newTabID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up, .right]),
            shortcut: KeyboardShortcutAction(keyCode: Key.t, modifiers: [.command])
        ),
        // ←→ Refresh  ⌘R
        GestureDefinition(
            id: refreshID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left, .right]),
            shortcut: KeyboardShortcutAction(keyCode: Key.r, modifiers: [.command])
        ),
        // ↓← Minimize  ⌘M
        GestureDefinition(
            id: minimizeID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .left]),
            shortcut: KeyboardShortcutAction(keyCode: Key.m, modifiers: [.command])
        ),
        // →← Undo  ⌘Z
        GestureDefinition(
            id: undoID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.right, .left]),
            shortcut: KeyboardShortcutAction(keyCode: Key.z, modifiers: [.command])
        ),
        // ↓↑ Redo  ⌘⇧Z
        GestureDefinition(
            id: redoID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .up]),
            shortcut: KeyboardShortcutAction(keyCode: Key.z, modifiers: [.command, .shift])
        ),
        // →↓ Copy  ⌘C
        GestureDefinition(
            id: copyID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.right, .down]),
            shortcut: KeyboardShortcutAction(keyCode: Key.c, modifiers: [.command])
        ),
        // →↑ Paste  ⌘V
        GestureDefinition(
            id: pasteID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.right, .up]),
            shortcut: KeyboardShortcutAction(keyCode: Key.v, modifiers: [.command])
        ),
        // ↓→↑ Find  ⌘F
        GestureDefinition(
            id: findID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right, .up]),
            shortcut: KeyboardShortcutAction(keyCode: Key.f, modifiers: [.command])
        ),
        // ↓→↓ Quit App  ⌘Q
        GestureDefinition(
            id: quitAppID,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right, .down]),
            shortcut: KeyboardShortcutAction(keyCode: Key.q, modifiers: [.command])
        ),
    ]

    // MARK: - Chrome

    private static let chromeGestures: [GestureDefinition] = [
        // ↑ Scroll to Top  ⌘↑
        GestureDefinition(
            id: chromeScrollToTopID,
            targetBundleIdentifier: chrome,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up]),
            shortcut: KeyboardShortcutAction(keyCode: Key.upArrow, modifiers: [.command])
        ),
        // ↓ Scroll to Bottom  ⌘↓
        GestureDefinition(
            id: chromeScrollToBottomID,
            targetBundleIdentifier: chrome,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down]),
            shortcut: KeyboardShortcutAction(keyCode: Key.downArrow, modifiers: [.command])
        ),
        // ↑← Reopen Closed Tab  ⌘⇧T
        GestureDefinition(
            id: chromeReopenClosedTabID,
            targetBundleIdentifier: chrome,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up, .left]),
            shortcut: KeyboardShortcutAction(keyCode: Key.t, modifiers: [.command, .shift])
        ),
        // ↑←↓ Focus Address Bar  ⌘L
        GestureDefinition(
            id: chromeFocusAddressBarID,
            targetBundleIdentifier: chrome,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up, .left, .down]),
            shortcut: KeyboardShortcutAction(keyCode: Key.l, modifiers: [.command])
        ),
    ]

    // MARK: - Finder

    private static let finderGestures: [GestureDefinition] = [
        // ↑ Parent Folder  ⌘↑
        GestureDefinition(
            id: finderParentFolderID,
            targetBundleIdentifier: finder,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up]),
            shortcut: KeyboardShortcutAction(keyCode: Key.upArrow, modifiers: [.command])
        ),
        // ↓ Open Item  ⌘↓
        GestureDefinition(
            id: finderOpenItemID,
            targetBundleIdentifier: finder,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down]),
            shortcut: KeyboardShortcutAction(keyCode: Key.downArrow, modifiers: [.command])
        ),
        // ↑← New Folder  ⌘⇧N
        GestureDefinition(
            id: finderNewFolderID,
            targetBundleIdentifier: finder,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.up, .left]),
            shortcut: KeyboardShortcutAction(keyCode: Key.n, modifiers: [.command, .shift])
        ),
    ]
}
