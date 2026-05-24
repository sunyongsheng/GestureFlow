import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryRelocatorTests: XCTestCase {
    func testRelocateCopiesFilesWritesStandaloneAndDeletesOldBusinessFiles() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)

        try "{\"isEnabled\":false}".write(
            to: oldDirectory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"applicationBundleIdentifiers\":[]}".write(
            to: oldDirectory.appendingPathComponent("gestures.json"),
            atomically: true,
            encoding: .utf8
        )

        let standaloneURL = root.appendingPathComponent("config_standalone.json")
        let relocator = ConfigurationDirectoryRelocator(
            standaloneStore: StandaloneConfigurationStore(fileURL: standaloneURL)
        )

        let resolvedNewDirectory = try relocator.relocate(
            from: oldDirectory,
            to: newDirectory.path
        )

        XCTAssertEqual(resolvedNewDirectory.standardizedFileURL, newDirectory.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.appendingPathComponent("config.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.appendingPathComponent("gestures.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("config.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("gestures.json").path))

        let standalone = try StandaloneConfigurationStore(fileURL: standaloneURL).load()
        XCTAssertEqual(standalone?.configurationDirectory, newDirectory.path)
    }

    func testRelocateRejectsTargetWithExistingConfigurationFiles() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        try "{}".write(
            to: newDirectory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )

        let relocator = ConfigurationDirectoryRelocator(
            standaloneStore: StandaloneConfigurationStore(
                fileURL: root.appendingPathComponent("config_standalone.json")
            )
        )

        XCTAssertThrowsError(try relocator.relocate(from: oldDirectory, to: newDirectory.path)) { error in
            XCTAssertEqual(
                error as? ConfigurationDirectoryRelocationError,
                .targetContainsConfigurationFiles
            )
        }
    }

    private func makeTemporaryRoot() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
