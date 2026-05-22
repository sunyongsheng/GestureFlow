import AppKit
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class SettingsWindowCoordinatorTests: XCTestCase {
    func testCoordinatorStoresSingleSettingsViewModelInstance() {
        let coordinator = SettingsWindowCoordinator()
        let initialViewModel = makeSettingsViewModel(
            isRunning: false,
            isAccessibilityTrusted: true
        )
        let replacementViewModel = makeSettingsViewModel(
            isRunning: true,
            isAccessibilityTrusted: false
        )

        coordinator.install(viewModel: initialViewModel)
        coordinator.install(viewModel: replacementViewModel)

        XCTAssertTrue(coordinator.viewModel === initialViewModel)
    }

    func testCoordinatorPublishesRuntimeUpdatesWithoutReplacingViewModel() {
        let coordinator = SettingsWindowCoordinator()
        let viewModel = makeSettingsViewModel(
            isRunning: false,
            isAccessibilityTrusted: false
        )

        coordinator.install(viewModel: viewModel)
        viewModel.updateRuntimeStatus(isRunning: true, isAccessibilityTrusted: true)

        XCTAssertTrue(coordinator.viewModel === viewModel)
        XCTAssertEqual(coordinator.viewModel?.isRunning, true)
        XCTAssertEqual(coordinator.viewModel?.isAccessibilityTrusted, true)
    }

    @MainActor
    func testCoordinatorForwardsSettingsDidAppearWhenWindowAttaches() {
        var didAppearCount = 0
        let coordinator = SettingsWindowCoordinator(
            onSettingsDidAppear: { didAppearCount += 1 }
        )
        let window = makeSettingsWindow()

        coordinator.attachSettingsWindow(window)

        XCTAssertEqual(didAppearCount, 1)
        XCTAssertEqual(
            window.identifier?.rawValue,
            SettingsWindowSceneIDs.settings
        )
    }

    @MainActor
    func testCoordinatorForwardsLastSettingsWindowDidClose() {
        let notificationCenter = NotificationCenter()
        var didCloseCount = 0
        let coordinator = SettingsWindowCoordinator(
            notificationCenter: notificationCenter,
            onLastSettingsWindowDidClose: { didCloseCount += 1 }
        )
        let window = makeSettingsWindow()

        coordinator.attachSettingsWindow(window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(didCloseCount, 1)
    }

    @MainActor
    func testCoordinatorReattachesWhenSettingsWindowOpensAgain() {
        let notificationCenter = NotificationCenter()
        var didAppearCount = 0
        var didCloseCount = 0
        let coordinator = SettingsWindowCoordinator(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: { didAppearCount += 1 },
            onLastSettingsWindowDidClose: { didCloseCount += 1 }
        )
        let window = makeSettingsWindow()

        coordinator.attachSettingsWindow(window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)
        coordinator.attachSettingsWindow(window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(didAppearCount, 2)
        XCTAssertEqual(didCloseCount, 2)
    }
}

private func makeSettingsViewModel(
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
private func makeSettingsWindow() -> NSWindow {
    NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
}
