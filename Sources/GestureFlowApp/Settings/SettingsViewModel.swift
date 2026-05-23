import AppKit
import Foundation
import GestureFlowCore
import UniformTypeIdentifiers

final class SettingsViewModel: ObservableObject {
    @Published private(set) var configuration: AppConfiguration
    @Published var gestureConfiguration: GestureConfiguration
    @Published private(set) var recoveryNoticeMessage: String?
    @Published private(set) var recoveryBackupPath: String?
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var gestureSaveErrorMessage: String?
    @Published private(set) var isRunning: Bool
    @Published private(set) var isAccessibilityTrusted: Bool
    @Published var selectedApplicationScope: GestureApplicationScope = .global

    private let saveConfiguration: (AppConfiguration) throws -> Void
    private let saveGestureConfiguration: (GestureConfiguration) throws -> Void
    private let permissionPrompt: () -> Void
    private let startGestureFlowAction: () -> Void
    private let stopGestureFlowAction: () -> Void
    private let quitApplicationAction: () -> Void
    private let launchAtLoginPlaceholderAction: () -> Void
    private let openApplicationPanel: () -> URL?

    init(
        loadResult: ConfigurationLoadResult,
        gestureConfiguration: GestureConfiguration,
        isRunning: Bool,
        isAccessibilityTrusted: Bool,
        saveConfiguration: @escaping (AppConfiguration) throws -> Void,
        saveGestureConfiguration: @escaping (GestureConfiguration) throws -> Void,
        requestAccessibilityPermission: @escaping () -> Void,
        startGestureFlow: @escaping () -> Void = {},
        stopGestureFlow: @escaping () -> Void = {},
        quitApplication: @escaping () -> Void = {},
        showLaunchAtLoginPlaceholder: @escaping () -> Void = {},
        openApplicationPanel: @escaping () -> URL? = SettingsViewModel.defaultOpenApplicationPanel
    ) {
        self.configuration = loadResult.configuration
        self.gestureConfiguration = gestureConfiguration
        self.recoveryNoticeMessage = loadResult.didRecoverFromCorruption
            ? loadResult.backupURL.map { "已从损坏的配置中恢复。备份已保存至 \($0.path)" }
                ?? "已从损坏的配置中恢复，但无法备份损坏的文件。"
            : nil
        self.recoveryBackupPath = loadResult.backupURL?.path
        self.isRunning = isRunning
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.saveConfiguration = saveConfiguration
        self.saveGestureConfiguration = saveGestureConfiguration
        self.permissionPrompt = requestAccessibilityPermission
        self.startGestureFlowAction = startGestureFlow
        self.stopGestureFlowAction = stopGestureFlow
        self.quitApplicationAction = quitApplication
        self.launchAtLoginPlaceholderAction = showLaunchAtLoginPlaceholder
        self.openApplicationPanel = openApplicationPanel
    }

    var registeredApplicationBundleIdentifiers: [String] {
        gestureConfiguration.applicationBundleIdentifiers
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
            gestureSaveErrorMessage = "无法读取所选应用的 Bundle ID。"
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

    func addGesture() {
        let gesture = GestureDefinition(
            targetBundleIdentifier: selectedApplicationScope.targetBundleIdentifier,
            name: "新手势",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            shortcut: KeyboardShortcutAction(keyCode: 0, modifiers: [])
        )
        var updatedConfiguration = gestureConfiguration
        updatedConfiguration.gestures.append(gesture)
        gestureConfiguration = updatedConfiguration
        persistGestureConfiguration()
    }

    func deleteGestures(at offsets: IndexSet, in scopeBundleIdentifier: String?) {
        let scopedGestures = gestures(for: scopeBundleIdentifier)
        let idsToDelete = Set(offsets.map { scopedGestures[$0].id })
        deleteGestures(withIDs: idsToDelete)
    }

    func deleteGestures(withIDs ids: Set<UUID>) {
        guard !ids.isEmpty else { return }

        var updatedConfiguration = gestureConfiguration
        updatedConfiguration.gestures.removeAll { ids.contains($0.id) }
        gestureConfiguration = updatedConfiguration
        persistGestureConfiguration()
    }

    func updateGesture(id: UUID, _ update: (inout GestureDefinition) -> Void) {
        guard let index = gestureConfiguration.gestures.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updatedConfiguration = gestureConfiguration
        update(&updatedConfiguration.gestures[index])
        gestureConfiguration = updatedConfiguration
        persistGestureConfiguration()
    }

    func updateFeedback(_ update: (inout FeedbackConfiguration) -> Void) {
        update(&configuration.feedback)
        persistAppConfiguration()
    }

    func updateTriggerConfiguration(_ update: (inout GestureTriggerConfiguration) -> Void) {
        update(&configuration.trigger)
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

    func quitApplication() {
        quitApplicationAction()
    }

    func showLaunchAtLoginPlaceholder() {
        launchAtLoginPlaceholderAction()
    }

    func updateRuntimeStatus(
        configuration: AppConfiguration? = nil,
        gestureConfiguration: GestureConfiguration? = nil,
        isRunning: Bool,
        isAccessibilityTrusted: Bool
    ) {
        if let configuration {
            self.configuration = configuration
        }
        if let gestureConfiguration {
            self.gestureConfiguration = gestureConfiguration
        }
        self.isRunning = isRunning
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    func syncGestureConfiguration(_ configuration: GestureConfiguration) {
        gestureConfiguration = configuration
    }

    private func persistGestureConfiguration() {
        let conflicts = ConflictDetector().detect(in: gestureConfiguration.gestures)
        guard conflicts.isEmpty else {
            gestureSaveErrorMessage = "存在重复的手势：同一应用、轨迹与触发键只能配置一条。"
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
