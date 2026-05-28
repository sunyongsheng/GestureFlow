import AppKit
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureShortcutFormattingTests: XCTestCase {
    func testCommandAIsRecorded() {
        let shortcut = KeyboardShortcutAction(keyCode: 0, modifiers: [.command])

        XCTAssertTrue(shortcut.isRecorded)
        XCTAssertEqual(GestureShortcutFormatting.displayString(for: shortcut), "⌘ A")
    }

    func testUnrecordedShortcutUsesEmptyModifiers() {
        let shortcut = KeyboardShortcutAction(keyCode: 0, modifiers: [])

        XCTAssertFalse(shortcut.isRecorded)
        XCTAssertEqual(
            GestureShortcutFormatting.displayString(for: shortcut),
            AppServices.localization.string(.shortcutClickToRecord)
        )
    }

    func testCaptureShortcutUsesHardwareKeyCodeForCommandA() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )

        let shortcut = GestureShortcutFormatting.captureShortcut(from: event!)

        XCTAssertEqual(shortcut?.keyCode, 0)
        XCTAssertEqual(shortcut?.modifiers, [.command])
    }
}
