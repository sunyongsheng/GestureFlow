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
    private var configurationDirectoryResolver: ConfigurationDirectoryResolver
    private var configurationStore: ConfigurationStore
    private let configurationDirectoryRelocator: ConfigurationDirectoryRelocator
    private let runtimeState: RuntimeState
    private let permissionService: PermissionService
    private let launchAtLoginService: LaunchAtLoginControlling
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
        configurationDirectoryResolver: ConfigurationDirectoryResolver? = nil,
        configurationStore: ConfigurationStore? = nil,
        gestureConfigurationService: GestureConfigurationService? = nil,
        configurationDirectoryRelocator: ConfigurationDirectoryRelocator? = nil,
        permissionService: PermissionService = PermissionService(),
        launchAtLoginService: LaunchAtLoginControlling = LaunchAtLoginService(),
        injectedGestureEngine: GestureEngine? = nil,
        notificationCenter: NotificationCenter = .default,
        activationNotificationName: Notification.Name = NSApplication.didBecomeActiveNotification,
        terminationNotificationName: Notification.Name = NSApplication.willTerminateNotification,
        terminateApplication: @escaping (NSApplication) -> Void = { $0.terminate(nil) },
        showSettings: @escaping (SettingsViewModel, SettingsPresentationSource) -> Void = { _, _ in },
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.application = application
        let resolvedResolver = configurationDirectoryResolver ?? ConfigurationDirectoryResolver.bootstrap()
        let resolvedConfigurationStore = configurationStore ?? resolvedResolver.makeConfigurationStore()
        let resolvedGestureService = gestureConfigurationService
            ?? GestureConfigurationService(store: resolvedResolver.makeGestureConfigurationStore())
        self.configurationDirectoryResolver = resolvedResolver
        self.configurationStore = resolvedConfigurationStore
        self.configurationDirectoryRelocator = configurationDirectoryRelocator
            ?? ConfigurationDirectoryRelocator(
                configurationDirectoryStore: resolvedResolver.configurationDirectoryStore
            )
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.notificationCenter = notificationCenter
        self.activationNotificationName = activationNotificationName
        self.terminationNotificationName = terminationNotificationName
        self.terminateApplication = terminateApplication
        self.showSettingsHandler = showSettings
        self.scheduleOnMain = scheduleOnMain
        self.initialLoadResult = resolvedConfigurationStore.loadRecovering()
        self.runtimeState = RuntimeState(
            appConfiguration: initialLoadResult.configuration,
            gestureConfigurationService: resolvedGestureService
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
            configurationDirectoryPath: configurationDirectoryResolver.displayPath(),
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled,
            saveConfiguration: { [weak self] newConfiguration in
                try self?.applySettingsConfiguration(newConfiguration)
            },
            saveGestureConfiguration: { [weak self] newGestureConfiguration in
                try self?.applyGestureConfiguration(newGestureConfiguration)
            },
            relocateConfigurationDirectory: { [weak self] newPath in
                try self?.relocateConfigurationDirectory(to: newPath)
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
            setLaunchAtLoginEnabled: { [weak self] isEnabled in
                try self?.launchAtLoginService.setEnabled(isEnabled)
            },
            launchAtLoginStatus: { [weak self] in
                self?.launchAtLoginService.isEnabled ?? false
            }
        )
    }

    func relocateConfigurationDirectory(to newPath: String) throws {
        try configurationStore.save(configuration)
        try runtimeState.gestureConfigurationService.save()

        let oldDirectory = configurationDirectoryResolver.configurationDirectoryURL
        let newDirectory = try configurationDirectoryRelocator.relocate(
            from: oldDirectory,
            to: newPath
        )

        configurationDirectoryResolver.apply(configurationDirectory: newDirectory)
        configurationStore = configurationDirectoryResolver.makeConfigurationStore()
        runtimeState.gestureConfigurationService.replaceStore(
            with: configurationDirectoryResolver.makeGestureConfigurationStore()
        )

        let loadResult = configurationStore.loadRecovering()
        configuration = loadResult.configuration
        runtimeState.appConfiguration = configuration
        runtimeState.gestureConfigurationService.load()

        if gestureEngine.isRunning {
            gestureEngine.stop()
            _ = gestureEngine.start()
        }

        syncRuntimePresentation()
        settingsViewModel?.updateRuntimeStatus(
            configuration: configuration,
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled
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
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled
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
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled
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
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled
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
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled
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
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled
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
