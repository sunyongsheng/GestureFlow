import XCTest
@testable import GestureFlowCore

final class SemanticVersionTests: XCTestCase {
    func testParsesPlainVersion() throws {
        let version = try SemanticVersion(parsing: "1.2.3")
        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 2)
        XCTAssertEqual(version.patch, 3)
    }

    func testParsesReleaseTagPrefix() throws {
        let version = try SemanticVersion(parsing: "release/v0.1.1")
        XCTAssertEqual(version.description, "0.1.1")
    }

    func testCompareOrdersVersions() throws {
        let older = try SemanticVersion(parsing: "0.1.1")
        let newer = try SemanticVersion(parsing: "0.2.0")
        XCTAssertTrue(older < newer)
        XCTAssertFalse(newer < older)
    }

    func testInvalidStringThrows() {
        XCTAssertThrowsError(try SemanticVersion(parsing: "not-a-version")) { error in
            XCTAssertEqual(error as? SemanticVersionParseError, .invalidFormat("not-a-version"))
        }
    }
}
