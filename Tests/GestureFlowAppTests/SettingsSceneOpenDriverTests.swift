import XCTest
@testable import GestureFlowApp

final class SettingsSceneOpenDriverTests: XCTestCase {
    func testOpenDriverInvokesResolvedOpenWindowAction() {
        var openCount = 0
        let driver = SettingsSceneOpenDriver(
            resolveOpenAction: {
                { openCount += 1 }
            }
        )

        let didOpen = driver.openSettingsWindow()

        XCTAssertTrue(didOpen)
        XCTAssertEqual(openCount, 1)
    }

    func testOpenDriverReturnsFalseWhenNoSettingsWindowActionCanBeResolved() {
        let driver = SettingsSceneOpenDriver(resolveOpenAction: { nil })

        let didOpen = driver.openSettingsWindow()

        XCTAssertFalse(didOpen)
    }

    func testInvokeSettingsItemActionDispatchesTargetActionDirectly() {
        let target = SettingsSceneOpenDriverActionTarget()
        let item = NSMenuItem(title: "Settings…", action: #selector(SettingsSceneOpenDriverActionTarget.openSettings(_:)), keyEquivalent: "")
        item.target = target

        let didInvoke = SettingsSceneOpenDriver.invokeSettingsItemAction(item)

        XCTAssertTrue(didInvoke)
        XCTAssertEqual(target.invocationCount, 1)
    }

    func testInvokeSettingsItemActionReturnsFalseWithoutAction() {
        let item = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: "")

        let didInvoke = SettingsSceneOpenDriver.invokeSettingsItemAction(item)

        XCTAssertFalse(didInvoke)
    }
}

private final class SettingsSceneOpenDriverActionTarget: NSObject {
    private(set) var invocationCount = 0

    @objc func openSettings(_ sender: Any?) {
        invocationCount += 1
    }
}
