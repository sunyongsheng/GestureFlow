import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class L10nTablesCompletenessTests: XCTestCase {
    func testEveryLanguageProvidesAllKeys() {
        let expectedKeys = Set(L10nKey.allCases)

        for language in AppLanguage.allCases {
            let tableKeys = Set(L10nTables.table(for: language).keys)
            XCTAssertEqual(
                tableKeys,
                expectedKeys,
                "Missing or extra L10n keys for \(language.rawValue)"
            )
        }
    }
}
