import XCTest
@testable import GestureFlowCore

final class AppConfigurationStoreTests: XCTestCase {
    func testSavesAndLoadsConfigurationFromInjectedURL() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = AppConfigurationStore(fileURL: fileURL)
        let configuration = AppConfiguration(
            isEnabled: true,
            feedback: FeedbackConfiguration(
                trailColorHex: "#FF0000",
                trailWidth: 8,
                trailOpacity: 0.5
            ),
            trigger: GestureTriggerConfiguration(
                movementThreshold: 36,
                holdTimeoutMilliseconds: 450,
                maximumSampleDistance: 140
            )
        )

        try store.save(configuration)
        let loaded = try store.load()

        XCTAssertEqual(loaded, configuration)
    }

    func testLoadRecoveringBacksUpCorruptConfigurationAndReturnsDefaults() throws {
        let fileURL = try makeTemporaryConfigURL()
        try "not: valid: yaml: [[[".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = AppConfigurationStore(fileURL: fileURL)

        let result = store.loadRecovering()

        XCTAssertEqual(result.configuration, AppConfiguration())
        XCTAssertTrue(result.didRecoverFromCorruption)
        XCTAssertNotNil(result.backupURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.backupURL!.path))
        XCTAssertTrue(
            result.backupURL!.lastPathComponent.hasPrefix("\(ConfigurationFileNames.config).corrupt-")
        )
    }

    func testLoadBackfillsDefaultTriggerConfigurationWhenTriggerSectionMissing() throws {
        let fileURL = try makeTemporaryConfigURL()
        let partialConfiguration = """
        isEnabled: true
        feedback:
          trailColorHex: "#0099FF"
          trailOpacity: 0.8
          trailWidth: 4
        """
        try partialConfiguration.write(to: fileURL, atomically: true, encoding: .utf8)
        let store = AppConfigurationStore(fileURL: fileURL)

        let configuration = try store.load()

        XCTAssertEqual(configuration.isEnabled, true)
        XCTAssertEqual(configuration.trigger, .default)
        XCTAssertEqual(configuration.gestureTargetApplication, .underMouse)
    }

    func testMissingGestureTargetApplicationBackfillsUnderMouse() throws {
        let fileURL = try makeTemporaryConfigURL()
        let partialConfiguration = """
        isEnabled: true
        trigger:
          movementThreshold: 24
          holdTimeoutMilliseconds: 250
          maximumSampleDistance: 120
        """
        try partialConfiguration.write(to: fileURL, atomically: true, encoding: .utf8)
        let store = AppConfigurationStore(fileURL: fileURL)

        let configuration = try store.load()

        XCTAssertEqual(configuration.gestureTargetApplication, .underMouse)
    }

    func testMissingIgnoredApplicationsBackfillsEmptyArray() throws {
        let fileURL = try makeTemporaryConfigURL()
        let partialConfiguration = """
        isEnabled: true
        """
        try partialConfiguration.write(to: fileURL, atomically: true, encoding: .utf8)
        let store = AppConfigurationStore(fileURL: fileURL)

        let configuration = try store.load()

        XCTAssertEqual(configuration.ignoredApplicationBundleIdentifiers, [])
    }

    private func makeTemporaryConfigURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent(ConfigurationFileNames.config)
    }
}
