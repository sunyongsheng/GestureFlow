import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryRelocatorTests: XCTestCase {
    func testRelocateCopiesFilesWritesUserDefaultsAndDeletesOldBusinessFiles() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)

        try "{\"isEnabled\":false}".write(
            to: oldDirectory.appendingPathComponent("config.yaml"),
            atomically: true,
            encoding: .utf8
        )
        try "{\"applicationBundleIdentifiers\":[]}".write(
            to: oldDirectory.appendingPathComponent("gestures.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let isolated = makeIsolatedStore()
        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: isolated.store
        )

        let resolvedNewDirectory = try relocator.relocate(
            from: oldDirectory,
            to: newDirectory.path
        )

        XCTAssertEqual(resolvedNewDirectory.standardizedFileURL, newDirectory.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.appendingPathComponent("gestures.yaml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("gestures.yaml").path))
        XCTAssertEqual(isolated.store.load(), newDirectory.path)
    }

    func testRelocateRejectsTargetWithExistingConfigurationFiles() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        try "{}".write(
            to: newDirectory.appendingPathComponent("config.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: makeIsolatedStore().store
        )

        XCTAssertThrowsError(try relocator.relocate(from: oldDirectory, to: newDirectory.path)) { error in
            XCTAssertEqual(
                error as? ConfigurationDirectoryRelocationError,
                .targetContainsConfigurationFiles
            )
        }
    }

    private func makeIsolatedStore() -> (store: ConfigurationDirectoryStore, suiteName: String) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (ConfigurationDirectoryStore(defaults: defaults), suiteName)
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
