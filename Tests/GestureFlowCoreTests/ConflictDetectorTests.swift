import XCTest
@testable import GestureFlowCore

final class ConflictDetectorTests: XCTestCase {
    func testDetectsDuplicateEnabledTriggerAndSignature() {
        let first = makeGesture(name: "Back")
        let second = makeGesture(name: "Back Duplicate")

        let conflicts = ConflictDetector().detect(in: [first, second])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].trigger, .rightMouse)
        XCTAssertEqual(conflicts[0].signature, GestureSignature(tokens: [.left]))
        XCTAssertEqual(Set(conflicts[0].gestureIDs), Set([first.id, second.id]))
    }

    func testIgnoresDisabledDuplicateGesture() {
        let enabled = makeGesture(name: "Back")
        var disabled = makeGesture(name: "Back Disabled")
        disabled.isEnabled = false

        let conflicts = ConflictDetector().detect(in: [enabled, disabled])

        XCTAssertTrue(conflicts.isEmpty)
    }

    private func makeGesture(name: String) -> GestureDefinition {
        GestureDefinition(
            name: name,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .systemCommand(.showDesktop)
        )
    }
}
