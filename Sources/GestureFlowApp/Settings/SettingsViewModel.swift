import AppKit
import Foundation
import GestureFlowCore
import UniformTypeIdentifiers

final class SettingsViewModel: ObservableObject {
    @Published private(set) var configuration: AppConfiguration
    @Published var gestureConfiguration: GestureConfiguration
    @Published private(set) var recoveryBackupPath: String?
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var gestureSaveErrorMessage: String?
    private var gestureMergeConflictIDs: [UUID] = []
    @Published private(set) var isRunning: Bool
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published private(set) var isLaunchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginErrorMessage: String?
    @Published private(set) var isAutomaticUpdateEnabled: Bool
    @Published private(set) var canCheckForUpdates: Bool
    @Published private(set) var isCheckingForUpdates = false
    @Published var isUpdateCheckAlertPresented = false
    @Published private(set) var updateCheckAlertTitle = ""
    @Published private(set) var updateCheckAlertMessage = ""
    @Published var selectedApplicationScope: GestureApplicationScope = .global
    @Published var draftConfigurationDirectoryPath: String
    @Published private(set) var persistedConfigurationDirectoryPath: String
    @Published private(set) var isRelocatingConfigurationDirectory = false
    @Published private(set) var configurationDirectoryErrorMessage: String?
    @Published var isConfigurationDirectoryAdoptionAlertPresented = false

    private var unsavedGestureIDs: Set<UUID> = []
    private var pendingConfigurationDirectoryPath: String?
    private let didRecoverFromCorruption: Bool

    let localizationManager: LocalizationManager
    var onLanguageDidChange: (() -> Void)?

    private let saveConfiguration: (AppConfiguration) throws -> Void
    private let saveGestureConfiguration: (GestureConfiguration) throws -> Void
    private let relocateConfigurationDirectoryAction: (String, ConfigurationDirectoryRelocationMode) throws -> Void
    private let targetHasConfigurationFiles: (String) -> Bool
    private let permissionPrompt: () -> Void
    private let startGestureFlowAction: () -> Void
    private let stopGestureFlowAction: () -> Void
    private let quitApplicationAction: () -> Void
    private let setLaunchAtLoginEnabledAction: (Bool) throws -> Void
    private let launchAtLoginStatusProvider: () -> Bool
    private let setAutomaticUpdateEnabledAction: (Bool) -> Void
    private let checkForUpdatesAction: () -> Void
    private let openApplicationPanel: () -> URL?
    let pauseGestureRecognition: () -> Void
    let resumeGestureRecognition: () -> Void

    init(
        loadResult: ConfigurationLoadResult,
        gestureConfiguration: GestureConfiguration,
        conflictingGestureIDs: [UUID] = [],
        configurationDirectoryPath: String = "~",
        isRunning: Bool,
        isAccessibilityTrusted: Bool,
        isLaunchAtLoginEnabled: Bool = false,
        isAutomaticUpdateEnabled: Bool = false,
        canCheckForUpdates: Bool = true,
        localizationManager: LocalizationManager = LocalizationManager(),
        saveConfiguration: @escaping (AppConfiguration) throws -> Void,
        saveGestureConfiguration: @escaping (GestureConfiguration) throws -> Void,
        relocateConfigurationDirectory: @escaping (String, ConfigurationDirectoryRelocationMode) throws -> Void = { _, _ in },
        targetHasConfigurationFiles: @escaping (String) -> Bool = { _ in false },
        requestAccessibilityPermission: @escaping () -> Void,
        startGestureFlow: @escaping () -> Void,
        stopGestureFlow: @escaping () -> Void,
        quitApplication: @escaping () -> Void,
        setLaunchAtLoginEnabled: @escaping (Bool) throws -> Void = { _ in },
        launchAtLoginStatus: @escaping () -> Bool = { false },
        setAutomaticUpdateEnabled: @escaping (Bool) -> Void = { _ in },
        checkForUpdates: @escaping () -> Void = {},
        openApplicationPanel: @escaping () -> URL? = SettingsViewModel.defaultOpenApplicationPanel,
        pauseGestureRecognition: @escaping () -> Void,
        resumeGestureRecognition: @escaping () -> Void
    ) {
        self.configuration = loadResult.configuration
        self.gestureConfiguration = gestureConfiguration
        self.didRecoverFromCorruption = loadResult.didRecoverFromCorruption
        self.recoveryBackupPath = loadResult.backupURL?.path
        self.localizationManager = localizationManager
        self.persistedConfigurationDirectoryPath = configurationDirectoryPath
        self.draftConfigurationDirectoryPath = configurationDirectoryPath
        self.isRunning = isRunning
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.isAutomaticUpdateEnabled = isAutomaticUpdateEnabled
        self.canCheckForUpdates = canCheckForUpdates
        self.saveConfiguration = saveConfiguration
        self.saveGestureConfiguration = saveGestureConfiguration
        self.relocateConfigurationDirectoryAction = relocateConfigurationDirectory
        self.targetHasConfigurationFiles = targetHasConfigurationFiles
        self.permissionPrompt = requestAccessibilityPermission
        self.startGestureFlowAction = startGestureFlow
        self.stopGestureFlowAction = stopGestureFlow
        self.quitApplicationAction = quitApplication
        self.setLaunchAtLoginEnabledAction = setLaunchAtLoginEnabled
        self.launchAtLoginStatusProvider = launchAtLoginStatus
        self.setAutomaticUpdateEnabledAction = setAutomaticUpdateEnabled
        self.checkForUpdatesAction = checkForUpdates
        self.openApplicationPanel = openApplicationPanel
        self.pauseGestureRecognition = pauseGestureRecognition
        self.resumeGestureRecognition = resumeGestureRecognition
        syncGestureMergeConflicts(conflictingGestureIDs)
    }

    var recoveryNoticeMessage: String? {
        guard didRecoverFromCorruption else { return nil }
        if let recoveryBackupPath {
            return localizationManager.format(.recoveryWithBackup, recoveryBackupPath)
        }
        return localizationManager.string(.recoveryWithoutBackup)
    }

    var registeredApplicationBundleIdentifiers: [String] {
        gestureConfiguration.applicationBundleIdentifiers.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard localizationManager.language != language else { return }
        localizationManager.setLanguage(language)
        onLanguageDidChange?()
    }

    func setShowMenuBarIcon(_ show: Bool) {
        configuration.general.showMenuBarIcon = show
        do {
            try saveConfiguration(configuration)
            saveErrorMessage = nil
        } catch {
            configuration.general.showMenuBarIcon = !show
            saveErrorMessage = error.localizedDescription
        }
    }

    func localizedGestureName(_ gesture: GestureDefinition) -> String {
        localizationManager.localizedGestureDisplayName(gesture)
    }

    func gestures(for scopeBundleIdentifier: String?) -> [GestureDefinition] {
        gestureConfiguration.gestures.filter {
            $0.targetBundleIdentifier == scopeBundleIdentifier
        }
    }

    func displayName(for bundleIdentifier: String) -> String {
        Self.displayName(forBundleIdentifier: bundleIdentifier)
    }

    func addApplicationFromPanel() {
        guard let applicationURL = openApplicationPanel() else {
            return
        }

        guard let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier else {
            gestureSaveErrorMessage = localizationManager.string(.errorBundleIdentifierUnreadable)
            return
        }

        guard !gestureConfiguration.applicationBundleIdentifiers.contains(bundleIdentifier) else {
            selectedApplicationScope = .application(bundleIdentifier: bundleIdentifier)
            gestureSaveErrorMessage = nil
            return
        }

        var updatedConfiguration = gestureConfiguration
        updatedConfiguration.applicationBundleIdentifiers.append(bundleIdentifier)
        gestureConfiguration = updatedConfiguration
        selectedApplicationScope = .application(bundleIdentifier: bundleIdentifier)
        persistGestureConfiguration()
    }

    func removeApplication(bundleIdentifier: String) {
        var updatedConfiguration = gestureConfiguration
        updatedConfiguration.applicationBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        updatedConfiguration.gestures.removeAll { $0.targetBundleIdentifier == bundleIdentifier }
        gestureConfiguration = updatedConfiguration

        if selectedApplicationScope.targetBundleIdentifier == bundleIdentifier {
            selectedApplicationScope = .global
        }

        persistGestureConfiguration()
    }

    @discardableResult
    func addGesture() -> UUID {
        let gesture = GestureDefinition(
            targetBundleIdentifier: selectedApplicationScope.targetBundleIdentifier,
            name: localizationManager.string(.gesturesNewGestureName),
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            shortcut: KeyboardShortcutAction(keyCode: 0, modifiers: []),
            source: .custom
        )
        var updatedConfiguration = gestureConfiguration
        updatedConfiguration.gestures.append(gesture)
        gestureConfiguration = updatedConfiguration
        unsavedGestureIDs.insert(gesture.id)
        return gesture.id
    }

    func isGesturePendingSave(id: UUID) -> Bool {
        unsavedGestureIDs.contains(id)
    }

    func deleteGestures(at offsets: IndexSet, in scopeBundleIdentifier: String?) {
        let scopedGestures = gestures(for: scopeBundleIdentifier)
        let idsToDelete = Set(offsets.map { scopedGestures[$0].id })
        deleteGestures(withIDs: idsToDelete)
    }

    func deleteGestures(withIDs ids: Set<UUID>) {
        guard !ids.isEmpty else { return }

        let shouldPersist = ids.contains { !unsavedGestureIDs.contains($0) }
        var updatedConfiguration = gestureConfiguration
        updatedConfiguration.gestures.removeAll { ids.contains($0.id) }
        gestureConfiguration = updatedConfiguration
        unsavedGestureIDs.subtract(ids)

        if shouldPersist {
            persistGestureConfiguration()
        } else {
            gestureSaveErrorMessage = nil
        }
    }

    func stageGestureUpdate(id: UUID, _ update: (inout GestureDefinition) -> Void) {
        guard let index = gestureConfiguration.gestures.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updatedConfiguration = gestureConfiguration
        update(&updatedConfiguration.gestures[index])
        gestureConfiguration = updatedConfiguration
        unsavedGestureIDs.insert(id)
    }

    func commitGesture(id: UUID) {
        guard unsavedGestureIDs.contains(id) else { return }
        guard let gesture = gestureConfiguration.gestures.first(where: { $0.id == id }) else {
            return
        }

        guard gesture.shortcut.isRecorded else {
            gestureSaveErrorMessage = localizationManager.string(.errorRecordShortcut)
            return
        }

        persistGestureConfiguration()
        if gestureSaveErrorMessage == nil {
            unsavedGestureIDs.remove(id)
        }
    }

    func updateFeedback(_ update: (inout FeedbackConfiguration) -> Void) {
        update(&configuration.feedback)
        persistAppConfiguration()
    }

    func updateTriggerConfiguration(_ update: (inout GestureTriggerConfiguration) -> Void) {
        update(&configuration.trigger)
        persistAppConfiguration()
    }

    func updateGestureTargetApplication(_ target: GestureTargetApplication) {
        configuration.gestureTargetApplication = target
        persistAppConfiguration()
    }

    var ignoredApplicationBundleIdentifiers: [String] {
        configuration.ignoredApplicationBundleIdentifiers
    }

    var runningApplicationsAvailableForIgnore: [(bundleIdentifier: String, name: String)] {
        let ignored = Set(configuration.ignoredApplicationBundleIdentifiers)
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && application.bundleIdentifier.map { bundleIdentifier in
                        bundleIdentifier != ownBundleIdentifier && !ignored.contains(bundleIdentifier)
                    } ?? false
            }
            .compactMap { application -> (bundleIdentifier: String, name: String)? in
                guard let bundleIdentifier = application.bundleIdentifier else { return nil }
                let name = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = (name?.isEmpty == false) ? name! : Self.displayName(forBundleIdentifier: bundleIdentifier)
                return (bundleIdentifier, resolvedName)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addIgnoredApplicationFromPanel() {
        guard let applicationURL = openApplicationPanel() else {
            return
        }

        guard let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier else {
            saveErrorMessage = localizationManager.string(.errorBundleIdentifierUnreadable)
            return
        }

        addIgnoredApplication(bundleIdentifier: bundleIdentifier)
    }

    func addIgnoredApplication(bundleIdentifier: String) {
        guard !isOwnBundleIdentifier(bundleIdentifier) else { return }
        guard !configuration.ignoredApplicationBundleIdentifiers.contains(bundleIdentifier) else { return }

        configuration.ignoredApplicationBundleIdentifiers.append(bundleIdentifier)
        persistAppConfiguration()
    }

    func removeIgnoredApplication(bundleIdentifier: String) {
        configuration.ignoredApplicationBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        persistAppConfiguration()
    }

    func requestAccessibilityPermission() {
        permissionPrompt()
    }

    func setGestureRecognitionEnabled(_ isEnabled: Bool) {
        if isEnabled {
            startGestureFlowAction()
        } else {
            stopGestureFlowAction()
        }
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            try setLaunchAtLoginEnabledAction(isEnabled)
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }
        isLaunchAtLoginEnabled = launchAtLoginStatusProvider()
    }

    func setAutomaticUpdateEnabled(_ isEnabled: Bool) {
        setAutomaticUpdateEnabledAction(isEnabled)
        isAutomaticUpdateEnabled = isEnabled
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        checkForUpdatesAction()
    }

    func setUpdateCheckInProgress(_ inProgress: Bool) {
        isCheckingForUpdates = inProgress
    }

    func presentUpdateCheckAlert(title: String, message: String) {
        updateCheckAlertTitle = title
        updateCheckAlertMessage = message
        isUpdateCheckAlertPresented = true
    }

    func quitApplication() {
        quitApplicationAction()
    }

    var canConfirmConfigurationDirectoryChange: Bool {
        !ConfigurationPathFormatting.normalizedPathsEqual(
            draftConfigurationDirectoryPath,
            persistedConfigurationDirectoryPath
        )
    }

    func prefillDefaultConfigurationDirectory() {
        draftConfigurationDirectoryPath = ConfigurationDirectoryResolver.defaultConfigurationDirectoryDisplayPath
        configurationDirectoryErrorMessage = nil
    }

    func prefillXDGConfigurationDirectory() {
        draftConfigurationDirectoryPath = ConfigurationDirectoryResolver.xdgConfigurationDirectoryDisplayPath()
        configurationDirectoryErrorMessage = nil
    }

    func confirmConfigurationDirectoryChange() {
        guard canConfirmConfigurationDirectoryChange else {
            return
        }

        configurationDirectoryErrorMessage = nil

        if targetHasConfigurationFiles(draftConfigurationDirectoryPath) {
            pendingConfigurationDirectoryPath = draftConfigurationDirectoryPath
            isConfigurationDirectoryAdoptionAlertPresented = true
            return
        }

        performConfigurationDirectoryRelocation(
            path: draftConfigurationDirectoryPath,
            mode: .copyCurrentToEmptyTarget
        )
    }

    func confirmConfigurationDirectoryAdoption() {
        guard let path = pendingConfigurationDirectoryPath else {
            return
        }

        pendingConfigurationDirectoryPath = nil
        isConfigurationDirectoryAdoptionAlertPresented = false
        performConfigurationDirectoryRelocation(
            path: path,
            mode: .adoptTargetAndMergeMissing
        )
    }

    func cancelConfigurationDirectoryAdoption() {
        pendingConfigurationDirectoryPath = nil
        isConfigurationDirectoryAdoptionAlertPresented = false
    }

    private func performConfigurationDirectoryRelocation(
        path: String,
        mode: ConfigurationDirectoryRelocationMode
    ) {
        isRelocatingConfigurationDirectory = true
        defer { isRelocatingConfigurationDirectory = false }

        do {
            try relocateConfigurationDirectoryAction(path, mode)
            persistedConfigurationDirectoryPath = path
            configurationDirectoryErrorMessage = nil
        } catch let error as ConfigurationDirectoryRelocationError {
            configurationDirectoryErrorMessage = localizationManager.message(for: error)
        } catch {
            configurationDirectoryErrorMessage = error.localizedDescription
        }
    }

    func updateRuntimeStatus(
        configuration: AppConfiguration? = nil,
        gestureConfiguration: GestureConfiguration? = nil,
        isRunning: Bool,
        isAccessibilityTrusted: Bool,
        isLaunchAtLoginEnabled: Bool? = nil
    ) {
        if let configuration {
            self.configuration = configuration
        }
        if let gestureConfiguration {
            self.gestureConfiguration = gestureConfiguration
        }
        self.isRunning = isRunning
        self.isAccessibilityTrusted = isAccessibilityTrusted
        if let isLaunchAtLoginEnabled {
            self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        }
    }

    func syncGestureConfiguration(_ configuration: GestureConfiguration) {
        gestureConfiguration = configuration
        unsavedGestureIDs.removeAll()
    }

    func syncGestureMergeConflicts(_ conflictingGestureIDs: [UUID]) {
        gestureMergeConflictIDs = conflictingGestureIDs
        if !conflictingGestureIDs.isEmpty {
            gestureSaveErrorMessage = localizationManager.string(.errorGestureMergeConflict)
        }
    }

    func restoreDefaultGestureConfiguration() {
        gestureConfiguration = GestureConfiguration.defaultTemplate
        selectedApplicationScope = .global
        unsavedGestureIDs.removeAll()
        persistGestureConfiguration()
    }

    func commitGestureConfigurationToDisk() {
        persistGestureConfiguration()
    }

    func restoreDefaultAdvancedSettings() {
        configuration.feedback = .default
        configuration.trigger = .default
        configuration.gestureTargetApplication = .defaultValue
        configuration.ignoredApplicationBundleIdentifiers = []
        persistAppConfiguration()
    }

    private func isOwnBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private func persistGestureConfiguration() {
        if !gestureMergeConflictIDs.isEmpty {
            gestureSaveErrorMessage = localizationManager.string(.errorGestureMergeConflict)
            return
        }

        let conflicts = ConflictDetector().detect(in: gestureConfiguration.gestures)
        guard conflicts.isEmpty else {
            gestureSaveErrorMessage = localizationManager.string(.errorGestureDuplicate)
            return
        }

        do {
            try saveGestureConfiguration(gestureConfiguration)
            gestureSaveErrorMessage = nil
        } catch {
            gestureSaveErrorMessage = error.localizedDescription
        }
    }

    private func persistAppConfiguration() {
        do {
            try saveConfiguration(configuration)
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private static func defaultOpenApplicationPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func displayName(forBundleIdentifier bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: url),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
              !name.isEmpty else {
            return bundleIdentifier
        }
        return name
    }
}
