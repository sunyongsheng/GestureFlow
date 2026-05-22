import AppKit
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class SettingsSceneBridgeTests: XCTestCase {
    func testBridgeStoresSingleSettingsViewModelInstance() {
        let bridge = SettingsSceneBridge()
        let initialViewModel = makeSettingsSceneBridgeViewModel(
            isRunning: false,
            isAccessibilityTrusted: true
        )
        let replacementViewModel = makeSettingsSceneBridgeViewModel(
            isRunning: true,
            isAccessibilityTrusted: false
        )

        bridge.install(viewModel: initialViewModel)
        bridge.install(viewModel: replacementViewModel)

        XCTAssertTrue(bridge.viewModel === initialViewModel)
    }

    func testBridgePublishesRuntimeUpdatesWithoutReplacingViewModel() {
        let bridge = SettingsSceneBridge()
        let viewModel = makeSettingsSceneBridgeViewModel(
            isRunning: false,
            isAccessibilityTrusted: false
        )

        bridge.install(viewModel: viewModel)
        viewModel.updateRuntimeStatus(isRunning: true, isAccessibilityTrusted: true)

        XCTAssertTrue(bridge.viewModel === viewModel)
        XCTAssertEqual(bridge.viewModel?.isRunning, true)
        XCTAssertEqual(bridge.viewModel?.isAccessibilityTrusted, true)
    }

    func testBridgeForwardsSettingsDidAppearLifecycleEvent() {
        var didAppearCount = 0
        let bridge = SettingsSceneBridge(
            onSettingsDidAppear: { didAppearCount += 1 }
        )

        bridge.handleSettingsDidAppear()

        XCTAssertEqual(didAppearCount, 1)
    }

    func testBridgeForwardsLastSettingsWindowDidCloseLifecycleEvent() {
        var didCloseCount = 0
        let bridge = SettingsSceneBridge(
            onLastSettingsWindowDidClose: { didCloseCount += 1 }
        )

        bridge.handleLastSettingsWindowDidClose()

        XCTAssertEqual(didCloseCount, 1)
    }

    @MainActor
    func testBridgeRetainsWindowLifecycleObservationAcrossWindowClose() {
        let notificationCenter = NotificationCenter()
        var didAppearCount = 0
        var didCloseCount = 0
        let bridge = SettingsSceneBridge(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: { didAppearCount += 1 },
            onLastSettingsWindowDidClose: { didCloseCount += 1 }
        )
        let window = makeSettingsSceneBridgeWindow()

        bridge.attachSettingsWindow(window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(didAppearCount, 1)
        XCTAssertEqual(didCloseCount, 1)
    }

    @MainActor
    func testBridgeReattachesWindowWhenSettingsWindowBecomesVisibleAgain() {
        let notificationCenter = NotificationCenter()
        var didAppearCount = 0
        var didCloseCount = 0
        let bridge = SettingsSceneBridge(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: { didAppearCount += 1 },
            onLastSettingsWindowDidClose: { didCloseCount += 1 }
        )
        let window = makeSettingsSceneBridgeWindow()
        window.title = "GestureFlowApp Settings"

        bridge.attachSettingsWindow(window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)
        notificationCenter.post(name: NSWindow.didBecomeKeyNotification, object: window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(didAppearCount, 2)
        XCTAssertEqual(didCloseCount, 2)
    }
}

private func makeSettingsSceneBridgeViewModel(
    isRunning: Bool,
    isAccessibilityTrusted: Bool
) -> SettingsViewModel {
    SettingsViewModel(
        loadResult: ConfigurationLoadResult(
            configuration: AppConfiguration(),
            didRecoverFromCorruption: false,
            backupURL: nil
        ),
        isRunning: isRunning,
        isAccessibilityTrusted: isAccessibilityTrusted,
        saveConfiguration: { _ in },
        requestAccessibilityPermission: {}
    )
}

@MainActor
private func makeSettingsSceneBridgeWindow() -> NSWindow {
    NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
}
