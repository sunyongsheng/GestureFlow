import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureTrailAppearanceTests: XCTestCase {
    func testGestureTrailAppearanceMapsStrokeFromFeedback() {
        let feedback = FeedbackConfiguration(
            trailColorHex: "#111111",
            trailWidth: 4,
            trailOpacity: 0.9,
            trailStrokeEnabled: true,
            trailStrokeColorHex: "#FFFFFF",
            trailStrokeWidth: 2
        )

        let appearance = GestureTrailAppearance(feedback: feedback)

        XCTAssertTrue(appearance.strokeEnabled)
        XCTAssertEqual(appearance.strokeColorHex, "#FFFFFF")
        XCTAssertEqual(appearance.strokeWidth, 2)
        XCTAssertEqual(appearance.colorHex, "#111111")
        XCTAssertEqual(appearance.width, 4)
        XCTAssertEqual(appearance.opacity, 0.9)
        XCTAssertEqual(appearance.feedbackCardCornerRadius, feedback.feedbackCardCornerRadius)
        XCTAssertEqual(
            appearance.feedbackCardLiquidGlassEnabled,
            feedback.feedbackCardLiquidGlassEnabled
        )
    }

    func testGestureTrailAppearanceDefaultsStrokeDisabled() {
        let appearance = GestureTrailAppearance(feedback: .default)

        XCTAssertFalse(appearance.strokeEnabled)
        XCTAssertEqual(appearance.feedbackCardCornerRadius, 18, accuracy: 0.001)
        XCTAssertFalse(appearance.feedbackCardLiquidGlassEnabled)
    }

    func testMutedAppearanceUsesConfiguredUnrecognizedTrailColor() {
        let feedback = FeedbackConfiguration(
            trailColorHex: "#FF00AA",
            trailWidth: 3,
            trailOpacity: 0.8,
            trailStrokeEnabled: true,
            trailStrokeColorHex: "#FFFFFF",
            trailStrokeWidth: 1,
            unrecognizedTrailColorHex: "#666666"
        )
        let appearance = GestureTrailAppearance(feedback: feedback, isHighlighted: false)

        XCTAssertEqual(appearance.resolvedTrailColorHex, "#666666")
        XCTAssertEqual(appearance.strokeColorHex, "#FFFFFF")
    }
}
