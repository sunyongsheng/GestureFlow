import XCTest
@testable import GestureFlowCore

final class ScopedGestureMatcherTests: XCTestCase {
    func testAppSpecificGestureBeatsGlobal() {
        let global = makeGesture(
            name: "Global",
            bundleIdentifier: nil,
            signature: [.down, .right]
        )
        let safari = makeGesture(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            signature: [.down, .right]
        )

        let match = ScopedGestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            foregroundBundleIdentifier: "com.apple.Safari",
            in: [global, safari]
        )

        XCTAssertEqual(match?.id, safari.id)
    }

    func testGlobalUsedWhenNoAppGesture() {
        let global = makeGesture(
            name: "Global",
            bundleIdentifier: nil,
            signature: [.down, .right]
        )

        let match = ScopedGestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            foregroundBundleIdentifier: "com.apple.Safari",
            in: [global]
        )

        XCTAssertEqual(match?.id, global.id)
    }

    func testDisabledGesturesAreNotMatched() {
        var global = makeGesture(
            name: "Global",
            bundleIdentifier: nil,
            signature: [.down, .right]
        )
        global.isEnabled = false

        let match = ScopedGestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            foregroundBundleIdentifier: nil,
            in: [global]
        )

        XCTAssertNil(match)
    }

    func testDifferentTriggerDoesNotMatch() {
        let global = makeGesture(
            name: "Global",
            bundleIdentifier: nil,
            signature: [.down, .right],
            trigger: .middleMouse
        )

        let match = ScopedGestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            foregroundBundleIdentifier: nil,
            in: [global]
        )

        XCTAssertNil(match)
    }

    private func makeGesture(
        name: String,
        bundleIdentifier: String?,
        signature: [GestureDirection],
        trigger: GestureTrigger = .rightMouse
    ) -> GestureDefinition {
        GestureDefinition(
            targetBundleIdentifier: bundleIdentifier,
            name: name,
            trigger: trigger,
            signature: GestureSignature(tokens: signature),
            shortcut: KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
        )
    }
}
