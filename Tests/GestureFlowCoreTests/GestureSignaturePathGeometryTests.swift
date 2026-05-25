import XCTest
@testable import GestureFlowCore

final class GestureSignaturePathGeometryTests: XCTestCase {
    func testDownRightPolylineHasThreeVertices() {
        let signature = GestureSignature(tokens: [.down, .right])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)
        XCTAssertEqual(polyline.count, 3)
        XCTAssertEqual(polyline[0], PathPoint(x: 0, y: 0))
        XCTAssertEqual(polyline[1], PathPoint(x: 0, y: 1))
        XCTAssertEqual(polyline[2], PathPoint(x: 1, y: 1))
    }

    func testTerminalDirectionForDownRight() {
        let signature = GestureSignature(tokens: [.down, .right])
        XCTAssertEqual(GestureSignaturePathGeometry.terminalDirection(for: signature), .right)
    }

    func testSingleSegmentLeft() {
        let signature = GestureSignature(tokens: [.left])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)
        XCTAssertEqual(polyline.count, 2)
        XCTAssertEqual(GestureSignaturePathGeometry.terminalDirection(for: signature), .left)
    }

    func testFittedPolylineStaysInsideUnitSquare() {
        let signature = GestureSignature(tokens: [.down, .right])
        let fitted = GestureSignaturePathGeometry.fittedPolyline(for: signature)
        XCTAssertEqual(fitted.count, 3)
        for point in fitted {
            XCTAssertGreaterThanOrEqual(point.x, 0)
            XCTAssertLessThanOrEqual(point.x, 1)
            XCTAssertGreaterThanOrEqual(point.y, 0)
            XCTAssertLessThanOrEqual(point.y, 1)
        }
    }

    func testEmptyTokensReturnsEmptyPolyline() {
        let signature = GestureSignature(tokens: [])
        XCTAssertTrue(GestureSignaturePathGeometry.polyline(for: signature).isEmpty)
        XCTAssertNil(GestureSignaturePathGeometry.terminalDirection(for: signature))
    }

    func testUpRightLeftStaggersUsingExistingVerticalDirection() {
        let signature = GestureSignature(tokens: [.up, .right, .left])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)

        XCTAssertEqual(polyline.count, 5)
        XCTAssertEqual(polyline[0], PathPoint(x: 0, y: 0))
        XCTAssertEqual(polyline[1], PathPoint(x: 0, y: -1))
        XCTAssertEqual(polyline[2], PathPoint(x: 1, y: -1))
        XCTAssertEqual(polyline[3], PathPoint(x: 1, y: -1.22))
        XCTAssertEqual(polyline[4], PathPoint(x: 0, y: -1.22))
    }

    func testUpDownRightStaggersUsingHorizontalDirectionFromSignature() {
        let signature = GestureSignature(tokens: [.up, .down, .right])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)

        XCTAssertEqual(polyline.count, 5)
        XCTAssertEqual(polyline[0], PathPoint(x: 0, y: 0))
        XCTAssertEqual(polyline[1], PathPoint(x: 0, y: -1))
        XCTAssertEqual(polyline[2], PathPoint(x: 0.22, y: -1))
        XCTAssertEqual(polyline[3], PathPoint(x: 0.22, y: 0))
        XCTAssertEqual(polyline[4], PathPoint(x: 1.22, y: 0))
    }

    func testDownUpLeftStaggersUsingHorizontalDirectionFromSignature() {
        let signature = GestureSignature(tokens: [.down, .up, .left])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)

        XCTAssertEqual(polyline.count, 5)
        XCTAssertEqual(polyline[0], PathPoint(x: 0, y: 0))
        XCTAssertEqual(polyline[1], PathPoint(x: 0, y: 1))
        XCTAssertEqual(polyline[2], PathPoint(x: -0.22, y: 1))
        XCTAssertEqual(polyline[3], PathPoint(x: -0.22, y: 0))
        XCTAssertEqual(polyline[4], PathPoint(x: -1.22, y: 0))
    }

    func testLeftRightLeftStaggersUsingDefaultDownWhenNoVerticalDirection() {
        let signature = GestureSignature(tokens: [.left, .right, .left])
        let polyline = GestureSignaturePathGeometry.polyline(for: signature)

        XCTAssertEqual(polyline.count, 6)
        XCTAssertEqual(polyline[0], PathPoint(x: 0, y: 0))
        XCTAssertEqual(polyline[1], PathPoint(x: -1, y: 0))
        XCTAssertEqual(polyline[2], PathPoint(x: -1, y: 0.22))
        XCTAssertEqual(polyline[3], PathPoint(x: 0, y: 0.22))
        XCTAssertEqual(polyline[4], PathPoint(x: 0, y: 0.44))
        XCTAssertEqual(polyline[5], PathPoint(x: -1, y: 0.44))
    }
}
