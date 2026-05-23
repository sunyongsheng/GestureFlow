import Foundation
import GestureFlowCore

final class SettingsViewModel: ObservableObject {
    @Published private(set) var configuration: AppConfiguration
    @Published private(set) var recoveryNoticeMessage: String?
    @Published private(set) var recoveryBackupPath: String?
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var isRunning: Bool
    @Published private(set) var isAccessibilityTrusted: Bool

    private let saveConfiguration: (AppConfiguration) throws -> Void
    private let permissionPrompt: () -> Void
    private let startGestureFlowAction: () -> Void
    private let stopGestureFlowAction: () -> Void
    private let quitApplicationAction: () -> Void
    private let launchAtLoginPlaceholderAction: () -> Void

    init(
        loadResult: ConfigurationLoadResult,
        isRunning: Bool,
        isAccessibilityTrusted: Bool,
        saveConfiguration: @escaping (AppConfiguration) throws -> Void,
        requestAccessibilityPermission: @escaping () -> Void,
        startGestureFlow: @escaping () -> Void = {},
        stopGestureFlow: @escaping () -> Void = {},
        quitApplication: @escaping () -> Void = {},
        showLaunchAtLoginPlaceholder: @escaping () -> Void = {}
    ) {
        self.configuration = loadResult.configuration
        self.recoveryBackupPath = loadResult.backupURL?.path
        if loadResult.didRecoverFromCorruption {
            if let backupPath = loadResult.backupURL?.path {
                self.recoveryNoticeMessage =
                    "已从损坏的配置中恢复。备份已保存至 \(backupPath)"
            } else {
                self.recoveryNoticeMessage =
                    "已从损坏的配置中恢复，但无法备份损坏的文件。"
            }
        } else {
            self.recoveryNoticeMessage = nil
        }
        self.isRunning = isRunning
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.saveConfiguration = saveConfiguration
        self.permissionPrompt = requestAccessibilityPermission
        self.startGestureFlowAction = startGestureFlow
        self.stopGestureFlowAction = stopGestureFlow
        self.quitApplicationAction = quitApplication
        self.launchAtLoginPlaceholderAction = showLaunchAtLoginPlaceholder
    }

    func updateGesture(id: UUID, _ update: (inout GestureDefinition) -> Void) {
        guard let index = configuration.gestures.firstIndex(where: { $0.id == id }) else {
            return
        }

        update(&configuration.gestures[index])
        persist()
    }

    func replaceGesture(_ gesture: GestureDefinition) {
        updateGesture(id: gesture.id) { currentGesture in
            currentGesture = gesture
        }
    }

    func updateFeedback(_ update: (inout FeedbackConfiguration) -> Void) {
        update(&configuration.feedback)
        persist()
    }

    func updateTriggerConfiguration(_ update: (inout GestureTriggerConfiguration) -> Void) {
        update(&configuration.trigger)
        persist()
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
        isRunning: Bool,
        isAccessibilityTrusted: Bool
    ) {
        if let configuration {
            self.configuration = configuration
        }
        self.isRunning = isRunning
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    private func persist() {
        do {
            try saveConfiguration(configuration)
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
