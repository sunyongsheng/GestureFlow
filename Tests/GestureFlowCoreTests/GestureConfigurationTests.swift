import XCTest
@testable import GestureFlowCore

final class GestureConfigurationTests: XCTestCase {
    func testBuiltInDefaultCloseWindowGesture() {
        let configuration = GestureConfiguration.defaultTemplate

        XCTAssertEqual(configuration.gestures.count, 1)
        XCTAssertEqual(configuration.gestures[0].name, "关闭窗口")
        XCTAssertEqual(configuration.gestures[0].signature.tokens, [.down, .right])
        XCTAssertNil(configuration.gestures[0].targetBundleIdentifier)
        XCTAssertEqual(configuration.gestures[0].id, GestureConfiguration.closeWindowGestureID)
    }
}
