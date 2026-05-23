import AppKit
import XCTest
@testable import GestureFlowApp

@MainActor
final class SettingsWindowFrontmostPresenterTests: XCTestCase {
    func testActivateExistingSettingsWindowBringsMatchingWindowToFront() {
        let window = makeSettingsWindow()
        window.orderOut(nil)
        var activateCount = 0

        let didActivate = SettingsWindowFrontmostPresenter.activateExistingSettingsWindow(
            windows: [window],
            activateApplication: { activateCount += 1 }
        )

        XCTAssertTrue(didActivate)
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(activateCount, 1)
    }

    func testActivateExistingSettingsWindowReturnsFalseWhenNoSettingsWindowExists() {
        let didActivate = SettingsWindowFrontmostPresenter.activateExistingSettingsWindow(
            windows: [makeGenericWindow()]
        )

        XCTAssertFalse(didActivate)
    }

    func testActivateExistingOrOpenOpensOnlyWhenNoSettingsWindowExists() {
        var openCount = 0

        SettingsWindowFrontmostPresenter.activateExistingOrOpen(
            openWindow: { openCount += 1 },
            windows: [makeGenericWindow()]
        )

        XCTAssertEqual(openCount, 1)
    }

    func testActivateExistingOrOpenSkipsOpenWhenSettingsWindowAlreadyExists() {
        let window = makeSettingsWindow()
        var openCount = 0

        SettingsWindowFrontmostPresenter.activateExistingOrOpen(
            openWindow: { openCount += 1 },
            windows: [window]
        )

        XCTAssertEqual(openCount, 0)
        XCTAssertTrue(window.isVisible)
    }

    func testActivateExistingSettingsWindowUsesAttachedWindowIDsWithoutIdentifier() {
        let window = makeGenericWindow()
        let attachedIDs = Set([ObjectIdentifier(window)])

        let didActivate = SettingsWindowFrontmostPresenter.activateExistingSettingsWindow(
            windows: [window],
            attachedWindowIDs: attachedIDs
        )

        XCTAssertTrue(didActivate)
        XCTAssertTrue(window.isVisible)
    }

    func testActivateExistingOrOpenWithAttachedWindowIDsSkipsOpen() {
        let coordinator = SettingsWindowCoordinator()
        let window = makeGenericWindow()
        coordinator.attachSettingsWindow(window)
        window.identifier = nil
        var openCount = 0
        let attachedIDs = Set(coordinator.attachedSettingsWindows.map(ObjectIdentifier.init(_:)))

        SettingsWindowFrontmostPresenter.activateExistingOrOpen(
            openWindow: { openCount += 1 },
            windows: coordinator.attachedSettingsWindows,
            attachedWindowIDs: attachedIDs
        )

        XCTAssertEqual(openCount, 0)
        XCTAssertTrue(window.isVisible)
    }
}

@MainActor
private func makeSettingsWindow() -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.identifier = NSUserInterfaceItemIdentifier(SettingsWindowSceneIDs.settings)
    return window
}

@MainActor
private func makeGenericWindow() -> NSWindow {
    NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
}
