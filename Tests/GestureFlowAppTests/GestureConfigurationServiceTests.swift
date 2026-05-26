import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureConfigurationServiceTests: XCTestCase {
    func testLoadCreatesFileWhenMissing() throws {
        let directory = try makeTemporaryDirectory()
        let store = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.yaml")
        )
        let service = GestureConfigurationService(store: store)

        service.load()

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(service.configuration, GestureConfiguration.defaultTemplate)
    }

    func testSaveWritesToDisk() throws {
        let directory = try makeTemporaryDirectory()
        let store = GestureConfigurationStore(
            fileURL: directory.appendingPathComponent("gestures.yaml")
        )
        let service = GestureConfigurationService(store: store)
        service.load()
        service.configuration.applicationBundleIdentifiers = ["com.apple.Safari"]

        try service.save()

        let loaded = try store.load()
        XCTAssertEqual(loaded.applicationBundleIdentifiers, ["com.apple.Safari"])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
