import XCTest
@testable import GestureFlowCore

final class StandaloneConfigurationStoreTests: XCTestCase {
    func testLoadReturnsNilWhenFileMissing() throws {
        let fileURL = try makeTemporaryStandaloneURL()
        let store = StandaloneConfigurationStore(fileURL: fileURL)

        XCTAssertNil(try store.load())
    }

    func testSavesAndLoadsStandaloneConfiguration() throws {
        let fileURL = try makeTemporaryStandaloneURL()
        let store = StandaloneConfigurationStore(fileURL: fileURL)
        let configuration = StandaloneConfiguration(
            configurationDirectory: "/tmp/custom-gestureflow"
        )

        try store.save(configuration)
        let loaded = try store.load()

        XCTAssertEqual(loaded, configuration)
    }

    func testLoadRecoveringBacksUpCorruptStandaloneFile() throws {
        let fileURL = try makeTemporaryStandaloneURL()
        try "{ invalid".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = StandaloneConfigurationStore(fileURL: fileURL)

        let result = store.loadRecovering()

        XCTAssertNil(result.configuration)
        XCTAssertTrue(result.didRecoverFromCorruption)
        XCTAssertNotNil(result.backupURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func makeTemporaryStandaloneURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent(ConfigurationFileNames.standalone)
    }
}
