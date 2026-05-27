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

    // Callback injection tests were removed; production code no longer supports injecting
    // lifecycle callbacks via initializer parameters.
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
        gestureConfiguration: .defaultTemplate,
        isRunning: isRunning,
        isAccessibilityTrusted: isAccessibilityTrusted,
        saveConfiguration: { _ in },
        saveGestureConfiguration: { _ in },
        requestAccessibilityPermission: {},
        startGestureFlow: {},
        stopGestureFlow: {},
        quitApplication: {},
        pauseGestureRecognition: {},
        resumeGestureRecognition: {}
    )
}

