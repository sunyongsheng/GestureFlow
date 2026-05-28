import Foundation

public enum BuiltInGestureSeeds {
    public static let closeWindowID = UUID(uuidString: "A7C4E1B2-3D5F-4A89-9C0E-1F2A3B4C5D6E")!

    public static func factoryGestures() -> [GestureDefinition] {
        [
            GestureDefinition(
                id: closeWindowID,
                targetBundleIdentifier: nil,
                trigger: .rightMouse,
                signature: GestureSignature(tokens: [.down, .right]),
                shortcut: KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
            )
        ]
    }

    public static func factoryBuiltinConfiguration() -> GestureConfiguration {
        GestureConfiguration(gestures: factoryGestures())
    }
}
