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

    func testAppDelegateExposesSharedSettingsSceneOpenDriver() {
        let driver = SettingsSceneOpenDriver(resolveOpenAction: { nil })
        let delegate = AppDelegate(
            settingsSceneOpenDriver: driver,
            makeApplicationController: { _, _ in ApplicationCoordinatorSpy() }
        )

        XCTAssertTrue(delegate.settingsSceneOpenDriver === driver)
    }

    func testAppDelegateExposesSharedSettingsSceneBridge() {
        let bridge = SettingsSceneBridge()
        let delegate = AppDelegate(
            settingsSceneBridge: bridge,
            makeApplicationController: { _, _ in ApplicationCoordinatorSpy() }
        )

        XCTAssertTrue(delegate.settingsSceneBridge === bridge)
    }

    func testDefaultAppDelegateUsesSharedSettingsSceneDependencies() {
        let delegate = AppDelegate(makeApplicationController: { _, _ in ApplicationCoordinatorSpy() })

        XCTAssertTrue(delegate.settingsSceneBridge === SettingsSceneServices.shared.bridge)
        XCTAssertTrue(delegate.settingsSceneOpenDriver === SettingsSceneServices.shared.openDriver)
    }

    func testDefaultAppDelegateUsesSharedPresentationController() {
        let delegate = AppDelegate(makeApplicationController: { _, _ in ApplicationCoordinatorSpy() })

        XCTAssertTrue(delegate.presentationController === SettingsSceneServices.shared.presentationController)
    }

    func testDefaultInitUsesSharedSettingsSceneDependencies() {
        let delegate = AppDelegate()

        XCTAssertTrue(delegate.settingsSceneBridge === SettingsSceneServices.shared.bridge)
        XCTAssertTrue(delegate.settingsSceneOpenDriver === SettingsSceneServices.shared.openDriver)
        XCTAssertTrue(delegate.presentationController === SettingsSceneServices.shared.presentationController)
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
        let bridge = SettingsSceneBridge()
        var openCount = 0
        let openDriver = SettingsSceneOpenDriver(resolveOpenAction: {
            { openCount += 1 }
        })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { $0() }
        )
        let showSettings = AppDelegate.makeShowSettingsHandler(
            bridge: bridge,
            openDriver: openDriver,
            presentationController: presentationController,
            scheduleOnMain: { $0() }
        )
        let viewModel = makeSettingsViewModel()

        showSettings(viewModel, SettingsPresentationSource.launch)

        XCTAssertTrue(bridge.viewModel === viewModel)
        XCTAssertEqual(openCount, 0)
    }

    func testShowSettingsHandlerForLaunchDefersForegroundPreparation() {
        let bridge = SettingsSceneBridge()
        var scheduledBlocks: [() -> Void] = []
        let openDriver = SettingsSceneOpenDriver(resolveOpenAction: { nil })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { _ in }
        )
        let showSettings = AppDelegate.makeShowSettingsHandler(
            bridge: bridge,
            openDriver: openDriver,
            presentationController: presentationController,
            scheduleOnMain: { scheduledBlocks.append($0) }
        )
        let viewModel = makeSettingsViewModel()

        showSettings(viewModel, SettingsPresentationSource.launch)

        XCTAssertTrue(bridge.viewModel === viewModel)
        XCTAssertEqual(scheduledBlocks.count, 1)
        XCTAssertEqual(presentationController.state, .accessoryBackground)

        scheduledBlocks.removeFirst()()

        XCTAssertEqual(presentationController.state, .promotingToForeground)
    }

    func testShowSettingsHandlerForMenuBarOpensSettingsWindow() {
        let bridge = SettingsSceneBridge()
        var openCount = 0
        let openDriver = SettingsSceneOpenDriver(resolveOpenAction: {
            { openCount += 1 }
        })
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { $0() }
        )
        let showSettings = AppDelegate.makeShowSettingsHandler(
            bridge: bridge,
            openDriver: openDriver,
            presentationController: presentationController,
            scheduleOnMain: { $0() }
        )
        let viewModel = makeSettingsViewModel()

        showSettings(viewModel, SettingsPresentationSource.menuBar)

        XCTAssertTrue(bridge.viewModel === viewModel)
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
