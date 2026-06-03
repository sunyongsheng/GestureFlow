import XCTest
@testable import GestureFlowCore

final class FeedbackConfigurationTests: XCTestCase {
    func testFeedbackConfigurationDefaults() {
        let config = FeedbackConfiguration.default

        XCTAssertEqual(config.trailColorHex, "#00E042")
        XCTAssertEqual(config.trailWidth, 3, accuracy: 0.001)
        XCTAssertEqual(config.trailOpacity, 1, accuracy: 0.001)
        XCTAssertTrue(config.trailStrokeEnabled)
        XCTAssertEqual(config.trailStrokeColorHex, "#FFFFFF")
        XCTAssertEqual(config.trailStrokeWidth, 2, accuracy: 0.001)
        XCTAssertEqual(config.overlayHideDelayMilliseconds, 500)
        XCTAssertEqual(config.unrecognizedTrailColorHex, "#8E8E93")
        XCTAssertEqual(config.feedbackCardCornerRadius, 18, accuracy: 0.001)
        XCTAssertFalse(config.feedbackCardLiquidGlassEnabled)
    }

    func testFeedbackConfigurationDecodesWithoutStrokeKeys() throws {
        let json = """
        {"trailColorHex":"#4A90E2","trailWidth":3,"trailOpacity":0.85}
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(FeedbackConfiguration.self, from: json)

        XCTAssertTrue(config.trailStrokeEnabled)
        XCTAssertEqual(config.trailStrokeColorHex, "#FFFFFF")
        XCTAssertEqual(config.trailStrokeWidth, 2, accuracy: 0.001)
        XCTAssertEqual(config.overlayHideDelayMilliseconds, 500)
        XCTAssertEqual(config.unrecognizedTrailColorHex, "#8E8E93")
        XCTAssertEqual(config.feedbackCardCornerRadius, 18, accuracy: 0.001)
        XCTAssertFalse(config.feedbackCardLiquidGlassEnabled)
    }

    func testFeedbackConfigurationEncodesFeedbackCardLiquidGlassEnabled() throws {
        let config = FeedbackConfiguration(
            trailColorHex: "#4A90E2",
            trailWidth: 3,
            trailOpacity: 0.85,
            feedbackCardLiquidGlassEnabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FeedbackConfiguration.self, from: data)

        XCTAssertTrue(decoded.feedbackCardLiquidGlassEnabled)
    }

    func testFeedbackConfigurationEncodesFeedbackCardCornerRadius() throws {
        let config = FeedbackConfiguration(
            trailColorHex: "#4A90E2",
            trailWidth: 3,
            trailOpacity: 0.85,
            feedbackCardCornerRadius: 24
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FeedbackConfiguration.self, from: data)

        XCTAssertEqual(decoded.feedbackCardCornerRadius, 24, accuracy: 0.001)
    }

    func testFeedbackConfigurationEncodesUnrecognizedTrailColor() throws {
        let config = FeedbackConfiguration(
            trailColorHex: "#4A90E2",
            trailWidth: 3,
            trailOpacity: 0.85,
            unrecognizedTrailColorHex: "#AABBCC"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FeedbackConfiguration.self, from: data)

        XCTAssertEqual(decoded.unrecognizedTrailColorHex, "#AABBCC")
    }

    func testFeedbackConfigurationEncodesOverlayHideDelay() throws {
        let config = FeedbackConfiguration(
            trailColorHex: "#4A90E2",
            trailWidth: 3,
            trailOpacity: 0.85,
            overlayHideDelayMilliseconds: 750
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FeedbackConfiguration.self, from: data)

        XCTAssertEqual(decoded.overlayHideDelayMilliseconds, 750)
    }

    func testFeedbackConfigurationEncodesStrokeFields() throws {
        let config = FeedbackConfiguration(
            trailColorHex: "#111111",
            trailWidth: 4,
            trailOpacity: 0.9,
            trailStrokeEnabled: true,
            trailStrokeColorHex: "#000000",
            trailStrokeWidth: 2
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FeedbackConfiguration.self, from: data)

        XCTAssertTrue(decoded.trailStrokeEnabled)
        XCTAssertEqual(decoded.trailStrokeColorHex, "#000000")
        XCTAssertEqual(decoded.trailStrokeWidth, 2, accuracy: 0.001)
    }
}
