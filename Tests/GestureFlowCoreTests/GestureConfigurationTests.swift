import XCTest
@testable import GestureFlowCore

final class GestureConfigurationTests: XCTestCase {
    func testDefaultTemplateIncludesAllBuiltInGestures() {
        let configuration = GestureConfiguration.defaultTemplate

        XCTAssertEqual(configuration.gestures.count, BuiltInGestureSeeds.factoryGestures().count)

        let ids = Set(configuration.gestures.map(\.id))
        XCTAssertEqual(ids, BuiltInGestureSeeds.allIDs)

        for gesture in configuration.gestures {
            XCTAssertEqual(gesture.source, .builtin)
            XCTAssertNil(gesture.name)
        }
    }

    func testDefaultTemplateIncludesCloseWindowGesture() {
        let configuration = GestureConfiguration.defaultTemplate
        let closeWindow = configuration.gestures.first { $0.id == BuiltInGestureSeeds.closeWindowID }

        XCTAssertNotNil(closeWindow)
        XCTAssertEqual(closeWindow?.signature.tokens, [.down, .right])
        XCTAssertNil(closeWindow?.targetBundleIdentifier)
    }
}
