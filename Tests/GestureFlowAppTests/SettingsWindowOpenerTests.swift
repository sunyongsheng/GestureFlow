import XCTest
@testable import GestureFlowApp

final class SettingsWindowOpenerTests: XCTestCase {
    func testOpenerInvokesRegisteredOpenWindowAction() {
        var openCount = 0
        let opener = SettingsWindowOpener(openWindowAction: { openCount += 1 })

        let didOpen = opener.openSettingsWindow()

        XCTAssertTrue(didOpen)
        XCTAssertEqual(openCount, 1)
    }

    func testOpenerPrefersRegisteredActionOverMenuFallback() {
        var registeredCount = 0
        let opener = SettingsWindowOpener()
        opener.registerOpenWindowAction { registeredCount += 1 }

        let didOpen = opener.openSettingsWindow()

        XCTAssertTrue(didOpen)
        XCTAssertEqual(registeredCount, 1)
    }

    func testOpenerResolveOpenActionHookStillWorksForTests() {
        var openCount = 0
        let opener = SettingsWindowOpener(
            resolveOpenAction: {
                { openCount += 1 }
            }
        )

        let didOpen = opener.openSettingsWindow()

        XCTAssertTrue(didOpen)
        XCTAssertEqual(openCount, 1)
    }

    func testOpenerReturnsFalseWhenNoActionIsAvailable() {
        let opener = SettingsWindowOpener(resolveOpenAction: { nil })

        let didOpen = opener.openSettingsWindow()

        XCTAssertFalse(didOpen)
    }

    func testInvokeSettingsItemActionDispatchesTargetActionDirectly() {
        let target = SettingsWindowOpenerActionTarget()
        let item = NSMenuItem(
            title: "Settings…",
            action: #selector(SettingsWindowOpenerActionTarget.openSettings(_:)),
            keyEquivalent: ""
        )
        item.target = target

        let didInvoke = SettingsWindowOpener.invokeSettingsItemAction(item)

        XCTAssertTrue(didInvoke)
        XCTAssertEqual(target.invocationCount, 1)
    }

    func testInvokeSettingsItemActionReturnsFalseWithoutAction() {
        let item = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: "")

        let didInvoke = SettingsWindowOpener.invokeSettingsItemAction(item)

        XCTAssertFalse(didInvoke)
    }
}

private final class SettingsWindowOpenerActionTarget: NSObject {
    private(set) var invocationCount = 0

    @objc func openSettings(_ sender: Any?) {
        invocationCount += 1
    }
}
