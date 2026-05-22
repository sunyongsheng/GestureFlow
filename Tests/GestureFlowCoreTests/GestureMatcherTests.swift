import XCTest
@testable import GestureFlowCore

final class GestureMatcherTests: XCTestCase {
    func testMatchesEnabledGestureWithSameTriggerAndSignature() {
        let gesture = GestureDefinition(
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .systemCommand(.showDesktop)
        )

        let match = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            in: [gesture]
        )

        XCTAssertEqual(match?.id, gesture.id)
    }

    func testDoesNotMatchDisabledGesture() {
        var gesture = GestureDefinition(
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .systemCommand(.showDesktop)
        )
        gesture.isEnabled = false

        let match = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            in: [gesture]
        )

        XCTAssertNil(match)
    }
}
