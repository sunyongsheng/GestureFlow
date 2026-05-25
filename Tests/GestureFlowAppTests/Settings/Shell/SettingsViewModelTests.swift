import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class SettingsViewModelTests: XCTestCase {
    func testRecoveredConfigurationExposesRecoveryNoticeAndBackupPath() {
        let backupURL = URL(fileURLWithPath: "/tmp/config.json.corrupt-123")
        let viewModel = makeViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: AppConfiguration(),
                didRecoverFromCorruption: true,
                backupURL: backupURL
            )
        )

        XCTAssertEqual(
            viewModel.recoveryNoticeMessage,
            "已从损坏的配置中恢复。备份已保存至 /tmp/config.json.corrupt-123"
        )
        XCTAssertEqual(viewModel.recoveryBackupPath, "/tmp/config.json.corrupt-123")
    }

    func testHealthyConfigurationDoesNotExposeRecoveryNotice() {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.recoveryNoticeMessage)
        XCTAssertNil(viewModel.recoveryBackupPath)
    }

    func testRestoreDefaultGestureConfigurationResetsAndPersists() throws {
        let directory = try makeTemporaryDirectory()
        let gestureStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.json")
        )
        var configuration = GestureConfiguration.defaultTemplate
        configuration.applicationBundleIdentifiers = ["com.apple.Safari"]
        configuration.gestures.append(
            GestureDefinition(
                targetBundleIdentifier: "com.apple.Safari",
                name: "Safari Back",
                trigger: .rightMouse,
                signature: GestureSignature(tokens: [.left]),
                shortcut: KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
            )
        )
        try gestureStore.save(configuration)

        let viewModel = makeViewModel(
            gestureConfiguration: try gestureStore.load(),
            saveGestureConfiguration: { try gestureStore.save($0) }
        )
        viewModel.selectedApplicationScope = .application(bundleIdentifier: "com.apple.Safari")
        _ = viewModel.addGesture()

        viewModel.restoreDefaultGestureConfiguration()

        XCTAssertEqual(viewModel.gestureConfiguration, GestureConfiguration.defaultTemplate)
        XCTAssertEqual(viewModel.selectedApplicationScope, .global)
        XCTAssertTrue(viewModel.registeredApplicationBundleIdentifiers.isEmpty)
        XCTAssertNil(viewModel.gestureSaveErrorMessage)
        XCTAssertEqual(try gestureStore.load(), GestureConfiguration.defaultTemplate)
    }

    func testCommitGestureShowsErrorWhenShortcutIsMissing() throws {
        let viewModel = makeViewModel()
        let gestureID = viewModel.addGesture()

        viewModel.commitGesture(id: gestureID)

        XCTAssertEqual(viewModel.gestureSaveErrorMessage, "请录制快捷键。")
        XCTAssertTrue(viewModel.isGesturePendingSave(id: gestureID))
    }

    func testCommitGestureKeepsPendingStateWhenValidationFails() throws {
        let directory = try makeTemporaryDirectory()
        let gestureStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.json")
        )
        let duplicate = GestureDefinition(
            name: "Duplicate",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.down, .right]),
            shortcut: KeyboardShortcutAction(keyCode: 1, modifiers: [])
        )
        try gestureStore.save(GestureConfiguration(gestures: [duplicate]))

        let viewModel = makeViewModel(
            gestureConfiguration: try gestureStore.load(),
            saveGestureConfiguration: { try gestureStore.save($0) }
        )
        let newGestureID = viewModel.addGesture()
        viewModel.stageGestureUpdate(id: newGestureID) { gesture in
            gesture.signature = duplicate.signature
            gesture.trigger = duplicate.trigger
        }

        viewModel.commitGesture(id: newGestureID)

        XCTAssertNotNil(viewModel.gestureSaveErrorMessage)
        XCTAssertTrue(viewModel.isGesturePendingSave(id: newGestureID))
        XCTAssertEqual(try gestureStore.load().gestures.count, 1)
    }

    func testAddGestureDoesNotPersistUntilCommitted() throws {
        let directory = try makeTemporaryDirectory()
        let gestureStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.json")
        )
        let initialCount = try gestureStore.load().gestures.count
        let viewModel = makeViewModel(
            gestureConfiguration: try gestureStore.load(),
            saveGestureConfiguration: { try gestureStore.save($0) }
        )

        let newGestureID = viewModel.addGesture()
        viewModel.stageGestureUpdate(id: newGestureID) { gesture in
            gesture.signature = GestureSignature(tokens: [.left])
            gesture.shortcut = KeyboardShortcutAction(keyCode: 0, modifiers: [.command])
        }

        XCTAssertEqual(try gestureStore.load().gestures.count, initialCount)
        XCTAssertTrue(viewModel.isGesturePendingSave(id: newGestureID))

        viewModel.commitGesture(id: newGestureID)

        XCTAssertNil(viewModel.gestureSaveErrorMessage)
        XCTAssertEqual(try gestureStore.load().gestures.count, initialCount + 1)
        XCTAssertFalse(viewModel.isGesturePendingSave(id: newGestureID))
    }

    func testUpdatingGesturePersistsGestureConfiguration() throws {
        let directory = try makeTemporaryDirectory()
        let gestureStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.json")
        )
        let gesture = GestureDefinition(
            id: UUID(uuidString: "4A3BB501-27B8-4A3B-9EE4-344D823F3515")!,
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            shortcut: KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        )
        try gestureStore.save(GestureConfiguration(gestures: [gesture]))
        let viewModel = makeViewModel(
            gestureConfiguration: try gestureStore.load(),
            saveGestureConfiguration: { try gestureStore.save($0) }
        )

        viewModel.stageGestureUpdate(id: gesture.id) { updatedGesture in
            updatedGesture.name = "Lock"
            updatedGesture.isEnabled = false
            updatedGesture.trigger = .middleMouse
            updatedGesture.signature = GestureSignature(tokens: [.down, .right])
            updatedGesture.shortcut = KeyboardShortcutAction(keyCode: 13, modifiers: [.shift, .command])
        }
        XCTAssertTrue(viewModel.isGesturePendingSave(id: gesture.id))

        viewModel.commitGesture(id: gesture.id)

        let persistedGesture = try XCTUnwrap(try gestureStore.load().gestures.first)
        XCTAssertEqual(persistedGesture.name, "Lock")
        XCTAssertFalse(persistedGesture.isEnabled)
        XCTAssertEqual(persistedGesture.trigger, .middleMouse)
        XCTAssertEqual(persistedGesture.signature, GestureSignature(tokens: [.down, .right]))
        XCTAssertEqual(
            persistedGesture.shortcut,
            KeyboardShortcutAction(keyCode: 13, modifiers: [.shift, .command])
        )
    }

    func testCancellingAddApplicationPanelDoesNothing() {
        let viewModel = makeViewModel(openApplicationPanel: { nil })

        viewModel.addApplicationFromPanel()

        XCTAssertTrue(viewModel.registeredApplicationBundleIdentifiers.isEmpty)
        XCTAssertNil(viewModel.gestureSaveErrorMessage)
    }

    func testRemoveApplicationDeletesScopedGestures() throws {
        let directory = try makeTemporaryDirectory()
        let gestureStore = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.json")
        )
        var configuration = GestureConfiguration.defaultTemplate
        configuration.applicationBundleIdentifiers = ["com.apple.Safari"]
        configuration.gestures.append(
            GestureDefinition(
                targetBundleIdentifier: "com.apple.Safari",
                name: "Safari Close",
                trigger: .rightMouse,
                signature: GestureSignature(tokens: [.left]),
                shortcut: KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
            )
        )
        try gestureStore.save(configuration)

        let viewModel = makeViewModel(
            gestureConfiguration: try gestureStore.load(),
            saveGestureConfiguration: { try gestureStore.save($0) }
        )
        viewModel.removeApplication(bundleIdentifier: "com.apple.Safari")

        let loaded = try gestureStore.load()
        XCTAssertTrue(loaded.applicationBundleIdentifiers.isEmpty)
        XCTAssertEqual(loaded.gestures.count, 1)
        XCTAssertNil(loaded.gestures[0].targetBundleIdentifier)
        XCTAssertEqual(viewModel.selectedApplicationScope, .global)
    }

    func testUpdatingFeedbackPersistsConfiguration() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(AppConfiguration())
        let viewModel = makeViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            saveConfiguration: { try store.save($0) }
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
        let viewModel = makeViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            saveConfiguration: { try store.save($0) }
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

    func testRestoreDefaultAdvancedSettingsResetsAndPersists() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        var configuration = AppConfiguration()
        configuration.feedback.trailColorHex = "#FFAA00"
        configuration.feedback.trailWidth = 7
        configuration.feedback.trailOpacity = 0.45
        configuration.trigger.movementThreshold = 40
        configuration.trigger.holdTimeoutMilliseconds = 500
        configuration.trigger.maximumSampleDistance = 160
        configuration.gestureTargetApplication = .foreground
        try store.save(configuration)

        let viewModel = makeViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            saveConfiguration: { try store.save($0) }
        )

        viewModel.restoreDefaultAdvancedSettings()

        XCTAssertEqual(viewModel.configuration.feedback, .default)
        XCTAssertEqual(viewModel.configuration.trigger, .default)
        XCTAssertEqual(viewModel.configuration.gestureTargetApplication, .defaultValue)

        let persisted = try store.load()
        XCTAssertEqual(persisted.feedback, .default)
        XCTAssertEqual(persisted.trigger, .default)
        XCTAssertEqual(persisted.gestureTargetApplication, .defaultValue)
        XCTAssertNil(viewModel.saveErrorMessage)
    }

    func testRestoreDefaultAdvancedSettingsPreservesIsEnabled() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(AppConfiguration(isEnabled: true))

        let viewModel = makeViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            saveConfiguration: { try store.save($0) }
        )
        viewModel.updateFeedback { $0.trailWidth = 9 }

        viewModel.restoreDefaultAdvancedSettings()

        XCTAssertTrue(viewModel.configuration.isEnabled)
        XCTAssertTrue(try store.load().isEnabled)
    }

    func testUpdatingGestureTargetApplicationPersistsConfiguration() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
        try store.save(AppConfiguration())
        let viewModel = makeViewModel(
            loadResult: ConfigurationLoadResult(
                configuration: try store.load(),
                didRecoverFromCorruption: false,
                backupURL: nil
            ),
            saveConfiguration: { try store.save($0) }
        )

        viewModel.updateGestureTargetApplication(.foreground)

        XCTAssertEqual(try store.load().gestureTargetApplication, .foreground)
    }

    func testUpdateRuntimeStatusRefreshesPermissionAndRunningState() {
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel(
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
        let viewModel = makeViewModel(
            isRunning: true,
            startGestureFlow: { startCount += 1 },
            stopGestureFlow: { stopCount += 1 }
        )

        viewModel.setGestureRecognitionEnabled(false)

        XCTAssertEqual(startCount, 0)
        XCTAssertEqual(stopCount, 1)
    }

    func testQuitApplicationInvokesInjectedAction() {
        var quitCount = 0
        let viewModel = makeViewModel(quitApplication: { quitCount += 1 })

        viewModel.quitApplication()

        XCTAssertEqual(quitCount, 1)
    }

    func testSetLaunchAtLoginEnabledInvokesInjectedAction() throws {
        var requestedValue: Bool?
        var status = false
        let viewModel = makeViewModel(
            isLaunchAtLoginEnabled: false,
            setLaunchAtLoginEnabled: { requestedValue = $0; status = $0 },
            launchAtLoginStatus: { status }
        )

        viewModel.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(requestedValue, true)
        XCTAssertTrue(viewModel.isLaunchAtLoginEnabled)
        XCTAssertNil(viewModel.launchAtLoginErrorMessage)
    }

    func testSetLaunchAtLoginEnabledShowsErrorAndRefreshesStatusOnFailure() {
        var status = false
        let viewModel = makeViewModel(
            isLaunchAtLoginEnabled: false,
            setLaunchAtLoginEnabled: { _ in throw NSError(domain: "test", code: 1) },
            launchAtLoginStatus: { status }
        )

        viewModel.setLaunchAtLoginEnabled(true)

        XCTAssertNotNil(viewModel.launchAtLoginErrorMessage)
        XCTAssertFalse(viewModel.isLaunchAtLoginEnabled)
    }

    func testUpdateRuntimeStatusRefreshesLaunchAtLoginState() {
        let viewModel = makeViewModel(isLaunchAtLoginEnabled: false)

        viewModel.updateRuntimeStatus(isRunning: false, isAccessibilityTrusted: true, isLaunchAtLoginEnabled: true)

        XCTAssertTrue(viewModel.isLaunchAtLoginEnabled)
    }

    private func makeViewModel(
        loadResult: ConfigurationLoadResult = ConfigurationLoadResult(
            configuration: AppConfiguration(),
            didRecoverFromCorruption: false,
            backupURL: nil
        ),
        gestureConfiguration: GestureConfiguration = .defaultTemplate,
        isRunning: Bool = false,
        isAccessibilityTrusted: Bool = true,
        isLaunchAtLoginEnabled: Bool = false,
        saveConfiguration: @escaping (AppConfiguration) throws -> Void = { _ in },
        saveGestureConfiguration: @escaping (GestureConfiguration) throws -> Void = { _ in },
        startGestureFlow: @escaping () -> Void = {},
        stopGestureFlow: @escaping () -> Void = {},
        quitApplication: @escaping () -> Void = {},
        setLaunchAtLoginEnabled: @escaping (Bool) throws -> Void = { _ in },
        launchAtLoginStatus: @escaping () -> Bool = { false },
        openApplicationPanel: @escaping () -> URL? = { nil }
    ) -> SettingsViewModel {
        SettingsViewModel(
            loadResult: loadResult,
            gestureConfiguration: gestureConfiguration,
            isRunning: isRunning,
            isAccessibilityTrusted: isAccessibilityTrusted,
            isLaunchAtLoginEnabled: isLaunchAtLoginEnabled,
            saveConfiguration: saveConfiguration,
            saveGestureConfiguration: saveGestureConfiguration,
            requestAccessibilityPermission: {},
            startGestureFlow: startGestureFlow,
            stopGestureFlow: stopGestureFlow,
            quitApplication: quitApplication,
            setLaunchAtLoginEnabled: setLaunchAtLoginEnabled,
            launchAtLoginStatus: launchAtLoginStatus,
            openApplicationPanel: openApplicationPanel
        )
    }

    private func makeTemporaryConfigURL() throws -> URL {
        let directory = try makeTemporaryDirectory()
        return directory.appendingPathComponent("config.json")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
