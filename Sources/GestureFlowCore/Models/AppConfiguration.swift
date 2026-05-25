import Foundation

public struct AppConfiguration: Codable, Equatable {
    public var isEnabled: Bool
    public var feedback: FeedbackConfiguration
    public var trigger: GestureTriggerConfiguration
    public var gestureTargetApplication: GestureTargetApplication

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case feedback
        case trigger
        case gestureTargetApplication
    }

    public init(
        isEnabled: Bool = false,
        feedback: FeedbackConfiguration = .default,
        trigger: GestureTriggerConfiguration = .default,
        gestureTargetApplication: GestureTargetApplication = .defaultValue
    ) {
        self.isEnabled = isEnabled
        self.feedback = feedback
        self.trigger = trigger
        self.gestureTargetApplication = gestureTargetApplication
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        feedback = try container.decodeIfPresent(FeedbackConfiguration.self, forKey: .feedback) ?? .default
        trigger = try container.decodeIfPresent(GestureTriggerConfiguration.self, forKey: .trigger) ?? .default
        gestureTargetApplication = try container.decodeIfPresent(
            GestureTargetApplication.self,
            forKey: .gestureTargetApplication
        ) ?? .defaultValue
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
        trailWidth: 3,
        trailOpacity: 0.85
    )
}
