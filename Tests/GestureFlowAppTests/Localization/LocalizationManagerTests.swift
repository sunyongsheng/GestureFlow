import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class LocalizationManagerTests: XCTestCase {
    func testStringReturnsChineseByDefault() {
        let manager = LocalizationManager(language: .zhHans)
        XCTAssertEqual(manager.string(.settingsSectionGeneral), "通用")
    }

    func testSetLanguageUpdatesStrings() {
        let manager = LocalizationManager(language: .zhHans)
        manager.setLanguage(.en)
        XCTAssertEqual(manager.string(.settingsSectionGeneral), "General")
    }

    func testLocalizedConfigurationDirectoryError() {
        let manager = LocalizationManager(language: .en)
        XCTAssertEqual(
            manager.message(for: .invalidConfigurationContent),
            "Configuration files in the target directory are invalid. Check them and try again."
        )
    }
}
