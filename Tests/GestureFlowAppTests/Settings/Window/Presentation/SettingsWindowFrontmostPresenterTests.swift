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
        var activateCount = 0

        SettingsWindowFrontmostPresenter.activateExistingOrOpen(
            openWindow: { openCount += 1 },
            windows: [makeGenericWindow()],
            activateApplication: { activateCount += 1 }
        )

        XCTAssertEqual(openCount, 1)
        // Activation is deferred until the settings host window attaches.
        XCTAssertEqual(activateCount, 0)
    }

    func testBringToFrontOrdersWindowKeyAndActivatesApplication() {
        let window = makeSettingsWindow()
        window.orderOut(nil)
        var activateCount = 0

        SettingsWindowFrontmostPresenter.bringToFront(
            window: window,
            activateApplication: { activateCount += 1 }
        )

        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(activateCount, 1)
    }

    func testClaimFrontmostSettingsWindowUsesWindowsOverloadPath() {
        let window = makeSettingsWindow()
        window.orderOut(nil)
        var activateCount = 0

        let didClaim = SettingsWindowFrontmostPresenter.activateExistingSettingsWindow(
            windows: [window],
            activateApplication: { activateCount += 1 }
        )

        XCTAssertTrue(didClaim)
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(activateCount, 1)
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

    func testCloseAllSettingsWindowsClosesMatchingWindows() {
        let settingsWindow = makeSettingsWindow()
        settingsWindow.orderFront(nil)
        let genericWindow = makeGenericWindow()
        genericWindow.orderFront(nil)

        SettingsWindowFrontmostPresenter.closeAllSettingsWindows(
            windows: [settingsWindow, genericWindow]
        )

        XCTAssertFalse(settingsWindow.isVisible)
        XCTAssertTrue(genericWindow.isVisible)
    }

    func testCloseAllSettingsWindowsClosesAttachedWindowsWithoutIdentifier() {
        let window = makeGenericWindow()
        window.orderFront(nil)
        let attachedIDs = Set([ObjectIdentifier(window)])

        SettingsWindowFrontmostPresenter.closeAllSettingsWindows(
            windows: [window],
            attachedWindowIDs: attachedIDs
        )

        XCTAssertFalse(window.isVisible)
    }

    func testBeginKeyFocusClaimStopsWhenAlreadyKey() {
        let coordinator = SettingsWindowCoordinator()
        let center = NotificationCenter()
        var claimCount = 0

        SettingsWindowFrontmostPresenter.beginKeyFocusClaim(
            coordinator: coordinator,
            notificationCenter: center,
            claim: { _ in
                claimCount += 1
                return true
            },
            isApplicationActive: { true },
            hasKeySettingsWindow: { _ in true }
        )

        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(claimCount, 1)
    }

    func testBeginKeyFocusClaimClaimsAgainWhenApplicationBecomesActive() {
        let coordinator = SettingsWindowCoordinator()
        let center = NotificationCenter()
        var claimCount = 0

        SettingsWindowFrontmostPresenter.beginKeyFocusClaim(
            coordinator: coordinator,
            notificationCenter: center,
            claim: { _ in
                claimCount += 1
                return true
            },
            isApplicationActive: { false },
            hasKeySettingsWindow: { _ in false }
        )

        XCTAssertEqual(claimCount, 1)

        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(claimCount, 2)

        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(claimCount, 2)
    }

    func testCancelKeyFocusClaimPreventsBecomeActiveClaim() {
        let coordinator = SettingsWindowCoordinator()
        let center = NotificationCenter()
        var claimCount = 0

        SettingsWindowFrontmostPresenter.beginKeyFocusClaim(
            coordinator: coordinator,
            notificationCenter: center,
            claim: { _ in
                claimCount += 1
                return true
            },
            isApplicationActive: { false },
            hasKeySettingsWindow: { _ in false }
        )

        SettingsWindowFrontmostPresenter.cancelKeyFocusClaim(notificationCenter: center)
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(claimCount, 1)
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
