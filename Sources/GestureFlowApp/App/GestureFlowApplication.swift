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
    private var appConfigurationStore: AppConfigurationStore
    private let configurationDirectoryRelocator: ConfigurationDirectoryRelocator
    private let runtimeState: RuntimeState
    private let permissionService: PermissionService
    private let launchAtLoginService: LaunchAtLoginControlling
    private let appUpdateService: AppUpdateService
    private let gestureEngine: GestureEngine
    private let notificationCenter: NotificationCenter
    private let activationNotificationName: Notification.Name
    private let terminationNotificationName: Notification.Name
    private let terminateApplication: (NSApplication) -> Void
    private let showSettingsHandler: (SettingsViewModel, SettingsPresentationSource) -> Void
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let initialLoadResult: ConfigurationLoadResult
    private let localizationManager: LocalizationManager
    private var configuration: AppConfiguration
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var settingsViewModel: SettingsViewModel?
    private(set) var statusBarController: StatusBarController?
    private var gestureRecognitionWasRunningBeforeRecordingPause = false
    private let autoPromptAccessibilityOnLaunch: Bool

    var isGestureFlowRunning: Bool {
        configuration.isEnabled
    }

    init(
        application: NSApplication = .shared,
        configurationDirectoryResolver: ConfigurationDirectoryResolver? = nil,
        appConfigurationStore: AppConfigurationStore? = nil,
        gestureConfigurationService: GestureConfigurationService? = nil,
        configurationDirectoryRelocator: ConfigurationDirectoryRelocator? = nil,
        permissionService: PermissionService = PermissionService(),
        launchAtLoginService: LaunchAtLoginControlling = LaunchAtLoginService(),
        appUpdateService: AppUpdateService? = nil,
        injectedGestureEngine: GestureEngine? = nil,
        notificationCenter: NotificationCenter = .default,
        activationNotificationName: Notification.Name = NSApplication.didBecomeActiveNotification,
        terminationNotificationName: Notification.Name = NSApplication.willTerminateNotification,
        terminateApplication: @escaping (NSApplication) -> Void = { $0.terminate(nil) },
        showSettings: @escaping (SettingsViewModel, SettingsPresentationSource) -> Void = { _, _ in },
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
        autoPromptAccessibilityOnLaunch: Bool = {
            #if DEBUG
            false
            #else
            true
            #endif
        }()
    ) {
        self.application = application
        self.autoPromptAccessibilityOnLaunch = autoPromptAccessibilityOnLaunch
        let resolvedResolver = configurationDirectoryResolver ?? ConfigurationDirectoryResolver.bootstrap()
        let resolvedAppConfigurationStore = appConfigurationStore ?? resolvedResolver.makeAppConfigurationStore()
        let resolvedGestureService = gestureConfigurationService
            ?? GestureConfigurationService(
                builtinStore: resolvedResolver.makeBuiltinGestureConfigurationStore(),
                customStore: resolvedResolver.makeCustomGestureConfigurationStore()
            )
        self.configurationDirectoryResolver = resolvedResolver
        self.appConfigurationStore = resolvedAppConfigurationStore
        self.configurationDirectoryRelocator = configurationDirectoryRelocator
            ?? ConfigurationDirectoryRelocator(
                configurationDirectoryStore: resolvedResolver.configurationDirectoryStore
            )
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.initialLoadResult = resolvedAppConfigurationStore.loadRecovering()
        let updatePreferencesStore = UpdatePreferencesStore()
        let updateScheduler = UpdateScheduler(intervalHours: initialLoadResult.configuration.update.checkIntervalHours)
        let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        self.appUpdateService = appUpdateService ?? AppUpdateService(
            releaseClient: GitHubReleaseClient(currentAppVersion: currentAppVersion),
            updateController: AppUpdateController(),
            preferencesStore: updatePreferencesStore,
            scheduler: updateScheduler,
            currentAppVersion: currentAppVersion
        )
        self.notificationCenter = notificationCenter
        self.activationNotificationName = activationNotificationName
        self.terminationNotificationName = terminationNotificationName
        self.terminateApplication = terminateApplication
        self.showSettingsHandler = showSettings
        self.scheduleOnMain = scheduleOnMain
        self.runtimeState = RuntimeState(
            appConfiguration: initialLoadResult.configuration,
            gestureConfigurationService: resolvedGestureService
        )
        self.configuration = runtimeState.appConfiguration
        runtimeState.gestureConfigurationService.load()

        let localizationManager = LocalizationManager()
        self.localizationManager = localizationManager
        AppServices.localization = localizationManager

        let runtimeState = self.runtimeState
        let targetResolver = GestureTargetApplicationResolver()
        let activationGate = GestureActivationGate(
            configurationProvider: { runtimeState.appConfiguration },
            targetResolver: targetResolver
        )
        self.gestureEngine = injectedGestureEngine ?? GestureEngine(
            appConfigurationProvider: { runtimeState.appConfiguration },
            gestureConfigurationProvider: { runtimeState.gestureConfigurationService.configuration },
            permissionService: permissionService,
            eventTap: MouseEventTap(
                triggerConfigurationProvider: { runtimeState.appConfiguration.trigger },
                gestureActivationGate: { activationGate.resolvedTargetForGestureActivation(at: $0) }
            ),
            overlay: GestureOverlayWindow(localization: localizationManager)
        )
        self.statusBarController = StatusBarController(
            actions: makeStatusBarActions(),
            localization: localizationManager
        )
        self.statusBarController?.isVisible = configuration.general.showMenuBarIcon
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
        startAutomaticUpdatesIfNeeded()
        openSettings(source: .launch)
        refreshApplicationState(promptIfNeeded: false)
        scheduleLaunchPermissionPromptIfNeeded()
    }

    private func startAutomaticUpdatesIfNeeded() {
        appUpdateService.startAutomaticUpdatesIfNeeded { [weak self] in
            Task { await self?.appUpdateService.checkForUpdatesIfNeeded(force: false) }
        }
    }

    private func makeUpdateSchedulerCallback() -> () -> Void {
        { [weak self] in
            Task { await self?.appUpdateService.checkForUpdatesIfNeeded(force: false) }
        }
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

    func pauseGestureRecognitionForCustomSignatureRecording() {
        gestureRecognitionWasRunningBeforeRecordingPause = gestureEngine.isRunning
        if gestureRecognitionWasRunningBeforeRecordingPause {
            gestureEngine.stop()
        }
    }

    func resumeGestureRecognitionAfterCustomSignatureRecording() {
        if gestureRecognitionWasRunningBeforeRecordingPause {
            _ = gestureEngine.start()
        }
        gestureRecognitionWasRunningBeforeRecordingPause = false
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
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: configuration,
                didRecoverFromCorruption: initialLoadResult.didRecoverFromCorruption,
                backupURL: initialLoadResult.backupURL
            ),
            gestureConfiguration: runtimeState.gestureConfigurationService.configuration,
            conflictingGestureIDs: runtimeState.gestureConfigurationService.conflictingGestureIDs,
            configurationDirectoryPath: configurationDirectoryResolver.displayPath(),
            isRunning: gestureEngine.isRunning,
            isAccessibilityTrusted: permissionService.isAccessibilityTrusted,
            isLaunchAtLoginEnabled: launchAtLoginService.isEnabled,
            isAutomaticUpdateEnabled: appUpdateService.isAutomaticUpdateEnabled,
            canCheckForUpdates: appUpdateService.canCheckForUpdates,
            localizationManager: localizationManager,
            saveConfiguration: { [weak self] newConfiguration in
                try self?.applySettingsConfiguration(newConfiguration)
            },
            saveGestureConfiguration: { [weak self] newGestureConfiguration in
                try self?.applyGestureConfiguration(newGestureConfiguration)
            },
            relocateConfigurationDirectory: { [weak self] newPath, mode in
                try self?.relocateConfigurationDirectory(to: newPath, mode: mode)
            },
            targetHasConfigurationFiles: { [weak self] path in
                self?.configurationDirectoryRelocator.targetHasConfigurationFiles(at: path) ?? false
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
            },
            setAutomaticUpdateEnabled: { [weak self] isEnabled in
                self?.appUpdateService.setAutomaticUpdateEnabled(isEnabled) {
                    self?.makeUpdateSchedulerCallback()()
                }
            },
            checkForUpdates: { [weak self] in
                guard let self, let viewModel = self.settingsViewModel else { return }
                Task {
                    await self.appUpdateService.checkForUpdatesIfNeeded(
                        force: true,
                        onManualProgress: { viewModel.setUpdateCheckInProgress($0) },
                        onManualOutcome: { [weak self] outcome in
                            self?.presentManualUpdateCheckOutcome(outcome, viewModel: viewModel)
                        }
                    )
                }
            },
            pauseGestureRecognition: { [weak self] in
                self?.pauseGestureRecognitionForCustomSignatureRecording()
            },
            resumeGestureRecognition: { [weak self] in
                self?.resumeGestureRecognitionAfterCustomSignatureRecording()
            }
        )
        viewModel.onLanguageDidChange = { [weak self] in
            self?.statusBarController?.refreshLocalizedStrings()
            self?.statusBarController?.update(state: self?.currentStatusBarState() ?? StatusBarState(
                isRunning: false,
                isAccessibilityTrusted: false
            ))
        }
        return viewModel
    }

    func relocateConfigurationDirectory(
        to newPath: String,
        mode: ConfigurationDirectoryRelocationMode = .copyCurrentToEmptyTarget
    ) throws {
        if mode == .copyCurrentToEmptyTarget {
            try appConfigurationStore.save(configuration)
            try runtimeState.gestureConfigurationService.save()
        }

        let oldDirectory = configurationDirectoryResolver.configurationDirectoryURL
        let newDirectory = try configurationDirectoryRelocator.relocate(
            from: oldDirectory,
            to: newPath,
            mode: mode
        )

        configurationDirectoryResolver.apply(configurationDirectory: newDirectory)
        appConfigurationStore = configurationDirectoryResolver.makeAppConfigurationStore()
        runtimeState.gestureConfigurationService.replaceStores(
            builtinStore: configurationDirectoryResolver.makeBuiltinGestureConfigurationStore(),
            customStore: configurationDirectoryResolver.makeCustomGestureConfigurationStore()
        )

        let loadResult = appConfigurationStore.loadRecovering()
        configuration = loadResult.configuration
        runtimeState.appConfiguration = configuration
        runtimeState.gestureConfigurationService.load()

        if gestureEngine.isRunning {
            gestureEngine.stop()
            _ = gestureEngine.start()
        }

        syncRuntimePresentation()
        settingsViewModel?.syncGestureConfiguration(runtimeState.gestureConfigurationService.configuration)
        settingsViewModel?.syncGestureMergeConflicts(runtimeState.gestureConfigurationService.conflictingGestureIDs)
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
        try appConfigurationStore.save(configuration)
        statusBarController?.isVisible = configuration.general.showMenuBarIcon
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
        settingsViewModel?.syncGestureMergeConflicts(runtimeState.gestureConfigurationService.conflictingGestureIDs)
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
            try appConfigurationStore.save(configuration)
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

        guard permissionService.isAccessibilityTrusted else {
            setGestureFlowEnabled(false)
            return
        }

        guard gestureEngine.start(promptIfUntrusted: false) else {
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
            self?.appUpdateService.stopAutomaticUpdates()
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
        guard autoPromptAccessibilityOnLaunch else { return }
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

    private func presentManualUpdateCheckOutcome(
        _ outcome: ManualUpdateCheckOutcome,
        viewModel: SettingsViewModel
    ) {
        switch outcome {
        case .delegatedToSparkle:
            break
        case .installUnavailableInDevelopment(let latestVersion, let releaseNotes):
            var message = localizationManager.format(
                .aboutUpdateAvailableInDevelopmentMessage,
                latestVersion.description
            )
            if let releaseNotes, !releaseNotes.isEmpty {
                message += "\n\n" + releaseNotes
            }
            viewModel.presentUpdateCheckAlert(
                title: localizationManager.string(.aboutUpdateAvailableInDevelopmentTitle),
                message: message
            )
        case .upToDate:
            viewModel.presentUpdateCheckAlert(
                title: localizationManager.string(.aboutUpdateUpToDateTitle),
                message: localizationManager.format(
                    .aboutUpdateUpToDateMessage,
                    currentVersionString()
                )
            )
        case .failed(let error):
            viewModel.presentUpdateCheckAlert(
                title: localizationManager.string(.aboutUpdateCheckFailedTitle),
                message: localizationManager.message(for: error)
            )
        }
    }

    private func currentVersionString() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func showPlaceholder(title: String, message: String = "This screen will be added in a later task.") {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
