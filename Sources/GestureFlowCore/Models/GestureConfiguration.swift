import Foundation

public struct GestureConfiguration: Codable, Equatable {
    public static let closeWindowGestureID = UUID(uuidString: "A7C4E1B2-3D5F-4A89-9C0E-1F2A3B4C5D6E")!

    public var applicationBundleIdentifiers: [String]
    public var gestures: [GestureDefinition]

    public init(
        applicationBundleIdentifiers: [String] = [],
        gestures: [GestureDefinition] = [GestureDefinition.builtInCloseWindow]
    ) {
        self.applicationBundleIdentifiers = applicationBundleIdentifiers
        self.gestures = gestures
    }

    public static var defaultTemplate: GestureConfiguration {
        GestureConfiguration(
            applicationBundleIdentifiers: [],
            gestures: [GestureDefinition.builtInCloseWindow]
        )
    }
}
