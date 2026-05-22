import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureFlowApplicationTests: XCTestCase {
    func testLaunchAlwaysOpensSettingsOnLaunch() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let notificationCenter = NotificationCenter()
        var showSettingsCount = 0
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            notificationCenter: notificationCenter,
            showSettings: { _, _ in showSettingsCount += 1 }
        )

        application.launch()

        XCTAssertEqual(showSettingsCount, 1)
    }

    func testLaunchKeepsExistingStatusBarControllerAlive() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { _, _ in }
        )
        let initialStatusBarController = application.statusBarController

        application.launch()

        XCTAssertTrue(application.statusBarController === initialStatusBarController)
    }

    func testLaunchPromptsForAccessibilityPermissionWhenMissing() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        var promptCount = 0
        var scheduledPrompt: (() -> Void)?
        let permissionService = PermissionService(
            trustCheck: { false },
            permissionPrompt: { promptCount += 1 }
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { _, _ in },
            scheduleOnMain: { scheduledPrompt = $0 }
        )

        application.launch()
        scheduledPrompt?()

        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: false, isAccessibilityTrusted: false)
        )
    }

    func testLaunchSchedulesPermissionPromptAfterOpeningSettings() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        var events: [String] = []
        var scheduledPrompt: (() -> Void)?
        let permissionService = PermissionService(
            trustCheck: { false },
            permissionPrompt: { events.append("prompt") }
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { _, _ in events.append("settings") },
            scheduleOnMain: { scheduledPrompt = $0 }
        )

        application.launch()
        XCTAssertEqual(events, ["settings"])

        scheduledPrompt?()
        XCTAssertEqual(events, ["settings", "prompt"])
    }

    func testActivationRefreshUpdatesVisibleRuntimeStateAfterLaunch() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        var isTrusted = false
        let permissionService = PermissionService(
            trustCheck: { isTrusted },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let notificationCenter = NotificationCenter()
        var capturedSettingsViewModel: SettingsViewModel?
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            notificationCenter: notificationCenter,
            activationNotificationName: .testApplicationDidBecomeActive,
            showSettings: { capturedSettingsViewModel = $0; _ = $1 }
        )

        application.launch()
        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: false, isAccessibilityTrusted: false)
        )

        isTrusted = true
        notificationCenter.post(name: .testApplicationDidBecomeActive, object: nil)

        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: false, isAccessibilityTrusted: true)
        )
        XCTAssertEqual(capturedSettingsViewModel?.isAccessibilityTrusted, true)
    }

    func testStartGestureFlowRefreshesCapturedSettingsViewModelRuntimeStateAfterLaunch() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var capturedSettingsViewModel: SettingsViewModel?
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { capturedSettingsViewModel = $0; _ = $1 }
        )

        application.launch()
        application.startGestureFlow()

        XCTAssertEqual(capturedSettingsViewModel?.isRunning, true)
        XCTAssertEqual(capturedSettingsViewModel?.isAccessibilityTrusted, true)
    }

    func testSettingsViewModelCanStartGestureFlowThroughInjectedAction() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var capturedSettingsViewModel: SettingsViewModel?
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { capturedSettingsViewModel = $0; _ = $1 }
        )

        application.launch()
        capturedSettingsViewModel?.setGestureRecognitionEnabled(true)

        XCTAssertEqual(eventTap.startCount, 1)
        XCTAssertTrue(gestureEngine.isRunning)
        XCTAssertTrue(try store.load().isEnabled)
    }

    func testSettingsViewModelCanStopGestureFlowThroughInjectedAction() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var capturedSettingsViewModel: SettingsViewModel?
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { capturedSettingsViewModel = $0; _ = $1 }
        )

        application.launch()
        application.startGestureFlow()
        capturedSettingsViewModel?.setGestureRecognitionEnabled(false)

        XCTAssertEqual(eventTap.stopCount, 1)
        XCTAssertFalse(gestureEngine.isRunning)
        XCTAssertFalse(try store.load().isEnabled)
    }

    func testSettingsViewModelCanQuitApplicationThroughInjectedAction() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var terminateCallCount = 0
        var capturedSettingsViewModel: SettingsViewModel?
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            terminateApplication: { _ in terminateCallCount += 1 },
            showSettings: { capturedSettingsViewModel = $0; _ = $1 }
        )

        application.launch()
        application.startGestureFlow()
        capturedSettingsViewModel?.quitApplication()

        XCTAssertEqual(eventTap.stopCount, 1)
        XCTAssertEqual(terminateCallCount, 1)
        XCTAssertFalse(try store.load().isEnabled)
    }

    func testLaunchCanInstallSettingsViewModelIntoBridgeAndOpenSettingsWindow() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let bridge = SettingsSceneBridge()
        var openSettingsWindowCount = 0
        let openDriver = SettingsSceneOpenDriver(
            resolveOpenAction: {
                { openSettingsWindowCount += 1 }
            }
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { viewModel, _ in
                bridge.install(viewModel: viewModel)
                _ = openDriver.openSettingsWindow()
            }
        )

        application.launch()

        XCTAssertNotNil(bridge.viewModel)
        XCTAssertEqual(openSettingsWindowCount, 1)
    }

    func testStartWithoutAccessibilityPermissionPromptsAndKeepsGestureFlowStopped() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        var promptCount = 0
        let permissionService = PermissionService(
            trustCheck: { false },
            permissionPrompt: { promptCount += 1 }
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine
        )

        application.startGestureFlow()

        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(eventTap.startCount, 0)
        XCTAssertFalse(try store.load().isEnabled)
        XCTAssertFalse(application.isGestureFlowRunning)
        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: false, isAccessibilityTrusted: false)
        )
    }

    func testStartWithAccessibilityPermissionEnablesGestureFlowAndUpdatesMenuState() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine
        )

        application.startGestureFlow()

        XCTAssertEqual(eventTap.startCount, 1)
        XCTAssertTrue(try store.load().isEnabled)
        XCTAssertTrue(application.isGestureFlowRunning)
        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: true, isAccessibilityTrusted: true)
        )
    }

    func testStartWithAccessibilityPermissionButEngineFailureKeepsGestureFlowStopped() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController(startResult: false)
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine
        )

        application.startGestureFlow()

        XCTAssertEqual(eventTap.startCount, 1)
        XCTAssertFalse(try store.load().isEnabled)
        XCTAssertFalse(application.isGestureFlowRunning)
        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: false, isAccessibilityTrusted: true)
        )
    }

    func testPersistedEnabledStateThatFailsToAutoStartIsResetToStopped() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(AppConfiguration(isEnabled: true))
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController(startResult: false)
        let gestureEngine = GestureEngine(
            configurationProvider: { store.loadRecovering().configuration },
            permissionService: permissionService,
            eventTap: eventTap
        )

        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine
        )

        XCTAssertEqual(eventTap.startCount, 1)
        XCTAssertFalse(try store.load().isEnabled)
        XCTAssertFalse(application.isGestureFlowRunning)
        XCTAssertEqual(
            application.statusBarController?.menuState,
            StatusBarState(isRunning: false, isAccessibilityTrusted: true)
        )
    }

    func testQuitMenuItemStopsGestureFlowBeforeTerminatingApplication() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var terminateCallCount = 0
        var wasStoppedBeforeTerminate = false
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            terminateApplication: { _ in
                terminateCallCount += 1
                wasStoppedBeforeTerminate = !gestureEngine.isRunning
            }
        )
        application.startGestureFlow()

        application.statusBarController?.performMenuItem(title: "Quit")

        XCTAssertEqual(eventTap.stopCount, 1)
        XCTAssertEqual(terminateCallCount, 1)
        XCTAssertTrue(wasStoppedBeforeTerminate)
        XCTAssertFalse(try store.load().isEnabled)
        XCTAssertFalse(application.isGestureFlowRunning)
    }

    func testTerminationNotificationStopsGestureFlow() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let notificationCenter = NotificationCenter()
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            notificationCenter: notificationCenter,
            terminationNotificationName: .testApplicationWillTerminate,
            showSettings: { _, _ in }
        )
        application.launch()
        application.startGestureFlow()

        notificationCenter.post(name: .testApplicationWillTerminate, object: nil)

        XCTAssertEqual(eventTap.stopCount, 1)
        XCTAssertFalse(try store.load().isEnabled)
        XCTAssertFalse(application.isGestureFlowRunning)
    }

    func testClosingSettingsDoesNotStopGestureRecognition() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var scheduledAccessoryFallback: (() -> Void)?
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { scheduledAccessoryFallback = $0 }
        )
        let bridge = SettingsSceneBridge(
            onSettingsDidAppear: {
                presentationController.handleSettingsDidAppear()
            },
            onLastSettingsWindowDidClose: {
                presentationController.handleLastSettingsWindowDidClose()
            }
        )
        let openDriver = SettingsSceneOpenDriver(
            resolveOpenAction: {
                {
                    bridge.handleSettingsDidAppear()
                }
            }
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { viewModel, _ in
                presentationController.cancelPendingAccessoryFallbackIfNeeded()
                presentationController.prepareToShowSettings()
                bridge.install(viewModel: viewModel)
                _ = openDriver.openSettingsWindow()
            }
        )

        application.launch()
        application.startGestureFlow()
        bridge.handleLastSettingsWindowDidClose()
        scheduledAccessoryFallback?()

        XCTAssertEqual(eventTap.stopCount, 0)
        XCTAssertTrue(application.isGestureFlowRunning)
        XCTAssertTrue(try store.load().isEnabled)
    }

    func testPreferencesMenuItemSchedulesSettingsPresentationAsynchronously() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var showSettingsCount = 0
        var scheduledOpenSettings: [() -> Void] = []
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { _, _ in showSettingsCount += 1 },
            scheduleOnMain: { scheduledOpenSettings.append($0) }
        )

        application.statusBarController?.performMenuItem(tag: StatusBarMenuItemTag.preferences)

        XCTAssertEqual(showSettingsCount, 0)
        XCTAssertEqual(scheduledOpenSettings.count, 1)

        scheduledOpenSettings.removeFirst()()

        XCTAssertEqual(showSettingsCount, 0)
        XCTAssertEqual(scheduledOpenSettings.count, 1)

        scheduledOpenSettings.removeFirst()()

        XCTAssertEqual(showSettingsCount, 0)
        XCTAssertEqual(scheduledOpenSettings.count, 1)

        scheduledOpenSettings.removeFirst()()

        XCTAssertEqual(showSettingsCount, 1)
    }

    func testQuitStopsGestureRecognitionUnderPresentationAwareSettingsFlow() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: permissionService,
            eventTap: eventTap
        )
        let presentationController = AppPresentationController(
            application: .shared,
            setActivationPolicy: { _ in true },
            activateApp: {},
            scheduleOnMain: { _ in }
        )
        let bridge = SettingsSceneBridge(
            onSettingsDidAppear: {
                presentationController.handleSettingsDidAppear()
            },
            onLastSettingsWindowDidClose: {
                presentationController.handleLastSettingsWindowDidClose()
            }
        )
        let openDriver = SettingsSceneOpenDriver(
            resolveOpenAction: {
                {
                    bridge.handleSettingsDidAppear()
                }
            }
        )
        var terminateCallCount = 0
        var wasStoppedBeforeTerminate = false
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            terminateApplication: { _ in
                terminateCallCount += 1
                wasStoppedBeforeTerminate = !gestureEngine.isRunning
            },
            showSettings: { viewModel, _ in
                presentationController.cancelPendingAccessoryFallbackIfNeeded()
                presentationController.prepareToShowSettings()
                bridge.install(viewModel: viewModel)
                _ = openDriver.openSettingsWindow()
            }
        )

        application.launch()
        application.startGestureFlow()
        application.statusBarController?.performMenuItem(title: "Quit")

        XCTAssertEqual(eventTap.stopCount, 1)
        XCTAssertEqual(terminateCallCount, 1)
        XCTAssertTrue(wasStoppedBeforeTerminate)
        XCTAssertFalse(try store.load().isEnabled)
        XCTAssertFalse(application.isGestureFlowRunning)
    }

    func testPreferencesMenuItemRoutesThroughSettingsWindowOpenDriver() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var scheduledOpenSettings: [() -> Void] = []
        let bridge = SettingsSceneBridge()
        var openSettingsWindowCount = 0
        let openDriver = SettingsSceneOpenDriver(
            resolveOpenAction: {
                { openSettingsWindowCount += 1 }
            }
        )
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { viewModel, _ in
                bridge.install(viewModel: viewModel)
                scheduledOpenSettings.append {
                    _ = openDriver.openSettingsWindow()
                }
            }
            ,
            scheduleOnMain: { scheduledOpenSettings.append($0) }
        )

        application.statusBarController?.performMenuItem(tag: StatusBarMenuItemTag.preferences)
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()
        XCTAssertEqual(openSettingsWindowCount, 0)
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()
        XCTAssertEqual(openSettingsWindowCount, 0)
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()
        XCTAssertEqual(openSettingsWindowCount, 0)
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()

        XCTAssertNotNil(bridge.viewModel)
        XCTAssertEqual(openSettingsWindowCount, 1)
    }

    func testReopeningSettingsReusesExistingViewModel() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let permissionService = PermissionService(
            trustCheck: { true },
            permissionPrompt: {}
        )
        let eventTap = ApplicationSpyMouseEventTapController()
        let gestureEngine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: permissionService,
            eventTap: eventTap
        )
        var shownViewModels: [SettingsViewModel] = []
        var scheduledOpenSettings: [() -> Void] = []
        let application = GestureFlowApplication(
            configurationStore: store,
            permissionService: permissionService,
            gestureEngine: gestureEngine,
            showSettings: { shownViewModels.append($0); _ = $1 },
            scheduleOnMain: { scheduledOpenSettings.append($0) }
        )

        application.launch()
        application.statusBarController?.performMenuItem(tag: StatusBarMenuItemTag.preferences)
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()
        XCTAssertEqual(scheduledOpenSettings.count, 1)
        scheduledOpenSettings.removeFirst()()

        XCTAssertEqual(shownViewModels.count, 2)
        XCTAssertTrue(shownViewModels[0] === shownViewModels[1])
    }

    private func makeTemporaryConfigURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("config.json")
    }
}

private final class ApplicationSpyMouseEventTapController: MouseEventTapControlling {
    var onGestureBegan: ((GestureTrigger, GesturePoint) -> Void)?
    var onGestureMoved: ((GesturePoint) -> Void)?
    var onGestureEnded: ((GestureTrigger, [GesturePoint]) -> Void)?
    var onGestureCancelled: (() -> Void)?
    var onRightClickTimeout: ((GesturePoint) -> Void)?
    var onRightClickTimeoutCleared: (() -> Void)?

    private let startResult: Bool
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(startResult: Bool = true) {
        self.startResult = startResult
    }

    func start() -> Bool {
        startCount += 1
        return startResult
    }

    func stop() {
        stopCount += 1
    }
}


private extension Notification.Name {
    static let testApplicationDidBecomeActive = Notification.Name("GestureFlowApplicationTests.didBecomeActive")
    static let testApplicationWillTerminate = Notification.Name("GestureFlowApplicationTests.willTerminate")
}
