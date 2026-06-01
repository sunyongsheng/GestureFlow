import XCTest
@testable import GestureFlowCore

final class GestureRecognizerTests: XCTestCase {
    func testRecognizesRightGesture() {
        let points = [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 40, y: 2),
            GesturePoint(x: 90, y: 3)
        ]

        let signature = GestureRecognizer().recognize(points: points)

        XCTAssertEqual(signature, GestureSignature(tokens: [.right]))
    }

    func testRecognizesDownThenRightGesture() {
        let points = [
            GesturePoint(x: 0, y: 60),
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 70, y: -2)
        ]

        let signature = GestureRecognizer().recognize(points: points)

        XCTAssertEqual(signature, GestureSignature(tokens: [.down, .right]))
    }

    func testRejectsTinyMovement() {
        let points = [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 2, y: 1)
        ]

        XCTAssertNil(GestureRecognizer().recognize(points: points))
    }

    func testNormalizesBoundingBoxToUnitSpace() {
        let points = [
            GesturePoint(x: 10, y: 20),
            GesturePoint(x: 30, y: 60),
            GesturePoint(x: 50, y: 100)
        ]

        let normalized = GestureNormalizer().normalizeBoundingBox(points)

        XCTAssertEqual(normalized, [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 0.5, y: 0.5),
            GesturePoint(x: 1, y: 1)
        ])
    }

    func testDefaultGestureTemplateIncludesCloseWindowGesture() {
        let configuration = GestureConfiguration.defaultTemplate

        XCTAssertTrue(configuration.gestures.allSatisfy { $0.name == nil })
        let closeWindow = configuration.gestures.first { $0.id == BuiltInGestureSeeds.closeWindowID }
        XCTAssertNotNil(closeWindow)
        XCTAssertEqual(closeWindow?.signature.tokens, [.down, .right])
    }
}
