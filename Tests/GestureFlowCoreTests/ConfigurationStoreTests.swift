import XCTest
@testable import GestureFlowCore

final class ConfigurationStoreTests: XCTestCase {
    func testSavesAndLoadsConfigurationFromInjectedURL() throws {
        let fileURL = try makeTemporaryConfigURL()
        let store = ConfigurationStore(fileURL: fileURL)
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
        try "{ not valid json".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(fileURL: fileURL)

        let result = store.loadRecovering()

        XCTAssertEqual(result.configuration, AppConfiguration())
        XCTAssertTrue(result.didRecoverFromCorruption)
        XCTAssertNotNil(result.backupURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.backupURL!.path))
        XCTAssertTrue(result.backupURL!.lastPathComponent.hasPrefix("config.json.corrupt-"))
    }

    func testLoadBackfillsDefaultTriggerConfigurationForLegacyConfig() throws {
        let fileURL = try makeTemporaryConfigURL()
        let legacyConfiguration = """
        {
          "feedback" : {
            "trailColorHex" : "#0099FF",
            "trailOpacity" : 0.8,
            "trailWidth" : 4
          },
          "isEnabled" : true
        }
        """
        try legacyConfiguration.write(to: fileURL, atomically: true, encoding: .utf8)
        let store = ConfigurationStore(fileURL: fileURL)

        let configuration = try store.load()

        XCTAssertEqual(configuration.isEnabled, true)
        XCTAssertEqual(configuration.trigger, .default)
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
