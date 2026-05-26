import XCTest
@testable import GestureFlowCore

final class GestureRecognizerRecordingTests: XCTestCase {
    func testViewCoordinatesMapDownwardDragToDownDirection() {
        let recognizer = GestureRecognizer()
        let points = (0...30).map { step in
            GesturePoint(x: 10, y: Double(step) * 4)
        }

        let signature = recognizer.recognize(points: points, coordinateSystem: .view)

        XCTAssertEqual(signature?.tokens, [.down])
    }

    func testScreenCoordinatesMapDownwardDragToUpDirection() {
        let recognizer = GestureRecognizer()
        let points = (0...30).map { step in
            GesturePoint(x: 10, y: -Double(step) * 4)
        }

        let signature = recognizer.recognize(points: points, coordinateSystem: .screen)

        XCTAssertEqual(signature?.tokens, [.down])
    }

    func testRecognizeCapsTokenCountForRecording() {
        let recognizer = GestureRecognizer()
        var points: [GesturePoint] = [GesturePoint(x: 0, y: 0)]
        var x = 0.0
        var y = 0.0
        for step in 1...24 {
            if step.isMultiple(of: 2) {
                x += 30
            } else {
                y += 30
            }
            points.append(GesturePoint(x: x, y: y))
        }

        let uncapped = recognizer.recognize(points: points, coordinateSystem: .view)
        let capped = recognizer.recognize(
            points: points,
            coordinateSystem: .view,
            maxTokenCount: GestureRecognizer.maxRecordingSegmentCount
        )

        XCTAssertGreaterThan(uncapped?.tokens.count ?? 0, GestureRecognizer.maxRecordingSegmentCount)
        XCTAssertEqual(capped?.tokens.count, GestureRecognizer.maxRecordingSegmentCount)
    }
}
