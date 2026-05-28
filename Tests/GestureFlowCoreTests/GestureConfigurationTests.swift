import XCTest
@testable import GestureFlowCore

final class GestureConfigurationTests: XCTestCase {
    func testDefaultTemplateIncludesBuiltInCloseWindowGesture() {
        let configuration = GestureConfiguration.defaultTemplate

        XCTAssertEqual(configuration.gestures.count, 1)
        XCTAssertNil(configuration.gestures[0].name)
        XCTAssertEqual(configuration.gestures[0].signature.tokens, [.down, .right])
        XCTAssertNil(configuration.gestures[0].targetBundleIdentifier)
        XCTAssertEqual(configuration.gestures[0].id, BuiltInGestureSeeds.closeWindowID)
        XCTAssertEqual(configuration.gestures[0].source, .builtin)
    }
}
