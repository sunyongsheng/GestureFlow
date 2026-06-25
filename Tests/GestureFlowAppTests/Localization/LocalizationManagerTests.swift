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
            "Configuration files in the target directory are invalid. Check them and try again"
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

    func testLocalizedGestureDisplayNameResolvesAllBuiltInIDs() {
        let manager = LocalizationManager(language: .en)
        for gesture in BuiltInGestureSeeds.factoryGestures() {
            let name = manager.localizedGestureDisplayName(id: gesture.id, storedName: nil)
            XCTAssertFalse(name.isEmpty, "Built-in gesture \(gesture.id) should have a localized name")
        }
    }

    func testLocalizedGestureDisplayNameForChromeGesture() {
        let manager = LocalizationManager(language: .zhHans)
        XCTAssertEqual(
            manager.localizedGestureDisplayName(
                id: BuiltInGestureSeeds.chromeScrollToTopID,
                storedName: nil
            ),
            "滚到页面顶部"
        )
    }

    func testLocalizedGestureDisplayNameForFinderGesture() {
        let manager = LocalizationManager(language: .en)
        XCTAssertEqual(
            manager.localizedGestureDisplayName(
                id: BuiltInGestureSeeds.finderNewFolderID,
                storedName: nil
            ),
            "New Folder"
        )
    }

    func testGestureSignatureUsesIdeographicSeparatorForJapanese() {
        let manager = LocalizationManager(language: .ja)
        let signature = GestureSignature(tokens: [.up, .left])
        XCTAssertEqual(manager.localizedDisplayName(for: signature), "上、左")
    }
}
