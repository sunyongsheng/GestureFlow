import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class SettingsPresentationFlowTests: XCTestCase {
    func testShouldPresentSettingsOnLaunchIsFalseForLoginItem() {
        let shouldPresent = SettingsPresentationFlow.shouldPresentSettingsOnLaunch(
            detector: LaunchReasonDetectorStub(wasLaunchedAtLogin: true)
        )

        XCTAssertFalse(shouldPresent)
    }

    func testShouldPresentSettingsOnLaunchIsTrueForOrdinaryColdStart() {
        let shouldPresent = SettingsPresentationFlow.shouldPresentSettingsOnLaunch(
            detector: LaunchReasonDetectorStub(wasLaunchedAtLogin: false)
        )

        XCTAssertTrue(shouldPresent)
    }

    func testPresentOnLaunchPreparesForegroundWithoutOpeningWindow() {
        let coordinator = SettingsWindowCoordinator()
        var openCount = 0
        var scheduledBlocks: [() -> Void] = []
        let opener = SettingsWindowOpener(resolveOpenAction: {
            { openCount += 1 }
        })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            scheduleOnMain: { $0() }
        )
        let flow = SettingsPresentationFlow(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: { scheduledBlocks.append($0) }
        )

        flow.presentOnLaunch(viewModel: makeSettingsViewModel())

        XCTAssertTrue(coordinator.viewModel != nil)
        XCTAssertEqual(scheduledBlocks.count, 1)
        XCTAssertEqual(presentationController.state, .accessoryBackground)

        scheduledBlocks.removeFirst()()

        XCTAssertEqual(presentationController.state, .promotingToForeground)
        XCTAssertEqual(openCount, 0)
    }

    func testPresentFromMenuBarPreparesThenOpens() {
        let coordinator = SettingsWindowCoordinator()
        var events: [String] = []
        let opener = SettingsWindowOpener(resolveOpenAction: {
            { events.append("open") }
        })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in
                events.append("policy")
                return true
            },
            scheduleOnMain: { $0() }
        )
        let flow = SettingsPresentationFlow(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: { $0() }
        )

        flow.presentFromMenuBar(viewModel: makeSettingsViewModel())

        XCTAssertEqual(events, ["policy", "open"])
        XCTAssertEqual(presentationController.state, .promotingToForeground)
    }

    func testDismissAutoOpenedWindowsForSilentLaunchSchedulesDismiss() {
        var dismissCount = 0
        var scheduledBlocks: [() -> Void] = []
        let flow = SettingsPresentationFlow(
            coordinator: SettingsWindowCoordinator(),
            opener: SettingsWindowOpener(resolveOpenAction: { nil }),
            presentationController: AppPresentationController(
                application: .shared,
                setActivationPolicy: { _ in true },
                scheduleOnMain: { _ in }
            ),
            scheduleOnMain: { scheduledBlocks.append($0) },
            dismissAutoOpenedWindows: { dismissCount += 1 }
        )

        flow.dismissAutoOpenedWindowsForSilentLaunch()

        XCTAssertEqual(dismissCount, 0)
        XCTAssertEqual(scheduledBlocks.count, 1)

        scheduledBlocks.removeFirst()()

        XCTAssertEqual(dismissCount, 1)
    }
}

private struct LaunchReasonDetectorStub: LaunchReasonDetecting {
    let wasLaunchedAtLogin: Bool
}

private func makeSettingsViewModel() -> SettingsViewModel {
    SettingsViewModel(
        loadResult: ConfigurationLoadResult(
            configuration: AppConfiguration(),
            didRecoverFromCorruption: false,
            backupURL: nil
        ),
        gestureConfiguration: .defaultTemplate,
        isRunning: false,
        isAccessibilityTrusted: true,
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
