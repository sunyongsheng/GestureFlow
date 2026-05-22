import XCTest
@testable import GestureFlowApp

final class StatusBarControllerTests: XCTestCase {
    func testMenuContainsSingleDynamicStartStopItem() {
        let controller = StatusBarController(actions: .stub)

        XCTAssertEqual(
            controller.menuItemTitles,
            [
                "Start GestureFlow",
                "Preferences",
                "Quit"
            ]
        )
    }

    func testDynamicMenuItemInvokesStartWhenStoppedAndStopWhenRunning() {
        var started = false
        var stopped = false
        let controller = StatusBarController(
            actions: StatusBarActions(
                start: { started = true },
                stop: { stopped = true },
                openSettings: {},
                showCommonGestures: {},
                showPreferences: {},
                requestAccessibilityPermission: {},
                quit: {}
            )
        )

        controller.performMenuItem(tag: .gestureFlow)
        controller.update(
            state: StatusBarState(isRunning: true, isAccessibilityTrusted: true)
        )
        controller.performMenuItem(tag: .gestureFlow)

        XCTAssertTrue(started)
        XCTAssertTrue(stopped)
    }

    func testPreferencesMenuItemInvokesOpenSettingsAction() {
        var openedSettings = false
        var showedPreferences = false
        var scheduledActions: [() -> Void] = []
        var dismissMenuTrackingCount = 0
        let controller = StatusBarController(
            actions: StatusBarActions(
                start: {},
                stop: {},
                openSettings: { openedSettings = true },
                showCommonGestures: {},
                showPreferences: { showedPreferences = true },
                requestAccessibilityPermission: {},
                quit: {}
            ),
            scheduleOnMain: { scheduledActions.append($0) },
            dismissMenuTracking: { dismissMenuTrackingCount += 1 }
        )

        let item = NSMenuItem(title: "Preferences", action: #selector(StatusBarController.openSettingsMenuItem(_:)), keyEquivalent: "")
        item.tag = StatusBarMenuItemTag.preferences.rawValue

        controller.openSettingsMenuItem(item)

        XCTAssertFalse(openedSettings)
        XCTAssertEqual(scheduledActions.count, 1)
        XCTAssertEqual(dismissMenuTrackingCount, 1)

        scheduledActions.removeFirst()()

        XCTAssertFalse(openedSettings)
        XCTAssertEqual(scheduledActions.count, 1)

        scheduledActions.removeFirst()()

        XCTAssertTrue(openedSettings)
        XCTAssertFalse(showedPreferences)
    }

    func testPreferencesMenuItemDoesNotUseSystemPreferencesSelector() {
        let controller = StatusBarController(actions: .stub)

        XCTAssertEqual(controller.menuItemAction(tag: .preferences), #selector(StatusBarController.openSettingsMenuItem(_:)))
    }

    func testQuitMenuItemInvokesQuitAction() {
        var quitCount = 0
        let controller = StatusBarController(
            actions: StatusBarActions(
                start: {},
                stop: {},
                openSettings: {},
                showCommonGestures: {},
                showPreferences: {},
                requestAccessibilityPermission: {},
                quit: { quitCount += 1 }
            )
        )

        controller.performMenuItem(tag: .quit)

        XCTAssertEqual(quitCount, 1)
    }

    func testDynamicMenuItemTitleChangesWithRunningState() {
        let controller = StatusBarController(actions: .stub)

        controller.update(
            state: StatusBarState(isRunning: false, isAccessibilityTrusted: true)
        )

        XCTAssertTrue(controller.menuItemTitles.contains("Start GestureFlow"))
        XCTAssertFalse(controller.menuItemTitles.contains("Stop GestureFlow"))
        XCTAssertTrue(controller.isMenuItemEnabled(tag: .gestureFlow))

        controller.update(
            state: StatusBarState(isRunning: true, isAccessibilityTrusted: true)
        )

        XCTAssertFalse(controller.menuItemTitles.contains("Start GestureFlow"))
        XCTAssertTrue(controller.menuItemTitles.contains("Stop GestureFlow"))
        XCTAssertTrue(controller.isMenuItemEnabled(tag: .gestureFlow))
    }
}

private extension StatusBarActions {
    static var stub: StatusBarActions {
        StatusBarActions(
            start: {},
            stop: {},
            openSettings: {},
            showCommonGestures: {},
            showPreferences: {},
            requestAccessibilityPermission: {},
            quit: {}
        )
    }
}
