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

    func testIncrementalRecognizerMatchesBatchRecognitionForEveryPrefix() {
        var generator = SeededRandomNumberGenerator(seed: 0x5EED)
        let recognizer = GestureRecognizer()

        for coordinateSystem in [GesturePointCoordinateSystem.screen, .view] {
            for _ in 0..<20 {
                let points = makeRandomGesturePath(count: 300, using: &generator)
                var incremental = IncrementalGestureRecognizer(coordinateSystem: coordinateSystem)
                for count in 1...points.count {
                    incremental.append(points[count - 1])
                    XCTAssertEqual(
                        incremental.signature,
                        recognizer.recognize(
                            points: Array(points.prefix(count)),
                            coordinateSystem: coordinateSystem
                        )
                    )
                }
            }
        }
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

/// Wandering path with occasional turns, sub-point to multi-point steps and jitter, so prefixes cross the
/// jitter and minimum-length thresholds at many different points.
private func makeRandomGesturePath(
    count: Int,
    using generator: inout SeededRandomNumberGenerator
) -> [GesturePoint] {
    var points = [GesturePoint(x: 0, y: 0)]
    var heading = Double.random(in: 0..<(2 * .pi), using: &generator)
    while points.count < count {
        if Double.random(in: 0..<1, using: &generator) < 0.05 {
            heading = Double.random(in: 0..<(2 * .pi), using: &generator)
        }
        let step = Double.random(in: 0.2...12, using: &generator)
        let last = points[points.count - 1]
        points.append(
            GesturePoint(
                x: last.x + cos(heading) * step + Double.random(in: -1.5...1.5, using: &generator),
                y: last.y + sin(heading) * step + Double.random(in: -1.5...1.5, using: &generator)
            )
        )
    }
    return points
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
