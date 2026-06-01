import XCTest
@testable import GestureFlowCore

final class BuiltInGestureSeedsTests: XCTestCase {
    func testCloseWindowIDIsStable() {
        XCTAssertEqual(
            BuiltInGestureSeeds.closeWindowID.uuidString,
            "A7C4E1B2-3D5F-4A89-9C0E-1F2A3B4C5D6E"
        )
    }

    func testFactoryGesturesContainsCloseWindow() {
        XCTAssertTrue(
            BuiltInGestureSeeds.factoryGestures().contains { $0.id == BuiltInGestureSeeds.closeWindowID }
        )
    }

    func testFactoryGesturesOmitPersistedName() {
        for gesture in BuiltInGestureSeeds.factoryGestures() {
            XCTAssertNil(gesture.name, "Built-in gesture \(gesture.id) should not have a persisted name")
        }
    }

    func testFactoryBuiltinConfigurationYAMLDoesNotIncludeName() throws {
        let data = try YAMLConfigurationCoder.encode(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        let yaml = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(yaml.contains("name:"))
    }

    func testFactoryGesturesContainsAllExpectedIDs() {
        let gestures = BuiltInGestureSeeds.factoryGestures()
        let ids = Set(gestures.map(\.id))
        XCTAssertEqual(ids, BuiltInGestureSeeds.allIDs)
    }

    func testFactoryGesturesCount() {
        XCTAssertEqual(BuiltInGestureSeeds.factoryGestures().count, 19)
    }

    func testChromeGesturesTargetChrome() {
        let chromeIDs: Set<UUID> = [
            BuiltInGestureSeeds.chromeScrollToTopID,
            BuiltInGestureSeeds.chromeScrollToBottomID,
            BuiltInGestureSeeds.chromeReopenClosedTabID,
            BuiltInGestureSeeds.chromeFocusAddressBarID,
        ]
        for gesture in BuiltInGestureSeeds.factoryGestures() where chromeIDs.contains(gesture.id) {
            XCTAssertEqual(gesture.targetBundleIdentifier, "com.google.Chrome")
        }
    }

    func testFinderGesturesTargetFinder() {
        let finderIDs: Set<UUID> = [
            BuiltInGestureSeeds.finderParentFolderID,
            BuiltInGestureSeeds.finderOpenItemID,
            BuiltInGestureSeeds.finderNewFolderID,
        ]
        for gesture in BuiltInGestureSeeds.factoryGestures() where finderIDs.contains(gesture.id) {
            XCTAssertEqual(gesture.targetBundleIdentifier, "com.apple.finder")
        }
    }

    func testGlobalGesturesHaveNilBundleIdentifier() {
        let globalIDs: Set<UUID> = [
            BuiltInGestureSeeds.closeWindowID, BuiltInGestureSeeds.backID,
            BuiltInGestureSeeds.forwardID, BuiltInGestureSeeds.newTabID,
            BuiltInGestureSeeds.refreshID, BuiltInGestureSeeds.minimizeID,
            BuiltInGestureSeeds.undoID, BuiltInGestureSeeds.redoID,
            BuiltInGestureSeeds.copyID, BuiltInGestureSeeds.pasteID,
            BuiltInGestureSeeds.findID, BuiltInGestureSeeds.quitAppID,
        ]
        for gesture in BuiltInGestureSeeds.factoryGestures() where globalIDs.contains(gesture.id) {
            XCTAssertNil(gesture.targetBundleIdentifier)
        }
    }

    func testBuiltinConfigurationIncludesAppBundleIdentifiers() {
        let config = BuiltInGestureSeeds.factoryBuiltinConfiguration()
        XCTAssertTrue(config.applicationBundleIdentifiers.contains("com.google.Chrome"))
        XCTAssertTrue(config.applicationBundleIdentifiers.contains("com.apple.finder"))
    }

    func testAllStableIDsAreUnique() {
        let gestures = BuiltInGestureSeeds.factoryGestures()
        let ids = gestures.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
