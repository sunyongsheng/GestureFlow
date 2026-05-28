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

    func testJapaneseLocalization() {
        let manager = LocalizationManager(language: .ja)
        XCTAssertEqual(manager.string(.settingsSectionGeneral), "一般")
        XCTAssertEqual(manager.string(.builtInCloseWindowGestureName), "ウィンドウを閉じる")
    }

    func testLocalizedGestureDisplayNameUsesStoredNameWhenPresent() {
        let manager = LocalizationManager(language: .en)
        XCTAssertEqual(
            manager.localizedGestureDisplayName(
                id: BuiltInGestureSeeds.closeWindowID,
                storedName: "Custom Close"
            ),
            "Custom Close"
        )
    }

    func testLocalizedGestureDisplayNameFallsBackWhenStoredNameMissing() {
        let manager = LocalizationManager(language: .en)
        XCTAssertEqual(
            manager.localizedGestureDisplayName(
                id: BuiltInGestureSeeds.closeWindowID,
                storedName: nil
            ),
            "Close Window"
        )
    }

    func testGestureSignatureUsesIdeographicSeparatorForJapanese() {
        let manager = LocalizationManager(language: .ja)
        let signature = GestureSignature(tokens: [.up, .left])
        XCTAssertEqual(manager.localizedDisplayName(for: signature), "上、左")
    }
}
