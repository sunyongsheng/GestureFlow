import XCTest
@testable import GestureFlowCore

final class GestureLiveMatcherTests: XCTestCase {
    func testPartialDownPrefixesConfiguredDownRight() {
        let gesture = makeGesture(name: "Close", signature: [.down, .right])
        let result = GestureLiveMatcher().evaluate(
            trigger: .rightMouse,
            partialSignature: GestureSignature(tokens: [.down]),
            targetBundleIdentifier: nil,
            in: [gesture]
        )

        XCTAssertNil(result.exactMatch)
        XCTAssertTrue(result.hasPrefixMatch)
    }

    func testExactMatchForCompleteSignature() {
        let gesture = makeGesture(name: "Close", signature: [.down, .right])
        let result = GestureLiveMatcher().evaluate(
            trigger: .rightMouse,
            partialSignature: GestureSignature(tokens: [.down, .right]),
            targetBundleIdentifier: nil,
            in: [gesture]
        )

        XCTAssertEqual(result.exactMatch?.name, "Close")
        XCTAssertTrue(result.hasPrefixMatch)
    }

    func testNoPrefixMatchWhenDirectionBreaks() {
        let gesture = makeGesture(name: "Close", signature: [.down, .right])
        let result = GestureLiveMatcher().evaluate(
            trigger: .rightMouse,
            partialSignature: GestureSignature(tokens: [.down, .left]),
            targetBundleIdentifier: nil,
            in: [gesture]
        )

        XCTAssertNil(result.exactMatch)
        XCTAssertFalse(result.hasPrefixMatch)
    }

    func testNilPartialSignatureHasNoMatches() {
        let gesture = makeGesture(name: "Close", signature: [.down, .right])
        let result = GestureLiveMatcher().evaluate(
            trigger: .rightMouse,
            partialSignature: nil,
            targetBundleIdentifier: nil,
            in: [gesture]
        )

        XCTAssertNil(result.exactMatch)
        XCTAssertFalse(result.hasPrefixMatch)
    }

    func testAppSpecificExactMatchBeatsGlobal() {
        let global = makeGesture(name: "Global", bundleIdentifier: nil, signature: [.down, .right])
        let safari = makeGesture(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            signature: [.down, .right]
        )
        let result = GestureLiveMatcher().evaluate(
            trigger: .rightMouse,
            partialSignature: GestureSignature(tokens: [.down, .right]),
            targetBundleIdentifier: "com.apple.Safari",
            in: [global, safari]
        )

        XCTAssertEqual(result.exactMatch?.id, safari.id)
    }

    func testDisabledGesturesAreIgnored() {
        var gesture = makeGesture(name: "Close", signature: [.down, .right])
        gesture.isEnabled = false

        let result = GestureLiveMatcher().evaluate(
            trigger: .rightMouse,
            partialSignature: GestureSignature(tokens: [.down]),
            targetBundleIdentifier: nil,
            in: [gesture]
        )

        XCTAssertNil(result.exactMatch)
        XCTAssertFalse(result.hasPrefixMatch)
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
