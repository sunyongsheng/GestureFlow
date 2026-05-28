import XCTest
@testable import GestureFlowCore

final class GestureConfigurationStoreTests: XCTestCase {
    func testLoadReturnsDefaultTemplateWhenFileMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        )

        let configuration = try store.load()

        XCTAssertEqual(configuration, GestureConfiguration.emptyCustomTemplate)
    }

    func testSaveAndLoadRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent(ConfigurationFileNames.gesturesCustom)
        )
        var configuration = GestureConfiguration.emptyCustomTemplate
        configuration.applicationBundleIdentifiers = ["com.apple.Safari"]

        try store.save(configuration)
        let loaded = try store.load()

        XCTAssertEqual(loaded, configuration)
    }
}
