import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryResolverTests: XCTestCase {
    func testBootstrapUsesDefaultDirectoryWhenStandaloneMissing() throws {
        let bootstrapDirectory = try makeTemporaryBootstrapDirectory()
        let standaloneURL = bootstrapDirectory.appendingPathComponent("config_standalone.yaml")
        let standaloneStore = StandaloneConfigurationStore(fileURL: standaloneURL)

        let resolver = ConfigurationDirectoryResolver.bootstrap(
            standaloneStore: standaloneStore,
            homeDirectory: bootstrapDirectory
        )

        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            ConfigurationDirectoryResolver.bootstrapBaseDirectoryURL.standardizedFileURL
        )
    }

    func testBootstrapUsesStandaloneDirectoryWhenValid() throws {
        let bootstrapDirectory = try makeTemporaryBootstrapDirectory()
        let customDirectory = bootstrapDirectory.appendingPathComponent("custom-config", isDirectory: true)
        try FileManager.default.createDirectory(at: customDirectory, withIntermediateDirectories: true)

        let standaloneURL = bootstrapDirectory.appendingPathComponent("config_standalone.yaml")
        let standaloneStore = StandaloneConfigurationStore(fileURL: standaloneURL)
        try standaloneStore.save(
            StandaloneConfiguration(configurationDirectory: customDirectory.path)
        )

        let resolver = ConfigurationDirectoryResolver.bootstrap(
            standaloneStore: standaloneStore,
            homeDirectory: bootstrapDirectory
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

    func testBootstrapFallsBackWhenStandaloneDirectoryInvalid() throws {
        let bootstrapDirectory = try makeTemporaryBootstrapDirectory()
        let standaloneURL = bootstrapDirectory.appendingPathComponent("config_standalone.yaml")
        let standaloneStore = StandaloneConfigurationStore(fileURL: standaloneURL)
        try standaloneStore.save(
            StandaloneConfiguration(configurationDirectory: "/definitely/not/a/real/gestureflow/path")
        )

        let resolver = ConfigurationDirectoryResolver.bootstrap(
            standaloneStore: standaloneStore,
            homeDirectory: bootstrapDirectory
        )

        XCTAssertEqual(
            resolver.configurationDirectoryURL.standardizedFileURL,
            ConfigurationDirectoryResolver.bootstrapBaseDirectoryURL.standardizedFileURL
        )
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
