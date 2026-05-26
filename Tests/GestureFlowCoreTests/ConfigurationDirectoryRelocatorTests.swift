import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryRelocatorTests: XCTestCase {
    func testTargetHasConfigurationFilesDetectsConfigYAML() throws {
        let root = try makeTemporaryRoot()
        let directory = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeValidAppConfiguration(to: directory.appendingPathComponent("config.yaml"))

        let relocator = ConfigurationDirectoryRelocator()

        XCTAssertTrue(relocator.targetHasConfigurationFiles(at: directory.path))
    }

    func testTargetHasConfigurationFilesReturnsFalseForEmptyDirectory() throws {
        let root = try makeTemporaryRoot()
        let directory = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let relocator = ConfigurationDirectoryRelocator()

        XCTAssertFalse(relocator.targetHasConfigurationFiles(at: directory.path))
    }

    func testRelocateCopiesFilesWritesUserDefaultsAndDeletesOldBusinessFiles() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)

        try writeValidAppConfiguration(to: oldDirectory.appendingPathComponent("config.yaml"))
        try writeValidGestureConfiguration(to: oldDirectory.appendingPathComponent("gestures.yaml"))

        let isolated = makeIsolatedStore()
        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: isolated.store
        )

        let resolvedNewDirectory = try relocator.relocate(
            from: oldDirectory,
            to: newDirectory.path,
            mode: .copyCurrentToEmptyTarget
        )

        XCTAssertEqual(resolvedNewDirectory.standardizedFileURL, newDirectory.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.appendingPathComponent("gestures.yaml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("gestures.yaml").path))
        XCTAssertEqual(isolated.store.load(), newDirectory.path)
    }

    func testAdoptKeepsTargetConfigAndMergesMissingGesturesFromOldDirectory() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDirectory, withIntermediateDirectories: true)

        let targetConfig = AppConfiguration(isEnabled: false)
        try writeValidAppConfiguration(
            to: newDirectory.appendingPathComponent("config.yaml"),
            configuration: targetConfig
        )
        try writeValidGestureConfiguration(to: oldDirectory.appendingPathComponent("gestures.yaml"))

        let isolated = makeIsolatedStore()
        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: isolated.store
        )

        _ = try relocator.relocate(
            from: oldDirectory,
            to: newDirectory.path,
            mode: .adoptTargetAndMergeMissing
        )

        XCTAssertEqual(
            try ConfigurationStore(
                fileURL: newDirectory.appendingPathComponent("config.yaml")
            ).load(),
            targetConfig
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: newDirectory.appendingPathComponent("gestures.yaml").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("gestures.yaml").path)
        )
    }

    func testAdoptRejectsInvalidTargetConfigBeforeMutatingDisk() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDirectory, withIntermediateDirectories: true)

        try writeValidGestureConfiguration(to: oldDirectory.appendingPathComponent("gestures.yaml"))
        try "not: valid: yaml".write(
            to: newDirectory.appendingPathComponent("config.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let isolated = makeIsolatedStore()
        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: isolated.store
        )

        XCTAssertThrowsError(
            try relocator.relocate(
                from: oldDirectory,
                to: newDirectory.path,
                mode: .adoptTargetAndMergeMissing
            )
        ) { error in
            XCTAssertEqual(
                error as? ConfigurationDirectoryRelocationError,
                .invalidConfigurationContent
            )
        }

        XCTAssertNil(isolated.store.load())
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: oldDirectory.appendingPathComponent("gestures.yaml").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: newDirectory.appendingPathComponent("gestures.yaml").path
            )
        )
    }

    private func writeValidAppConfiguration(
        to url: URL,
        configuration: AppConfiguration = AppConfiguration(isEnabled: true)
    ) throws {
        let data = try YAMLConfigurationCoder.encode(configuration)
        try data.write(to: url, options: .atomic)
    }

    private func writeValidGestureConfiguration(to url: URL) throws {
        let data = try YAMLConfigurationCoder.encode(GestureConfiguration.defaultTemplate)
        try data.write(to: url, options: .atomic)
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
