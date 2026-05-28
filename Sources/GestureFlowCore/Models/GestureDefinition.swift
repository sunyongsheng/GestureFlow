import Foundation

public struct GestureDefinition: Codable, Equatable, Identifiable {
    public var id: UUID
    public var targetBundleIdentifier: String?
    public var name: String?
    public var isEnabled: Bool
    public var trigger: GestureTrigger
    public var signature: GestureSignature
    public var shortcut: KeyboardShortcutAction
    public var source: GestureSource

    private enum CodingKeys: String, CodingKey {
        case id
        case targetBundleIdentifier
        case name
        case isEnabled
        case trigger
        case signature
        case shortcut
    }

    public init(
        id: UUID = UUID(),
        targetBundleIdentifier: String? = nil,
        name: String? = nil,
        isEnabled: Bool = true,
        trigger: GestureTrigger,
        signature: GestureSignature,
        shortcut: KeyboardShortcutAction,
        source: GestureSource = .custom
    ) {
        self.id = id
        self.targetBundleIdentifier = targetBundleIdentifier
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.signature = signature
        self.shortcut = shortcut
        self.source = source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        targetBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .targetBundleIdentifier)
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
        name = decodedName.flatMap { $0.isEmpty ? nil : $0 }
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        trigger = try container.decode(GestureTrigger.self, forKey: .trigger)
        signature = try container.decode(GestureSignature.self, forKey: .signature)
        shortcut = try container.decode(KeyboardShortcutAction.self, forKey: .shortcut)
        source = .custom
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(targetBundleIdentifier, forKey: .targetBundleIdentifier)
        if let name, !name.isEmpty {
            try container.encode(name, forKey: .name)
        }
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(signature, forKey: .signature)
        try container.encode(shortcut, forKey: .shortcut)
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

