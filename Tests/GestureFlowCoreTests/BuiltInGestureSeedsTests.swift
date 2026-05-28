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
        XCTAssertNil(BuiltInGestureSeeds.factoryGestures()[0].name)
    }

    func testFactoryBuiltinConfigurationYAMLDoesNotIncludeName() throws {
        let data = try YAMLConfigurationCoder.encode(BuiltInGestureSeeds.factoryBuiltinConfiguration())
        let yaml = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(yaml.contains("name:"))
    }
}
