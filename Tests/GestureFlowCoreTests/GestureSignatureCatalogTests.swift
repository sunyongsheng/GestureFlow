import XCTest
@testable import GestureFlowCore

final class GestureSignatureCatalogTests: XCTestCase {
    func testCatalogCountIs52() {
        XCTAssertEqual(GestureSignatureCatalog.all.count, 52)
    }

    func testNoAdjacentDuplicateTokensInAnyEntry() {
        for option in GestureSignatureCatalog.all {
            let tokens = option.signature.tokens
            for index in tokens.indices.dropFirst() {
                XCTAssertNotEqual(tokens[index], tokens[index - 1])
            }
        }
    }

    func testChineseDisplayNameForDownRight() {
        let signature = GestureSignature(tokens: [.down, .right])
        XCTAssertEqual(signature.chineseDisplayName, "下、右")

        let option = GestureSignatureCatalog.all.first {
            $0.signature == signature
        }
        XCTAssertEqual(option?.displayName, "下、右")
    }
}
