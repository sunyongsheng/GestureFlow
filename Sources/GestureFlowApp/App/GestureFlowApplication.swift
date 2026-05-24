import AppKit
import GestureFlowCore

protocol GestureFlowApplicationCoordinating: AnyObject {
    func launch()
}

enum SettingsPresentationSource {
    case launch
    case menuBar
}

final class GestureFlowApplication: GestureFlowApplicationCoordinating {
    private final class RuntimeState {
        var appConfiguration: AppConfiguration
        let gestureConfigurationService: GestureConfigurationService

        init(
            appConfiguration: AppConfiguration,
            gestureConfigurationService: GestureConfigurationService
        ) {
            self.appConfiguration = appConfiguration
            self.gestureConfigurationService = gestureConfigurationService
        }
    }

    private let application: NSApplication
    private let configurationStore: ConfigurationStore
    private let runtimeState: RuntimeState
    private let permissionService: PermissionService
    private let gestureEngine: GestureEngine
    private let notificationCenter: NotificationCenter
    private let activationNotificationName: Notification.Name
    private let terminationNotificationName: Notification.Name
    private let terminateApplication: (NSApplication) -> Void
    private let showSettingsHandler: (SettingsViewModel, SettingsPresentationSource) -> Void
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let initialLoadResult: ConfigurationLoadResult
    private var configuration: AppConfiguration
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var settingsViewModel: SettingsViewModel?
    private(set) var statusBarController: StatusBarController?

    var isGestureFlowRunning: Bool {
        configuration.isEnabled
    }

    init(
        application: NSApplication = .shared,
        configurationStore: ConfigurationStore = ConfigurationStore(),
        gestureConfigurationService: GestureConfigurationService = GestureConfigurationService(),
        permissionService: PermissionService = PermissionService(),
        injectedGestureEngine: GestureEngine? = nil,
        notificationCenter: NotificationCenter = .default,
        activationNotificationName: Notification.Name = NSApplication.didBecomeActiveNotification,
        terminationNotificationName: Notification.Name = NSApplication.willTerminateNotification,
        terminateApplication: @escaping (NSApplication) -> Void = { $0.terminate(nil) },
        showSettings: @escaping (SettingsViewModel, SettingsPresentationSource) -> Void = { _, _ in },
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.application = application
        self.configurationStore = configurationStore
        self.permissionService = permissionService
        self.notificationCenter = notificationCenter
        self.activationNotificationName = activationNotificationName
        self.terminationNotificationName = terminationNotificationName
        self.terminateApplication = terminateApplication
        self.showSettingsHandler = showSettings
        self.scheduleOnMain = scheduleOnMain
        self.initialLoadResult = configurationStore.loadRecovering()
        self.runtimeState = RuntimeState(
            appConfiguration: initialLoadResult.configuration,
            gestureConfigurationService: gestureConfigurationService
        )
        self.configuration = runtimeState.appConfiguration
        runtimeState.gestureConfigurationService.load()

        let runtimeState = self.runtimeState
        self.gestureEngine = injectedGestureEngine ?? GestureEngine(
            appConfigurationProvider: { runtimeState.appConfiguration },
            gestureConfigurationProvider: { runtimeState.gestureConfigurationService.configuration },
            permissionService: permissionService,
            eventTap: MouseEventTap(
                triggerConfigurationProvider: { runtimeState.appConfiguration.trigger }
            ),
            overlay: GestureOverlayWindow()
        )
        self.statusBarController = StatusBarController(actions: makeStatusBarActions())
        reconcilePersistedRunningState()
        self.statusBarController?.update(state: currentStatusBarState())
    }

    deinit {
        if let activationObserver {
            notificationCenter.removeObserver(activationObserver)
        }
        if let terminationObserver {
            notificationCenter.removeObserver(terminationObserver)
        }
    }

    func launch() {
        observeApplicationActivationIfNeeded()
        observeApplicationTerminationIfNeeded()
        openSettings(source: .launch)
        refreshApplicationState(promptIfNeeded: false)
        scheduleLaunchPermissionPromptIfNeeded()
    }

    func startGestureFlow() {
        guard permissionService.refreshAccessibilityTrust() else {
            permissionService.promptForAccessibilityPermission()
            refreshApplicationState(promptIfNeeded: false)
            setGestureFlowEnabled(false)
            return
        }

        guard gestureEngine.start() else {
            setGestureFlowEnabled(false)
            return
        }

        setGestureFlowEnabled(true)
    }

    func stopGestureFlow() {
        stopGestureEngine(persistUserPreference: true)
    }

    /// Stops listening without changing the persisted enabled preference (e.g. app quit).
    private func stopGestureEngine(persistUserPreference: Bool) {
        gestureEngine.stop()
        if persistUserPreference {
            setGestureFlowEnabled(false)
        } else {
            syncRuntimePresentation()
        }
    }

    private func makeStatusBarActions() -> StatusBarActions {
        StatusBarActions(
            start: { [weak self] in self?.startGestureFlow() },
            stop: { [weak self] in self?.stopGestureFlow() },
            openSettings: { [weak self] in self?.scheduleOpenSettings() },
            quit: { [weak self] in self?.quitApplication() }
        )
    }

    private func quitApplication() {
        stopGestureEngine(persistUserPreference: false)
        terminateApplication(application)
    }

    private func scheduleOpenSettings() {
        scheduleOnMain { [weak self] in
            self?.openSettings(source: .menuBar)
        }
    }

    private func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: configuration,
                didRecoverFromCorruption: initialLoadResult.didRecoverFromCorruption,
                backupURL: initialLoadResult.backupURL
            ),
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            saveConfiguration: { [weak self] newConfiguration in
                try self?.applySettingsConfiguration(newConfiguration)
            },
            saveGestureConfiguration: { [weak self] newGestureConfiguration in
                try self?.applyGestureConfiguration(newGestureConfiguration)
            },
            requestAccessibilityPermission: { [weak self] in
                self?.permissionService.promptForAccessibilityPermission()
            },
            startGestureFlow: { [weak self] in
                self?.startGestureFlow()
            },
            stopGestureFlow: { [weak self] in
                self?.stopGestureFlow()
            },
            quitApplication: { [weak self] in
                self?.quitApplication()
            },
            showLaunchAtLoginPlaceholder: { [weak self] in
                self?.showPlaceholder(
                    title: "登录时打开",
                    message: "此功能尚未实现。"
                )
            }
        )
    }

    private func applySettingsConfiguration(_ newConfiguration: AppConfiguration) throws {
        configuration = newConfiguration
        runtimeState.appConfiguration = newConfiguration
        try configurationStore.save(configuration)
        statusBarController?.update(state: currentStatusBarState())
        settingsViewModel?.updateRuntimeStatus(
            configuration: configuration,
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted
        )
    }

    private func applyGestureConfiguration(_ newGestureConfiguration: GestureConfiguration) throws {
        runtimeState.gestureConfigurationService.configuration = newGestureConfiguration
        try runtimeState.gestureConfigurationService.save()
        settingsViewModel?.syncGestureConfiguration(runtimeState.gestureConfigurationService.configuration)
        settingsViewModel?.updateRuntimeStatus(
            configuration: configuration,
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted
        )
    }

    private func setGestureFlowEnabled(_ isEnabled: Bool) {
        configuration.isEnabled = isEnabled
        runtimeState.appConfiguration.isEnabled = isEnabled
        do {
            try configurationStore.save(configuration)
            syncRuntimePresentation()
        } catch {
            showPlaceholder(title: "GestureFlow", message: "Failed to save configuration: \(error)")
        }
    }

    private func syncRuntimePresentation() {
        statusBarController?.update(state: currentStatusBarState())
        settingsViewModel?.updateRuntimeStatus(
            configuration: configuration,
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted
        )
    }

    private func reconcilePersistedRunningState() {
        guard configuration.isEnabled else { return }

        guard permissionService.isAccessibilityTrusted, gestureEngine.start() else {
            setGestureFlowEnabled(false)
            return
        }
    }

    private func observeApplicationActivationIfNeeded() {
        guard activationObserver == nil else { return }

        activationObserver = notificationCenter.addObserver(
            forName: activationNotificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.refreshApplicationState(promptIfNeeded: false)
        }
    }

    private func observeApplicationTerminationIfNeeded() {
        guard terminationObserver == nil else { return }

        terminationObserver = notificationCenter.addObserver(
            forName: terminationNotificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.stopGestureEngine(persistUserPreference: false)
        }
    }

    private func refreshApplicationState(promptIfNeeded: Bool) {
        let isAccessibilityTrusted = permissionService.refreshAccessibilityTrust()

        if promptIfNeeded, !isAccessibilityTrusted {
            permissionService.promptForAccessibilityPermission()
            _ = permissionService.refreshAccessibilityTrust()
        }

        if !permissionService.isAccessibilityTrusted, gestureEngine.isRunning {
            stopGestureFlow()
            return
        }

        statusBarController?.update(state: currentStatusBarState())
        settingsViewModel?.updateRuntimeStatus(
            configuration: configuration,
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted
        )
    }

    private func scheduleLaunchPermissionPromptIfNeeded() {
        guard !permissionService.isAccessibilityTrusted else { return }

        scheduleOnMain { [weak self] in
            guard let self else { return }
            guard !self.permissionService.refreshAccessibilityTrust() else {
                self.refreshApplicationState(promptIfNeeded: false)
                return
            }

            self.permissionService.promptForAccessibilityPermission()
            self.refreshApplicationState(promptIfNeeded: false)
        }
    }

    private func openSettings(source: SettingsPresentationSource) {
        let viewModel = settingsViewModel ?? makeSettingsViewModel()
        settingsViewModel = viewModel
        viewModel.updateRuntimeStatus(
            configuration: configuration,
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted
        )
        showSettingsHandler(viewModel, source)
    }

    private func currentStatusBarState() -> StatusBarState {
        StatusBarState(
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted
        )
    }

    private func showPlaceholder(title: String, message: String = "This screen will be added in a later task.") {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
