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
    public var trailStrokeEnabled: Bool
    public var trailStrokeColorHex: String
    public var trailStrokeWidth: Double
    /// How long the trail and completion feedback stay visible after mouse release.
    public var overlayHideDelayMilliseconds: Int
    /// Main trail color while drawing a gesture that does not prefix-match any configured gesture.
    public var unrecognizedTrailColorHex: String
    /// Corner radius of the on-screen gesture feedback card (not exposed in settings UI).
    public var feedbackCardCornerRadius: Double
    /// Use macOS 26 liquid glass styling for the on-screen feedback card.
    public var feedbackCardLiquidGlassEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case trailColorHex
        case trailWidth
        case trailOpacity
        case trailStrokeEnabled
        case trailStrokeColorHex
        case trailStrokeWidth
        case overlayHideDelayMilliseconds
        case unrecognizedTrailColorHex
        case feedbackCardCornerRadius
        case feedbackCardLiquidGlassEnabled
    }

    public init(
        trailColorHex: String,
        trailWidth: Double,
        trailOpacity: Double,
        trailStrokeEnabled: Bool = false,
        trailStrokeColorHex: String = "#FFFFFF",
        trailStrokeWidth: Double = 1.5,
        overlayHideDelayMilliseconds: Int = 500,
        unrecognizedTrailColorHex: String = "#8E8E93",
        feedbackCardCornerRadius: Double = 18,
        feedbackCardLiquidGlassEnabled: Bool = false
    ) {
        self.trailColorHex = trailColorHex
        self.trailWidth = trailWidth
        self.trailOpacity = trailOpacity
        self.trailStrokeEnabled = trailStrokeEnabled
        self.trailStrokeColorHex = trailStrokeColorHex
        self.trailStrokeWidth = trailStrokeWidth
        self.overlayHideDelayMilliseconds = overlayHideDelayMilliseconds
        self.unrecognizedTrailColorHex = unrecognizedTrailColorHex
        self.feedbackCardCornerRadius = feedbackCardCornerRadius
        self.feedbackCardLiquidGlassEnabled = feedbackCardLiquidGlassEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trailColorHex = try container.decode(String.self, forKey: .trailColorHex)
        trailWidth = try container.decode(Double.self, forKey: .trailWidth)
        trailOpacity = try container.decode(Double.self, forKey: .trailOpacity)
        trailStrokeEnabled = try container.decodeIfPresent(Bool.self, forKey: .trailStrokeEnabled) ?? false
        trailStrokeColorHex = try container.decodeIfPresent(String.self, forKey: .trailStrokeColorHex) ?? "#FFFFFF"
        trailStrokeWidth = try container.decodeIfPresent(Double.self, forKey: .trailStrokeWidth) ?? 1.5
        overlayHideDelayMilliseconds = try container.decodeIfPresent(
            Int.self,
            forKey: .overlayHideDelayMilliseconds
        ) ?? 500
        unrecognizedTrailColorHex = try container.decodeIfPresent(
            String.self,
            forKey: .unrecognizedTrailColorHex
        ) ?? "#8E8E93"
        feedbackCardCornerRadius = try container.decodeIfPresent(
            Double.self,
            forKey: .feedbackCardCornerRadius
        ) ?? 18
        feedbackCardLiquidGlassEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .feedbackCardLiquidGlassEnabled
        ) ?? false
    }

    public static let `default` = FeedbackConfiguration(
        trailColorHex: "#4A90E2",
        trailWidth: 3,
        trailOpacity: 0.85,
        trailStrokeEnabled: false,
        trailStrokeColorHex: "#FFFFFF",
        trailStrokeWidth: 1.5,
        overlayHideDelayMilliseconds: 500,
        unrecognizedTrailColorHex: "#8E8E93"
    )
}
