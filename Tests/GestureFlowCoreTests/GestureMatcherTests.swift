import XCTest
@testable import GestureFlowCore

final class GestureMatcherTests: XCTestCase {
    func testReturnsExactMatchWhenAvailable() {
        let downOnly = makeGesture(name: "Down", signature: [.down])
        let downRight = makeGesture(name: "Down Right", signature: [.down, .right])

        let result = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down]),
            targetBundleIdentifier: nil,
            prefixPolicy: .fallbackToPrefix,
            in: [downOnly, downRight]
        )

        XCTAssertEqual(result.gesture?.id, downOnly.id)
        XCTAssertTrue(result.isExact)
    }

    func testFallsBackToPrefixOnlyWhenExactMissing() {
        let downRight = makeGesture(name: "Down Right", signature: [.down, .right])

        let result = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down]),
            targetBundleIdentifier: nil,
            prefixPolicy: .fallbackToPrefix,
            in: [downRight]
        )

        XCTAssertEqual(result.gesture?.id, downRight.id)
        XCTAssertFalse(result.isExact)
    }

    func testDoesNotReturnPrefixWhenPrefixDisabled() {
        let downRight = makeGesture(name: "Down Right", signature: [.down, .right])

        let result = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down]),
            targetBundleIdentifier: nil,
            prefixPolicy: .disabled,
            in: [downRight]
        )

        XCTAssertNil(result.gesture)
        XCTAssertFalse(result.isExact)
    }

    func testReturnsNoneWhenDirectionBreaks() {
        let downRight = makeGesture(name: "Down Right", signature: [.down, .right])

        let result = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .left]),
            targetBundleIdentifier: nil,
            prefixPolicy: .fallbackToPrefix,
            in: [downRight]
        )

        XCTAssertNil(result.gesture)
    }

    func testAppSpecificBeatsGlobalForExactMatch() {
        let global = makeGesture(name: "Global", bundleIdentifier: nil, signature: [.down, .right])
        let safari = makeGesture(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            signature: [.down, .right]
        )

        let result = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            targetBundleIdentifier: "com.apple.Safari",
            prefixPolicy: .disabled,
            in: [global, safari]
        )

        XCTAssertEqual(result.gesture?.id, safari.id)
        XCTAssertTrue(result.isExact)
    }

    func testDisabledGesturesAreIgnored() {
        var downRight = makeGesture(name: "Down Right", signature: [.down, .right])
        downRight.isEnabled = false

        let result = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down]),
            targetBundleIdentifier: nil,
            prefixPolicy: .fallbackToPrefix,
            in: [downRight]
        )

        XCTAssertNil(result.gesture)
    }

    private func makeGesture(
        name: String,
        bundleIdentifier: String? = nil,
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

