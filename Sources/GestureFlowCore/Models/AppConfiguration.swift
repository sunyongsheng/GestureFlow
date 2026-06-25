import Foundation

public struct GeneralConfiguration: Codable, Equatable {
    public var showMenuBarIcon: Bool

    private enum CodingKeys: String, CodingKey {
        case showMenuBarIcon
    }

    public init(showMenuBarIcon: Bool = true) {
        self.showMenuBarIcon = showMenuBarIcon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
    }

    public static var `default`: GeneralConfiguration {
        GeneralConfiguration()
    }
}

public struct UpdateConfiguration: Codable, Equatable {
    /// How often to check for updates automatically, in hours.
    public var checkIntervalHours: Int

    private enum CodingKeys: String, CodingKey {
        case checkIntervalHours
    }

    public init(checkIntervalHours: Int = UpdateConfiguration.default.checkIntervalHours) {
        self.checkIntervalHours = checkIntervalHours
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checkIntervalHours = try container.decodeIfPresent(Int.self, forKey: .checkIntervalHours)
            ?? Self.default.checkIntervalHours
    }

    public static let `default` = UpdateConfiguration(checkIntervalHours: 168)
}

public struct AppConfiguration: Codable, Equatable {
    public var isEnabled: Bool
    public var general: GeneralConfiguration
    public var feedback: FeedbackConfiguration
    public var trigger: GestureTriggerConfiguration
    public var update: UpdateConfiguration
    public var gestureTargetApplication: GestureTargetApplication
    public var ignoredApplicationBundleIdentifiers: [String]

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case general
        case feedback
        case trigger
        case update
        case gestureTargetApplication
        case ignoredApplicationBundleIdentifiers
    }

    public init(
        isEnabled: Bool = false,
        general: GeneralConfiguration = .default,
        feedback: FeedbackConfiguration = .default,
        trigger: GestureTriggerConfiguration = .default,
        update: UpdateConfiguration = .default,
        gestureTargetApplication: GestureTargetApplication = .defaultValue,
        ignoredApplicationBundleIdentifiers: [String] = []
    ) {
        self.isEnabled = isEnabled
        self.general = general
        self.feedback = feedback
        self.trigger = trigger
        self.update = update
        self.gestureTargetApplication = gestureTargetApplication
        self.ignoredApplicationBundleIdentifiers = ignoredApplicationBundleIdentifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        general = try container.decodeIfPresent(GeneralConfiguration.self, forKey: .general) ?? .default
        feedback = try container.decodeIfPresent(FeedbackConfiguration.self, forKey: .feedback) ?? .default
        trigger = try container.decodeIfPresent(GestureTriggerConfiguration.self, forKey: .trigger) ?? .default
        update = try container.decodeIfPresent(UpdateConfiguration.self, forKey: .update) ?? .default
        gestureTargetApplication = try container.decodeIfPresent(
            GestureTargetApplication.self,
            forKey: .gestureTargetApplication
        ) ?? .defaultValue
        ignoredApplicationBundleIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .ignoredApplicationBundleIdentifiers
        ) ?? []
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
        holdTimeoutMilliseconds: 450,
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
        trailStrokeEnabled: Bool = true,
        trailStrokeColorHex: String = "#FFFFFF",
        trailStrokeWidth: Double = 2,
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
        trailStrokeEnabled = try container.decodeIfPresent(Bool.self, forKey: .trailStrokeEnabled)
            ?? Self.default.trailStrokeEnabled
        trailStrokeColorHex = try container.decodeIfPresent(String.self, forKey: .trailStrokeColorHex)
            ?? Self.default.trailStrokeColorHex
        trailStrokeWidth = try container.decodeIfPresent(Double.self, forKey: .trailStrokeWidth)
            ?? Self.default.trailStrokeWidth
        overlayHideDelayMilliseconds = try container.decodeIfPresent(
            Int.self,
            forKey: .overlayHideDelayMilliseconds
        ) ?? Self.default.overlayHideDelayMilliseconds
        unrecognizedTrailColorHex = try container.decodeIfPresent(
            String.self,
            forKey: .unrecognizedTrailColorHex
        ) ?? Self.default.unrecognizedTrailColorHex
        feedbackCardCornerRadius = try container.decodeIfPresent(
            Double.self,
            forKey: .feedbackCardCornerRadius
        ) ?? Self.default.feedbackCardCornerRadius
        feedbackCardLiquidGlassEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .feedbackCardLiquidGlassEnabled
        ) ?? Self.default.feedbackCardLiquidGlassEnabled
    }

    public static let `default` = FeedbackConfiguration(
        trailColorHex: "#00E042",
        trailWidth: 3,
        trailOpacity: 1,
        trailStrokeEnabled: true,
        trailStrokeColorHex: "#FFFFFF",
        trailStrokeWidth: 2,
        overlayHideDelayMilliseconds: 500,
        unrecognizedTrailColorHex: "#8E8E93"
    )
}
