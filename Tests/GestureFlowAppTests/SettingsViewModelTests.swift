import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class SettingsViewModelTests: XCTestCase {
    func testRecoveredConfigurationExposesRecoveryNoticeAndBackupPath() {
        let backupURL = URL(fileURLWithPath: "/tmp/config.json.corrupt-123")
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: true,
                backupURL: backupURL
            ),
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            requestAccessibilityPermission: {}
        )

        XCTAssertEqual(
            viewModel.recoveryNoticeMessage,
            "已从损坏的配置中恢复。备份已保存至 /tmp/config.json.corrupt-123"
        )
        XCTAssertEqual(viewModel.recoveryBackupPath, "/tmp/config.json.corrupt-123")
    }

    func testHealthyConfigurationDoesNotExposeRecoveryNotice() {
        let viewModel = SettingsViewModel(
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

        XCTAssertNil(viewModel.recoveryNoticeMessage)
        XCTAssertNil(viewModel.recoveryBackupPath)
    }

    func testUpdatingGesturePersistsConfiguration() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let gesture = GestureDefinition(
            id: UUID(uuidString: "4A3BB501-27B8-4A3B-9EE4-344D823F3515")!,
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .keyboardShortcut(KeyboardShortcutAction(keyCode: 123, modifiers: [.command]))
        )
        try store.save(AppConfiguration(gestures: [gesture]))
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { try store.save($0) },
            requestAccessibilityPermission: {}
        )

        viewModel.updateGesture(id: gesture.id) { updatedGesture in
            updatedGesture.name = "Lock"
            updatedGesture.isEnabled = false
            updatedGesture.trigger = .middleMouse
            updatedGesture.signature = GestureSignature(tokens: [.down, .right])
            updatedGesture.action = .systemCommand(.lockScreen)
        }

        let persistedGesture = try XCTUnwrap(try store.load().gestures.first)
        XCTAssertEqual(persistedGesture.name, "Lock")
        XCTAssertFalse(persistedGesture.isEnabled)
        XCTAssertEqual(persistedGesture.trigger, .middleMouse)
        XCTAssertEqual(persistedGesture.signature, GestureSignature(tokens: [.down, .right]))
        XCTAssertEqual(persistedGesture.action, .systemCommand(.lockScreen))
    }

    func testUpdatingFeedbackPersistsConfiguration() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(AppConfiguration())
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: true,
            isAccessibilityTrusted: false,
            saveConfiguration: { try store.save($0) },
            requestAccessibilityPermission: {}
        )

        viewModel.updateFeedback { feedback in
            feedback.trailColorHex = "#FFAA00"
            feedback.trailWidth = 7
            feedback.trailOpacity = 0.45
        }

        let persistedFeedback = try store.load().feedback
        XCTAssertEqual(persistedFeedback.trailColorHex, "#FFAA00")
        XCTAssertEqual(persistedFeedback.trailWidth, 7)
        XCTAssertEqual(persistedFeedback.trailOpacity, 0.45)
    }

    func testUpdatingTriggerConfigurationPersistsConfiguration() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(AppConfiguration())
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: true,
            isAccessibilityTrusted: true,
            saveConfiguration: { try store.save($0) },
            requestAccessibilityPermission: {}
        )

        viewModel.updateTriggerConfiguration { trigger in
            trigger.movementThreshold = 40
            trigger.holdTimeoutMilliseconds = 500
            trigger.maximumSampleDistance = 160
        }

        let persistedTrigger = try store.load().trigger
        XCTAssertEqual(persistedTrigger.movementThreshold, 40)
        XCTAssertEqual(persistedTrigger.holdTimeoutMilliseconds, 500)
        XCTAssertEqual(persistedTrigger.maximumSampleDistance, 160)
    }

    func testUpdateRuntimeStatusRefreshesPermissionAndRunningState() {
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: false,
            isAccessibilityTrusted: false,
            saveConfiguration: { _ in },
            requestAccessibilityPermission: {}
        )

        let updatedConfiguration = AppConfiguration(isEnabled: true)
        viewModel.updateRuntimeStatus(
            configuration: updatedConfiguration,
            isRunning: true,
            isAccessibilityTrusted: true
        )

        XCTAssertEqual(viewModel.configuration.isEnabled, true)
        XCTAssertEqual(viewModel.isRunning, true)
        XCTAssertEqual(viewModel.isAccessibilityTrusted, true)
    }

    func testSetGestureRecognitionEnabledTrueInvokesStartAction() {
        var startCount = 0
        var stopCount = 0
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            requestAccessibilityPermission: {},
            startGestureFlow: { startCount += 1 },
            stopGestureFlow: { stopCount += 1 }
        )

        viewModel.setGestureRecognitionEnabled(true)

        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(stopCount, 0)
    }

    func testSetGestureRecognitionEnabledFalseInvokesStopAction() {
        var startCount = 0
        var stopCount = 0
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: true,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            requestAccessibilityPermission: {},
            startGestureFlow: { startCount += 1 },
            stopGestureFlow: { stopCount += 1 }
        )

        viewModel.setGestureRecognitionEnabled(false)

        XCTAssertEqual(startCount, 0)
        XCTAssertEqual(stopCount, 1)
    }

    func testQuitApplicationInvokesInjectedAction() {
        var quitCount = 0
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            requestAccessibilityPermission: {},
            quitApplication: { quitCount += 1 }
        )

        viewModel.quitApplication()

        XCTAssertEqual(quitCount, 1)
    }

    func testShowLaunchAtLoginPlaceholderInvokesInjectedAction() {
        var placeholderCount = 0
        let viewModel = SettingsViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            isRunning: false,
            isAccessibilityTrusted: true,
            saveConfiguration: { _ in },
            requestAccessibilityPermission: {},
            showLaunchAtLoginPlaceholder: { placeholderCount += 1 }
        )

        viewModel.showLaunchAtLoginPlaceholder()

        XCTAssertEqual(placeholderCount, 1)
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
