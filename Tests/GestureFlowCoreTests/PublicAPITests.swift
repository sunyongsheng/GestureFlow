import XCTest
import GestureFlowCore

final class PublicAPITests: XCTestCase {
    func testGestureTriggerConfigurationCanBeConstructedByPackageClients() {
        let trigger = GestureTriggerConfiguration(
            movementThreshold: 32,
            holdTimeoutMilliseconds: 400,
            maximumSampleDistance: 120
        )

        XCTAssertEqual(trigger.movementThreshold, 32)
        XCTAssertEqual(trigger.holdTimeoutMilliseconds, 400)
        XCTAssertEqual(trigger.maximumSampleDistance, 120)
    }

    func testFeedbackConfigurationCanBeConstructedByPackageClients() {
        let feedback = FeedbackConfiguration(
            trailColorHex: "#FFFFFF",
            trailWidth: 6,
            trailOpacity: 0.5
        )

        XCTAssertEqual(feedback.trailColorHex, "#FFFFFF")
        XCTAssertEqual(feedback.trailWidth, 6)
        XCTAssertEqual(feedback.trailOpacity, 0.5)
    }

    func testActionValueTypesCanBeConstructedByPackageClients() {
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let app = OpenApplicationAction(bundleIdentifier: "com.apple.finder")
        let url = OpenURLAction(url: URL(string: "https://example.com")!)

        XCTAssertEqual(shortcut.keyCode, 123)
        XCTAssertEqual(shortcut.modifiers, [.command])
        XCTAssertEqual(app.bundleIdentifier, "com.apple.finder")
        XCTAssertEqual(url.url.absoluteString, "https://example.com")
    }
}
