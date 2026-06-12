import XCTest
@testable import GestureFlowApp

final class ApplicationBundleIdentifierSupportTests: XCTestCase {
    func testParentBundleIdentifierStripsHelperSuffix() {
        XCTAssertEqual(
            ApplicationBundleIdentifierSupport.parentBundleIdentifier(
                forHelperBundleIdentifier: "com.cursor.app.helper"
            ),
            "com.cursor.app"
        )
    }

    func testParentBundleIdentifierStripsNestedHelperSuffix() {
        XCTAssertEqual(
            ApplicationBundleIdentifierSupport.parentBundleIdentifier(
                forHelperBundleIdentifier: "com.google.Chrome.helper.renderer"
            ),
            "com.google.Chrome"
        )
    }

    func testParentBundleIdentifierReturnsNilForNonHelperBundle() {
        XCTAssertNil(
            ApplicationBundleIdentifierSupport.parentBundleIdentifier(
                forHelperBundleIdentifier: "com.google.Chrome"
            )
        )
    }
}
