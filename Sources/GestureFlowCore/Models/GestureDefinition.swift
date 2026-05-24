import Foundation

public struct GestureDefinition: Codable, Equatable, Identifiable {
    public var id: UUID
    public var targetBundleIdentifier: String?
    public var name: String
    public var isEnabled: Bool
    public var trigger: GestureTrigger
    public var signature: GestureSignature
    public var shortcut: KeyboardShortcutAction

    public init(
        id: UUID = UUID(),
        targetBundleIdentifier: String? = nil,
        name: String,
        isEnabled: Bool = true,
        trigger: GestureTrigger,
        signature: GestureSignature,
        shortcut: KeyboardShortcutAction
    ) {
        self.id = id
        self.targetBundleIdentifier = targetBundleIdentifier
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.signature = signature
        self.shortcut = shortcut
    }
}

public enum GestureTrigger: String, Codable, Equatable, CaseIterable {
    case rightMouse
    case middleMouse
}

public struct GestureSignature: Codable, Equatable, Hashable {
    public var tokens: [GestureDirection]

    public init(tokens: [GestureDirection]) {
        self.tokens = tokens
    }
}

public enum GestureDirection: String, Codable, Equatable, Hashable, CaseIterable {
    case up = "U"
    case down = "D"
    case left = "L"
    case right = "R"

    public var chineseDisplayName: String {
        switch self {
        case .up:
            return "上"
        case .down:
            return "下"
        case .left:
            return "左"
        case .right:
            return "右"
        }
    }
}

public extension GestureSignature {
    var chineseDisplayName: String {
        tokens.map(\.chineseDisplayName).joined(separator: "、")
    }
}

public struct KeyboardShortcutAction: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: [KeyboardModifier]

    public init(keyCode: UInt16, modifiers: [KeyboardModifier]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Recorded shortcuts always include at least one modifier (e.g. ⌘A uses keyCode 0).
    public var isRecorded: Bool {
        !modifiers.isEmpty
    }
}

public enum KeyboardModifier: String, Codable, Equatable, CaseIterable {
    case command
    case option
    case control
    case shift
}

public enum GestureAction: Codable, Equatable {
    case keyboardShortcut(KeyboardShortcutAction)
    case openApplication(OpenApplicationAction)
    case openURL(OpenURLAction)
    case systemCommand(SystemCommandAction)
}

public struct OpenApplicationAction: Codable, Equatable {
    public var bundleIdentifier: String

    public init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct OpenURLAction: Codable, Equatable {
    public var url: URL

    public init(url: URL) {
        self.url = url
    }
}

public enum SystemCommandAction: String, Codable, Equatable {
    case showDesktop
    case lockScreen
}

public extension GestureDefinition {
    static var builtInCloseWindow: GestureDefinition {
        GestureDefinition(
            id: GestureConfiguration.closeWindowGestureID,
            targetBundleIdentifier: nil,
            name: "关闭窗口",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            shortcut: KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
        )
    }
}
