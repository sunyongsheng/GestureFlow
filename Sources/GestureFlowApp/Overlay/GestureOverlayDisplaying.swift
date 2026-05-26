import Foundation
import GestureFlowCore

struct GestureTrailAppearance: Equatable {
    var colorHex: String
    var width: Double
    var opacity: Double
    var strokeEnabled: Bool
    var strokeColorHex: String
    var strokeWidth: Double

    init(feedback: FeedbackConfiguration) {
        self.colorHex = feedback.trailColorHex
        self.width = feedback.trailWidth
        self.opacity = feedback.trailOpacity
        self.strokeEnabled = feedback.trailStrokeEnabled
        self.strokeColorHex = feedback.trailStrokeColorHex
        self.strokeWidth = feedback.trailStrokeWidth
    }
}

struct GestureOverlayMarker: Equatable {
    enum Style: Equatable {
        case timeoutOrigin
    }

    var point: GesturePoint
    var style: Style
}

enum GestureOverlayCompletion: Equatable {
    case recognized(name: String)
    case unmatched
    case rejected
    case actionFailed
}

protocol GestureOverlayDisplaying: AnyObject {
    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance)
    func appendGesturePoint(_ point: GesturePoint)
    func completeGesture(with completion: GestureOverlayCompletion, at point: GesturePoint?)
    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance)
    func clearMarker()
    func cancelGesture()
}

final class NoopGestureOverlay: GestureOverlayDisplaying {
    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance) {}
    func appendGesturePoint(_ point: GesturePoint) {}
    func completeGesture(with completion: GestureOverlayCompletion, at point: GesturePoint?) {}
    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {}
    func clearMarker() {}
    func cancelGesture() {}
}
