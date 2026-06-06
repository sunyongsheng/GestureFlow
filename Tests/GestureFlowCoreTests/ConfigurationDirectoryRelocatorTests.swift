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
        try writeValidSplitGestureConfiguration(in: oldDirectory)

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
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: newDirectory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: newDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: oldDirectory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin).path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: oldDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
            )
        )
        XCTAssertEqual(isolated.store.load(), newDirectory.path)
    }

    func testRelocatePersistsRequestedSymlinkPathForDisplay() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        let symlinkDirectory = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: symlinkDirectory, withDestinationURL: realDirectory)

        try writeValidAppConfiguration(to: oldDirectory.appendingPathComponent("config.yaml"))

        let isolated = makeIsolatedStore()
        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: isolated.store
        )

        let resolvedNewDirectory = try relocator.relocate(
            from: oldDirectory,
            to: symlinkDirectory.path,
            mode: .copyCurrentToEmptyTarget
        )

        XCTAssertEqual(resolvedNewDirectory, realDirectory.standardizedFileURL.resolvingSymlinksInPath())
        XCTAssertTrue(FileManager.default.fileExists(atPath: realDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertEqual(isolated.store.load(), symlinkDirectory.path)
    }

    func testRelocatePersistsRequestedTildePathForDisplay() throws {
        let root = try makeTemporaryRoot()
        let homeDirectory = root.appendingPathComponent("home", isDirectory: true)
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let targetDirectory = homeDirectory.appendingPathComponent("config/gestureflow", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        try writeValidAppConfiguration(to: oldDirectory.appendingPathComponent("config.yaml"))

        let isolated = makeIsolatedStore()
        let relocator = ConfigurationDirectoryRelocator(
            configurationDirectoryStore: isolated.store,
            homeDirectory: homeDirectory
        )

        let resolvedNewDirectory = try relocator.relocate(
            from: oldDirectory,
            to: "~/config/gestureflow",
            mode: .copyCurrentToEmptyTarget
        )

        XCTAssertEqual(resolvedNewDirectory, targetDirectory.standardizedFileURL.resolvingSymlinksInPath())
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetDirectory.appendingPathComponent("config.yaml").path))
        XCTAssertEqual(isolated.store.load(), "~/config/gestureflow")
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
        try writeValidSplitGestureConfiguration(in: oldDirectory)

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
            try AppConfigurationStore(
                fileURL: newDirectory.appendingPathComponent("config.yaml")
            ).load(),
            targetConfig
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: newDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: oldDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
            )
        )
    }

    func testAdoptRejectsInvalidTargetConfigBeforeMutatingDisk() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDirectory, withIntermediateDirectories: true)

        try writeValidSplitGestureConfiguration(in: oldDirectory)
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
                atPath: oldDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: newDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom).path
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

    private func writeValidSplitGestureConfiguration(
        in directory: URL,
        custom: GestureConfiguration = .emptyCustomTemplate
    ) throws {
        try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
        ).save(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        try GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        ).save(custom)
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
