import Foundation
import GestureFlowCore

struct GestureTrailAppearance: Equatable {
    var colorHex: String
    var width: Double
    var opacity: Double
    var strokeEnabled: Bool
    var strokeColorHex: String
    var strokeWidth: Double
    var unrecognizedTrailColorHex: String
    var feedbackCardCornerRadius: Double
    var feedbackCardLiquidGlassEnabled: Bool
    var isHighlighted: Bool

    init(feedback: FeedbackConfiguration, isHighlighted: Bool = true) {
        self.colorHex = feedback.trailColorHex
        self.width = feedback.trailWidth
        self.opacity = feedback.trailOpacity
        self.strokeEnabled = feedback.trailStrokeEnabled
        self.strokeColorHex = feedback.trailStrokeColorHex
        self.strokeWidth = feedback.trailStrokeWidth
        self.unrecognizedTrailColorHex = feedback.unrecognizedTrailColorHex
        self.feedbackCardCornerRadius = feedback.feedbackCardCornerRadius
        self.feedbackCardLiquidGlassEnabled = feedback.feedbackCardLiquidGlassEnabled
        self.isHighlighted = isHighlighted
    }

    var resolvedTrailColorHex: String {
        isHighlighted ? colorHex : unrecognizedTrailColorHex
    }
}

struct LiveGestureOverlayFeedback: Equatable {
    var message: String?
    var matchedGestureID: UUID?
    var matchedGestureStoredName: String?
    var showsCard: Bool
    var usesTrailColor: Bool = false
}

struct GestureOverlayMarker: Equatable {
    enum Style: Equatable {
        case timeoutOrigin
    }

    var point: GesturePoint
    var style: Style
}

enum GestureOverlayCompletion: Equatable {
    case recognized(gestureID: UUID, storedName: String)
    case unmatched
    case rejected
    case targetNotFound(gestureID: UUID, storedName: String)
    case shortcutNotConfigured(gestureID: UUID, storedName: String)
    case deliveryFailed(gestureID: UUID, storedName: String)
    case executionFailed(gestureID: UUID, storedName: String)
}

protocol GestureOverlayDisplaying: AnyObject {
    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance)
    func appendGesturePoint(_ point: GesturePoint)
    func updateLiveGesture(
        at point: GesturePoint,
        appearance: GestureTrailAppearance,
        feedback: LiveGestureOverlayFeedback
    )
    func completeGesture(
        with completion: GestureOverlayCompletion,
        at point: GesturePoint?,
        hideAfter: TimeInterval
    )
    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance)
    func clearMarker()
    func cancelGesture()
}

final class NoopGestureOverlay: GestureOverlayDisplaying {
    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance) {}
    func appendGesturePoint(_ point: GesturePoint) {}
    func updateLiveGesture(
        at point: GesturePoint,
        appearance: GestureTrailAppearance,
        feedback: LiveGestureOverlayFeedback
    ) {}
    func completeGesture(
        with completion: GestureOverlayCompletion,
        at point: GesturePoint?,
        hideAfter: TimeInterval
    ) {}
    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {}
    func clearMarker() {}
    func cancelGesture() {}
}
