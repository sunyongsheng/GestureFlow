import Foundation

public struct GestureConfiguration: Codable, Equatable {
    public var applicationBundleIdentifiers: [String]
    public var gestures: [GestureDefinition]
    public var gestureSignatures: [GestureSignature]

    public init(
        applicationBundleIdentifiers: [String] = [],
        gestures: [GestureDefinition] = [],
        gestureSignatures: [GestureSignature] = []
    ) {
        self.applicationBundleIdentifiers = applicationBundleIdentifiers
        self.gestures = gestures
        self.gestureSignatures = gestureSignatures
    }

    public static var emptyCustomTemplate: GestureConfiguration {
        GestureConfiguration()
    }

    public static var defaultTemplate: GestureConfiguration {
        SplitGestureConfigurationLoader.merge(
            builtin: BuiltInGestureSeeds.factoryBuiltinConfiguration(),
            custom: .emptyCustomTemplate
        ).configuration
    }

    private enum CodingKeys: String, CodingKey {
        case applicationBundleIdentifiers
        case gestures
        case gestureSignatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        applicationBundleIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .applicationBundleIdentifiers
        ) ?? []
        gestures = try container.decodeIfPresent([GestureDefinition].self, forKey: .gestures) ?? []
        gestureSignatures = try container.decodeIfPresent(
            [GestureSignature].self,
            forKey: .gestureSignatures
        ) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(applicationBundleIdentifiers, forKey: .applicationBundleIdentifiers)
        try container.encode(gestures, forKey: .gestures)
        try container.encode(gestureSignatures, forKey: .gestureSignatures)
    }
}
