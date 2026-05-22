import Foundation

public struct AppConfiguration: Codable, Equatable {
    public var isEnabled: Bool
    public var gestures: [GestureDefinition]
    public var feedback: FeedbackConfiguration
    public var trigger: GestureTriggerConfiguration

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case gestures
        case feedback
        case trigger
    }

    public init(
        isEnabled: Bool = false,
        gestures: [GestureDefinition] = GestureDefinition.defaults,
        feedback: FeedbackConfiguration = .default,
        trigger: GestureTriggerConfiguration = .default
    ) {
        self.isEnabled = isEnabled
        self.gestures = gestures
        self.feedback = feedback
        self.trigger = trigger
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        gestures = try container.decodeIfPresent([GestureDefinition].self, forKey: .gestures)
            ?? GestureDefinition.defaults
        feedback = try container.decodeIfPresent(FeedbackConfiguration.self, forKey: .feedback) ?? .default
        trigger = try container.decodeIfPresent(GestureTriggerConfiguration.self, forKey: .trigger) ?? .default
    }
}

public struct GestureTriggerConfiguration: Codable, Equatable {
    public var movementThreshold: Double
    public var holdTimeoutMilliseconds: Int
    public var maximumSampleDistance: Double

    private enum CodingKeys: String, CodingKey {
        case movementThreshold
        case holdTimeoutMilliseconds
        case maximumSampleDistance
    }

    public init(movementThreshold: Double, holdTimeoutMilliseconds: Int, maximumSampleDistance: Double) {
        self.movementThreshold = movementThreshold
        self.holdTimeoutMilliseconds = holdTimeoutMilliseconds
        self.maximumSampleDistance = maximumSampleDistance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        movementThreshold = try container.decodeIfPresent(Double.self, forKey: .movementThreshold)
            ?? GestureTriggerConfiguration.default.movementThreshold
        holdTimeoutMilliseconds = try container.decodeIfPresent(Int.self, forKey: .holdTimeoutMilliseconds)
            ?? GestureTriggerConfiguration.default.holdTimeoutMilliseconds
        maximumSampleDistance = try container.decodeIfPresent(Double.self, forKey: .maximumSampleDistance)
            ?? GestureTriggerConfiguration.default.maximumSampleDistance
    }

    public static let `default` = GestureTriggerConfiguration(
        movementThreshold: 24,
        holdTimeoutMilliseconds: 250,
        maximumSampleDistance: 120
    )
}

public struct FeedbackConfiguration: Codable, Equatable {
    public var trailColorHex: String
    public var trailWidth: Double
    public var trailOpacity: Double

    public init(trailColorHex: String, trailWidth: Double, trailOpacity: Double) {
        self.trailColorHex = trailColorHex
        self.trailWidth = trailWidth
        self.trailOpacity = trailOpacity
    }

    public static let `default` = FeedbackConfiguration(
        trailColorHex: "#4A90E2",
        trailWidth: 2.5,
        trailOpacity: 0.85
    )
}
