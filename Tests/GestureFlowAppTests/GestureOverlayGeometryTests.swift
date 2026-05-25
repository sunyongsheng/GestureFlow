import CoreGraphics
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureOverlayGeometryTests: XCTestCase {
    func testHotspotOffsetDefaultsToRawPoint() {
        let point = GesturePoint(x: 100, y: 200)

        let adjusted = GestureOverlayGeometry.applyHotspotOffset(to: point)

        XCTAssertEqual(adjusted, point)
    }

    func testScreenResolutionChoosesContainingScreenForGlobalPoint() {
        let leftScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rightScreen = CGRect(x: 1440, y: 0, width: 1728, height: 1117)
        let point = GesturePoint(x: 1600, y: 700)

        let resolved = GestureOverlayGeometry.resolveScreenFrame(
            containing: point,
            screenFrames: [leftScreen, rightScreen],
            mainScreenFrame: leftScreen
        )

        XCTAssertEqual(resolved, rightScreen)
    }

    func testFeedbackAnchorIsNearLowerQuarterOfTargetScreen() {
        let screen = CGRect(x: 1440, y: 0, width: 1728, height: 1117)

        let anchor = GestureOverlayGeometry.feedbackAnchor(in: screen)

        XCTAssertEqual(anchor.width, 320)
        XCTAssertEqual(anchor.height, 44)
        XCTAssertEqual(anchor.midX, screen.midX, accuracy: 0.001)
        XCTAssertEqual(anchor.midY, screen.minY + screen.height * 0.25, accuracy: 0.001)
    }

    func testScreenResolutionFallsBackToMainScreenWhenPointIsOutsideKnownScreens() {
        let leftScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let point = GesturePoint(x: -200, y: 1200)

        let resolved = GestureOverlayGeometry.resolveScreenFrame(
            containing: point,
            screenFrames: [leftScreen],
            mainScreenFrame: leftScreen
        )

        XCTAssertEqual(resolved, leftScreen)
    }

    func testScreenResolutionUsesRawBoundaryPointInsteadOfShiftedOverlayPoint() {
        let leftScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rightScreen = CGRect(x: 1440, y: 0, width: 1728, height: 1117)
        let rawBoundaryPoint = GesturePoint(x: 1442, y: 80)

        let resolved = GestureOverlayGeometry.resolveScreenFrame(
            containing: rawBoundaryPoint,
            screenFrames: [leftScreen, rightScreen],
            mainScreenFrame: leftScreen
        )

        XCTAssertEqual(resolved, rightScreen)
    }

    func testDefaultFeedbackUsesThinnerTrailWidth() {
        XCTAssertEqual(FeedbackConfiguration.default.trailWidth, 3, accuracy: 0.001)
    }
}
