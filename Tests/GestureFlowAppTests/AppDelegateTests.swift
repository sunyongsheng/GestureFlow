import AppKit
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class AppDelegateTests: XCTestCase {
    func testSettingsWindowSceneIDUsesStableSettingsIdentifier() {
        XCTAssertEqual(SettingsWindowSceneIDs.settings, "settings")
    }

    func testApplicationDidFinishLaunching_startsCoordinatorWithoutCallingCustomRunLoop() {
        let coordinator = ApplicationCoordinatorSpy()
        let delegate = AppDelegate(makeApplicationController: { _, _ in coordinator })

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(coordinator.launchCallCount, 1)
        XCTAssertTrue(delegate.applicationController === coordinator)
    }

    func testAppDelegateExposesInjectedSettingsOpener() {
        let opener = SettingsWindowOpener(resolveOpenAction: { nil })
        let delegate = AppDelegate(
            settingsOpener: opener,
            makeApplicationController: { _, _ in ApplicationCoordinatorSpy() }
        )

        XCTAssertTrue(delegate.settingsOpener === opener)
    }

    func testAppDelegateExposesInjectedSettingsCoordinator() {
        let coordinator = SettingsWindowCoordinator()
        let delegate = AppDelegate(
            settingsCoordinator: coordinator,
            makeApplicationController: { _, _ in ApplicationCoordinatorSpy() }
        )

        XCTAssertTrue(delegate.settingsCoordinator === coordinator)
    }

    func testDefaultAppDelegateUsesSharedSettingsWindowDependencies() {
        let delegate = AppDelegate(makeApplicationController: { _, _ in ApplicationCoordinatorSpy() })

        XCTAssertTrue(delegate.settingsCoordinator === SettingsWindowDependencies.shared.coordinator)
        XCTAssertTrue(delegate.settingsOpener === SettingsWindowDependencies.shared.opener)
    }

    func testDefaultAppDelegateUsesSharedPresentationController() {
        let delegate = AppDelegate(makeApplicationController: { _, _ in ApplicationCoordinatorSpy() })

        XCTAssertTrue(delegate.presentationController === SettingsWindowDependencies.shared.presentationController)
    }

    func testDefaultInitUsesSharedSettingsWindowDependencies() {
        let delegate = AppDelegate()

        XCTAssertTrue(delegate.settingsCoordinator === SettingsWindowDependencies.shared.coordinator)
        XCTAssertTrue(delegate.settingsOpener === SettingsWindowDependencies.shared.opener)
        XCTAssertTrue(delegate.presentationController === SettingsWindowDependencies.shared.presentationController)
    }

    func testCustomAppDelegateCanInjectPresentationController() {
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { _ in }
        )
        let delegate = AppDelegate(
            presentationController: presentationController,
            makeApplicationController: { _, _ in ApplicationCoordinatorSpy() }
        )

        XCTAssertTrue(delegate.presentationController === presentationController)
    }

    func testShowSettingsHandlerForLaunchInstallsViewModelWithoutOpeningSettingsWindow() {
        let coordinator = SettingsWindowCoordinator()
        var openCount = 0
        let opener = SettingsWindowOpener(resolveOpenAction: {
            { openCount += 1 }
        })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { $0() }
        )
        let showSettings = AppDelegate.makeShowSettingsHandler(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: { $0() }
        )
        let viewModel = makeSettingsViewModel()

        showSettings(viewModel, SettingsPresentationSource.launch)

        XCTAssertTrue(coordinator.viewModel === viewModel)
        XCTAssertEqual(openCount, 0)
    }

    func testShowSettingsHandlerForLaunchDefersForegroundPreparation() {
        let coordinator = SettingsWindowCoordinator()
        var scheduledBlocks: [() -> Void] = []
        let opener = SettingsWindowOpener(resolveOpenAction: { nil })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { _ in }
        )
        let showSettings = AppDelegate.makeShowSettingsHandler(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: { scheduledBlocks.append($0) }
        )
        let viewModel = makeSettingsViewModel()

        showSettings(viewModel, SettingsPresentationSource.launch)

        XCTAssertTrue(coordinator.viewModel === viewModel)
        XCTAssertEqual(scheduledBlocks.count, 1)
        XCTAssertEqual(presentationController.state, .accessoryBackground)

        scheduledBlocks.removeFirst()()

        XCTAssertEqual(presentationController.state, .promotingToForeground)
    }

    func testShowSettingsHandlerForMenuBarOpensSettingsWindow() {
        let coordinator = SettingsWindowCoordinator()
        var openCount = 0
        let opener = SettingsWindowOpener(resolveOpenAction: {
            { openCount += 1 }
        })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { $0() }
        )
        let showSettings = AppDelegate.makeShowSettingsHandler(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: { $0() }
        )
        let viewModel = makeSettingsViewModel()

        showSettings(viewModel, SettingsPresentationSource.menuBar)

        XCTAssertTrue(coordinator.viewModel === viewModel)
        XCTAssertEqual(openCount, 1)
    }
}

private final class ApplicationCoordinatorSpy: GestureFlowApplicationCoordinating {
    private(set) var launchCallCount = 0

    func launch() {
        launchCallCount += 1
    }
}

private func makeSettingsViewModel() -> SettingsViewModel {
    SettingsViewModel(
        loadResult: ConfigurationLoadResult(
            configuration: AppConfiguration(),
            didRecoverFromCorruption: false,
            backupURL: nil
        ),
        isRunning: false,
        isAccessibilityTrusted: true,
        saveConfiguration: { _ in },
        requestAccessibilityPermission: {}
    )
}
