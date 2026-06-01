import XCTest
@testable import GestureFlowApp

final class StatusBarControllerTests: XCTestCase {
    func testMenuContainsSingleDynamicStartStopItem() {
        let controller = StatusBarController(actions: .stub, localization: LocalizationManager(language: .zhHans))

        XCTAssertEqual(
            controller.menuItemTitles,
            [
                "启动 GestureFlow",
                "设置…",
                "退出"
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
                quit: {}
            ),
            localization: LocalizationManager(language: .zhHans),
            scheduleOnMain: { $0() }
        )

        controller.performMenuItem(tag: .gestureFlow)
        controller.update(
            state: StatusBarState(isRunning: true, isAccessibilityTrusted: true)
        )
        controller.performMenuItem(tag: .gestureFlow)

        XCTAssertTrue(started)
        XCTAssertTrue(stopped)
    }

    func testSettingsMenuItemInvokesOpenSettingsAction() {
        var openedSettings = false
        var scheduledActions: [() -> Void] = []
        let controller = StatusBarController(
            actions: StatusBarActions(
                start: {},
                stop: {},
                openSettings: { openedSettings = true },
                quit: {}
            ),
            localization: LocalizationManager(language: .zhHans),
            scheduleOnMain: { scheduledActions.append($0) }
        )

        let item = NSMenuItem(
            title: "设置…",
            action: #selector(StatusBarController.openSettingsMenuItem(_:)),
            keyEquivalent: ""
        )
        item.tag = StatusBarMenuItemTag.settings.rawValue

        controller.openSettingsMenuItem(item)

        XCTAssertFalse(openedSettings)
        XCTAssertEqual(scheduledActions.count, 1)

        scheduledActions.removeFirst()()

        XCTAssertFalse(openedSettings)
        XCTAssertEqual(scheduledActions.count, 1)

        scheduledActions.removeFirst()()

        XCTAssertTrue(openedSettings)
    }

    func testSettingsMenuItemDoesNotUseSystemPreferencesSelector() {
        let controller = StatusBarController(actions: .stub, localization: LocalizationManager(language: .zhHans))

        XCTAssertEqual(
            controller.menuItemAction(tag: .settings),
            #selector(StatusBarController.openSettingsMenuItem(_:))
        )
    }

    func testQuitMenuItemInvokesQuitAction() {
        var quitCount = 0
        let controller = StatusBarController(
            actions: StatusBarActions(
                start: {},
                stop: {},
                openSettings: {},
                quit: { quitCount += 1 }
            ),
            localization: LocalizationManager(language: .zhHans),
            scheduleOnMain: { $0() }
        )

        controller.performMenuItem(tag: .quit)

        XCTAssertEqual(quitCount, 1)
    }

    func testDynamicMenuItemTitleChangesWithRunningState() {
        let controller = StatusBarController(actions: .stub, localization: LocalizationManager(language: .zhHans))

        controller.update(
            state: StatusBarState(isRunning: false, isAccessibilityTrusted: true)
        )

        XCTAssertTrue(controller.menuItemTitles.contains("启动 GestureFlow"))
        XCTAssertFalse(controller.menuItemTitles.contains("停止 GestureFlow"))
        XCTAssertTrue(controller.isMenuItemEnabled(tag: .gestureFlow))

        controller.update(
            state: StatusBarState(isRunning: true, isAccessibilityTrusted: true)
        )

        XCTAssertFalse(controller.menuItemTitles.contains("启动 GestureFlow"))
        XCTAssertTrue(controller.menuItemTitles.contains("停止 GestureFlow"))
        XCTAssertTrue(controller.isMenuItemEnabled(tag: .gestureFlow))
    }

    func testStatusBarIconsLoadAsTemplateImages() {
        XCTAssertEqual(StatusBarIcon.image(isRunning: false).isTemplate, true)
        XCTAssertEqual(StatusBarIcon.image(isRunning: true).isTemplate, true)
    }
}

private extension StatusBarActions {
    static var stub: StatusBarActions {
        StatusBarActions(
            start: {},
            stop: {},
            openSettings: {},
            quit: {}
        )
    }
}
