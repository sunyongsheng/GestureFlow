import XCTest
@testable import GestureFlowCore

final class ConflictDetectorTests: XCTestCase {
    func testDetectsDuplicateScopeSignatureAndTrigger() {
        let first = makeGesture(name: "First")
        let second = makeGesture(name: "Second")

        let conflicts = ConflictDetector().detect(in: [first, second])

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertNil(conflicts[0].targetBundleIdentifier)
        XCTAssertEqual(conflicts[0].trigger, .rightMouse)
        XCTAssertEqual(conflicts[0].signature, GestureSignature(tokens: [.left]))
        XCTAssertEqual(Set(conflicts[0].gestureIDs), Set([first.id, second.id]))
    }

    func testDetectsDuplicateEvenWhenDisabled() {
        let enabled = makeGesture(name: "Enabled")
        var disabled = makeGesture(name: "Disabled")
        disabled.isEnabled = false

        let conflicts = ConflictDetector().detect(in: [enabled, disabled])

        XCTAssertEqual(conflicts.count, 1)
    }

    private func makeGesture(name: String) -> GestureDefinition {
        GestureDefinition(
            name: name,
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            shortcut: KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
        )
    }
}
