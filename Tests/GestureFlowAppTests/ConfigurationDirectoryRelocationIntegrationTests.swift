import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class ConfigurationDirectoryRelocationIntegrationTests: XCTestCase {
    func testRelocateConfigurationDirectoryReloadsStores() throws {
        let root = try makeTemporaryRoot()
        let bootstrapDirectory = root.appendingPathComponent("bootstrap", isDirectory: true)
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: bootstrapDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)

        let standaloneURL = bootstrapDirectory.appendingPathComponent("config_standalone.json")
        try StandaloneConfigurationStore(fileURL: standaloneURL).save(
            StandaloneConfiguration(configurationDirectory: oldDirectory.path)
        )

        let configuration = AppConfiguration(isEnabled: true)
        let configurationStore = ConfigurationStore(
            fileURL: oldDirectory.appendingPathComponent("config.json")
        )
        try configurationStore.save(configuration)

        let gestureService = GestureConfigurationService(
            store: GestureConfigurationStore(
                fileURL: oldDirectory.appendingPathComponent("gestures.json")
            )
        )
        gestureService.load()

        var resolver = ConfigurationDirectoryResolver(
            configurationDirectoryURL: oldDirectory,
            standaloneStore: StandaloneConfigurationStore(fileURL: standaloneURL)
        )

        let application = GestureFlowApplication(
            configurationDirectoryResolver: resolver,
            configurationStore: configurationStore,
            gestureConfigurationService: gestureService,
            configurationDirectoryRelocator: ConfigurationDirectoryRelocator(
                standaloneStore: StandaloneConfigurationStore(fileURL: standaloneURL)
            ),
            showSettings: { _, _ in }
        )

        try application.relocateConfigurationDirectory(to: newDirectory.path)

        resolver = ConfigurationDirectoryResolver.bootstrap(
            standaloneStore: StandaloneConfigurationStore(fileURL: standaloneURL)
        )
        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            newDirectory.standardizedFileURL
        )
        XCTAssertEqual(try resolver.makeConfigurationStore().load(), configuration)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: oldDirectory.appendingPathComponent("config.json").path
            )
        )
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
