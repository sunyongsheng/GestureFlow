import Foundation

public struct GestureConfiguration: Codable, Equatable {
    public static let closeWindowGestureID = UUID(uuidString: "A7C4E1B2-3D5F-4A89-9C0E-1F2A3B4C5D6E")!

    public var applicationBundleIdentifiers: [String]
    public var gestures: [GestureDefinition]
    public var customGestureSignatures: [GestureSignature]

    public init(
        applicationBundleIdentifiers: [String] = [],
        gestures: [GestureDefinition] = [GestureDefinition.builtInCloseWindow],
        customGestureSignatures: [GestureSignature] = []
    ) {
        self.applicationBundleIdentifiers = applicationBundleIdentifiers
        self.gestures = gestures
        self.customGestureSignatures = customGestureSignatures
    }

    public static var defaultTemplate: GestureConfiguration {
        GestureConfiguration(
            applicationBundleIdentifiers: [],
            gestures: [GestureDefinition.builtInCloseWindow]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case applicationBundleIdentifiers
        case gestures
        case customGestureSignatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        applicationBundleIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .applicationBundleIdentifiers
        ) ?? []
        gestures = try container.decodeIfPresent([GestureDefinition].self, forKey: .gestures)
            ?? [GestureDefinition.builtInCloseWindow]
        customGestureSignatures = try container.decodeIfPresent(
            [GestureSignature].self,
            forKey: .customGestureSignatures
        ) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(applicationBundleIdentifiers, forKey: .applicationBundleIdentifiers)
        try container.encode(gestures, forKey: .gestures)
        try container.encode(customGestureSignatures, forKey: .customGestureSignatures)
    }
}
