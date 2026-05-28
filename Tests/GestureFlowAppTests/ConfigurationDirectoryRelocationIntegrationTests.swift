import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class ConfigurationDirectoryRelocationIntegrationTests: XCTestCase {
    func testRelocateConfigurationDirectoryReloadsStores() throws {
        let root = try makeTemporaryRoot()
        let oldDirectory = root.appendingPathComponent("old", isDirectory: true)
        let newDirectory = root.appendingPathComponent("new", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)

        let isolated = makeIsolatedStore()
        try isolated.store.save(configurationDirectory: oldDirectory.path)

        let configuration = AppConfiguration(isEnabled: true)
        let appConfigurationStore = AppConfigurationStore(
            fileURL: oldDirectory.appendingPathComponent("config.yaml")
        )
        try appConfigurationStore.save(configuration)

        let gestureService = GestureConfigurationService(
            builtinStore: GestureConfigurationStore(
                fileURL: oldDirectory.appendingPathComponent(ConfigurationFileNames.gesturesBuiltin)
            ),
            customStore: GestureConfigurationStore(
                fileURL: oldDirectory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
            )
        )
        gestureService.load()

        var resolver = ConfigurationDirectoryResolver(
            configurationDirectoryURL: oldDirectory,
            configurationDirectoryStore: isolated.store
        )

        let application = GestureFlowApplication(
            configurationDirectoryResolver: resolver,
            appConfigurationStore: appConfigurationStore,
            gestureConfigurationService: gestureService,
            configurationDirectoryRelocator: ConfigurationDirectoryRelocator(
                configurationDirectoryStore: isolated.store
            ),
            showSettings: { _, _ in }
        )

        try application.relocateConfigurationDirectory(to: newDirectory.path)

        resolver = ConfigurationDirectoryResolver.bootstrap(
            configurationDirectoryStore: isolated.store
        )
        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            newDirectory.standardizedFileURL
        )
        XCTAssertEqual(try resolver.makeAppConfigurationStore().load(), configuration)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: oldDirectory.appendingPathComponent("config.yaml").path
            )
        )
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
