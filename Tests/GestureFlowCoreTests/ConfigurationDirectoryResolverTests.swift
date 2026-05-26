import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryResolverTests: XCTestCase {
    func testBootstrapUsesDefaultDirectoryWhenUserDefaultsKeyMissing() throws {
        let store = makeIsolatedStore().store

        let resolver = ConfigurationDirectoryResolver.bootstrap(
            configurationDirectoryStore: store
        )

        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            ConfigurationDirectoryResolver.defaultConfigurationDirectoryURL.standardizedFileURL
        )
    }

    func testBootstrapUsesStoredDirectoryWhenValid() throws {
        let isolated = makeIsolatedStore()
        let customDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: customDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: customDirectory)
        }

        try isolated.store.save(configurationDirectory: customDirectory.path)

        let resolver = ConfigurationDirectoryResolver.bootstrap(
            configurationDirectoryStore: isolated.store
        )

        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            customDirectory.standardizedFileURL
        )
    }

    func testXDGConfigurationDirectoryUsesDefaultConfigHomeWhenEnvUnset() throws {
        let homeDirectory = try makeTemporaryBootstrapDirectory()

        let url = ConfigurationDirectoryResolver.xdgConfigurationDirectoryURL(
            environment: [:],
            homeDirectory: homeDirectory
        )

        XCTAssertEqual(
            url.standardizedFileURL,
            homeDirectory.appendingPathComponent(".config/gestureflow", isDirectory: true).standardizedFileURL
        )
        XCTAssertEqual(
            ConfigurationDirectoryResolver.xdgConfigurationDirectoryDisplayPath(
                environment: [:],
                homeDirectory: homeDirectory
            ),
            "~/.config/gestureflow"
        )
    }

    func testXDGConfigurationDirectoryUsesXDGConfigHomeWhenEnvSet() throws {
        let homeDirectory = try makeTemporaryBootstrapDirectory()
        let customConfigHome = homeDirectory.appendingPathComponent("xdg-config", isDirectory: true)

        let url = ConfigurationDirectoryResolver.xdgConfigurationDirectoryURL(
            environment: ["XDG_CONFIG_HOME": customConfigHome.path],
            homeDirectory: homeDirectory
        )

        XCTAssertEqual(
            url.standardizedFileURL,
            customConfigHome.appendingPathComponent("gestureflow", isDirectory: true).standardizedFileURL
        )
    }

    func testBootstrapFallsBackWhenStoredDirectoryInvalid() throws {
        let isolated = makeIsolatedStore()
        try isolated.store.save(configurationDirectory: "/definitely/not/a/real/gestureflow/path")

        let resolver = ConfigurationDirectoryResolver.bootstrap(
            configurationDirectoryStore: isolated.store
        )

        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            ConfigurationDirectoryResolver.defaultConfigurationDirectoryURL.standardizedFileURL
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

    private func makeTemporaryBootstrapDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
