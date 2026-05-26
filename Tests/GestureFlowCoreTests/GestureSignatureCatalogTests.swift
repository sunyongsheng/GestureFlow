import XCTest
@testable import GestureFlowCore

final class GestureSignatureCatalogTests: XCTestCase {
    func testCatalogCountIs56() {
        XCTAssertEqual(GestureSignatureCatalog.all.count, 56)
    }

    func testDisplayOrderStartsWithCardinalsThenCommonTwoStrokeGestures() {
        let firstIDs = GestureSignatureCatalog.all.prefix(8).map(\.id)
        XCTAssertEqual(
            firstIDs,
            ["U", "R", "D", "L", "D,R", "D,L", "U,R", "U,L"]
        )
    }

    func testFourTokenDiagonalPresetsAreLastRowInDisplayOrder() {
        let lastIDs = GestureSignatureCatalog.all.suffix(4).map(\.id)
        XCTAssertEqual(lastIDs, ["R,U,L,D", "R,D,L,U", "L,U,R,D", "L,D,R,U"])
    }

    func testFourTokenDiagonalPresetsAreIncluded() {
        let expected: [(tokens: [GestureDirection], displayName: String)] = [
            ([.right, .down, .left, .up], "右、下、左、上"),
            ([.left, .down, .right, .up], "左、下、右、上"),
            ([.right, .up, .left, .down], "右、上、左、下"),
            ([.left, .up, .right, .down], "左、上、右、下"),
        ]

        for item in expected {
            let signature = GestureSignature(tokens: item.tokens)
            let option = GestureSignatureCatalog.all.first { $0.signature == signature }
            XCTAssertNotNil(option, "Missing preset \(item.displayName)")
            XCTAssertEqual(option?.displayName, item.displayName)
        }
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

    func testStableIDForDownRight() {
        let signature = GestureSignature(tokens: [.down, .right])
        let option = GestureSignatureCatalog.all.first { $0.signature == signature }
        XCTAssertEqual(option?.id, "D,R")
        XCTAssertEqual(option?.displayName, "下、右")
    }
}
