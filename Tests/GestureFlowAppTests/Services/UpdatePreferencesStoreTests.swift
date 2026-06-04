import XCTest
@testable import GestureFlowApp

final class UpdatePreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.update.\(UUID().uuidString)")!
    }

    func testAutomaticUpdateDefaultsToFalse() {
        let store = UpdatePreferencesStore(defaults: defaults)
        XCTAssertFalse(store.isAutomaticUpdateEnabled)
    }

    func testPersistsAutomaticUpdateToggle() {
        let store = UpdatePreferencesStore(defaults: defaults)
        store.isAutomaticUpdateEnabled = true

        let reloaded = UpdatePreferencesStore(defaults: defaults)
        XCTAssertTrue(reloaded.isAutomaticUpdateEnabled)
    }

    func testLastCheckDateRoundTrip() {
        let store = UpdatePreferencesStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        store.lastUpdateCheckDate = date

        let reloaded = UpdatePreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.lastUpdateCheckDate?.timeIntervalSince1970, date.timeIntervalSince1970)
    }

    func testLastCheckDateNilByDefault() {
        let store = UpdatePreferencesStore(defaults: defaults)
        XCTAssertNil(store.lastUpdateCheckDate)
    }
}
