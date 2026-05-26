import XCTest
@testable import GestureFlowCore

final class GestureSignatureLookupTests: XCTestCase {
    func testIDJoinsTokenRawValues() {
        let signature = GestureSignature(tokens: [.down, .right])
        XCTAssertEqual(GestureSignatureLookup.id(for: signature), "D,R")
    }

    func testExistsFindsBuiltInCatalogSignature() {
        let signature = GestureSignature(tokens: [.down, .right])
        XCTAssertTrue(GestureSignatureLookup.exists(signature, customSignatures: []))
    }

    func testExistsFindsCustomSignature() {
        let signature = GestureSignature(tokens: [.up, .left, .right])
        XCTAssertTrue(
            GestureSignatureLookup.exists(
                signature,
                customSignatures: [signature]
            )
        )
    }

    func testExistsReturnsFalseForUnknownSignature() {
        let signature = GestureSignature(tokens: [.left, .up, .right, .down, .left])
        XCTAssertFalse(GestureSignatureLookup.exists(signature, customSignatures: []))
    }
}
