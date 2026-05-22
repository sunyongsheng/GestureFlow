import Foundation

public struct GestureDefinition: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var trigger: GestureTrigger
    public var signature: GestureSignature
    public var action: GestureAction
    public var scope: GestureScope

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        trigger: GestureTrigger,
        signature: GestureSignature,
        action: GestureAction,
        scope: GestureScope = .global
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.signature = signature
        self.action = action
        self.scope = scope
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
}

public enum GestureScope: Codable, Equatable {
    case global
}

public enum GestureAction: Codable, Equatable {
    case keyboardShortcut(KeyboardShortcutAction)
    case openApplication(OpenApplicationAction)
    case openURL(OpenURLAction)
    case systemCommand(SystemCommandAction)
}

public struct KeyboardShortcutAction: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: [KeyboardModifier]

    public init(keyCode: UInt16, modifiers: [KeyboardModifier]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum KeyboardModifier: String, Codable, Equatable {
    case command
    case option
    case control
    case shift
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
    static let defaults: [GestureDefinition] = [
        GestureDefinition(
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .keyboardShortcut(KeyboardShortcutAction(keyCode: 123, modifiers: [.command]))
        ),
        GestureDefinition(
            name: "Forward",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.right]),
            action: .keyboardShortcut(KeyboardShortcutAction(keyCode: 124, modifiers: [.command]))
        )
    ]
}
