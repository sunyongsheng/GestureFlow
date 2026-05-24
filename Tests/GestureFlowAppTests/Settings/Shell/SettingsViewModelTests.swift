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

    func testShowLaunchAtLoginPlaceholderInvokesInjectedAction() {
        var placeholderCount = 0
        let viewModel = makeViewModel(showLaunchAtLoginPlaceholder: { placeholderCount += 1 })

        viewModel.showLaunchAtLoginPlaceholder()

        XCTAssertEqual(placeholderCount, 1)
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
        saveConfiguration: @escaping (AppConfiguration) throws -> Void = { _ in },
        saveGestureConfiguration: @escaping (GestureConfiguration) throws -> Void = { _ in },
        startGestureFlow: @escaping () -> Void = {},
        stopGestureFlow: @escaping () -> Void = {},
        quitApplication: @escaping () -> Void = {},
        showLaunchAtLoginPlaceholder: @escaping () -> Void = {},
        openApplicationPanel: @escaping () -> URL? = { nil }
    ) -> SettingsViewModel {
        SettingsViewModel(
            loadResult: loadResult,
            gestureConfiguration: gestureConfiguration,
            isRunning: isRunning,
            isAccessibilityTrusted: isAccessibilityTrusted,
            saveConfiguration: saveConfiguration,
            saveGestureConfiguration: saveGestureConfiguration,
            requestAccessibilityPermission: {},
            startGestureFlow: startGestureFlow,
            stopGestureFlow: stopGestureFlow,
            quitApplication: quitApplication,
            showLaunchAtLoginPlaceholder: showLaunchAtLoginPlaceholder,
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
