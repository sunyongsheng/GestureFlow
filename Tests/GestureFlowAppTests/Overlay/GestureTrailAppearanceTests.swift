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
    }

    func testGestureTrailAppearanceDefaultsStrokeDisabled() {
        let appearance = GestureTrailAppearance(feedback: .default)

        XCTAssertFalse(appearance.strokeEnabled)
    }
}
