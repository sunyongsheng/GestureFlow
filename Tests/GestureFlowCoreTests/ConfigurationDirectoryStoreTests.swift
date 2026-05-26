import XCTest
@testable import GestureFlowCore

final class ConfigurationDirectoryStoreTests: XCTestCase {
    func testLoadReturnsNilWhenKeyMissing() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConfigurationDirectoryStore(defaults: defaults)

        XCTAssertNil(store.load())
    }

    func testSavesAndLoadsCustomConfigurationDirectory() throws {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConfigurationDirectoryStore(defaults: defaults)
        try store.save(configurationDirectory: "/tmp/custom-gestureflow")

        XCTAssertEqual(store.load(), "/tmp/custom-gestureflow")
    }

    func testSaveDefaultDirectoryRemovesUserDefaultsKey() throws {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConfigurationDirectoryStore(defaults: defaults)
        let defaultPath = ConfigurationDirectoryResolver.defaultConfigurationDirectoryURL.path
        try store.save(configurationDirectory: defaultPath)

        XCTAssertNil(store.load())
    }
}
