import XCTest
@testable import GestureFlowCore

final class GeneralConfigurationTests: XCTestCase {
    func testGeneralConfigurationDefaultsShowMenuBarIconTrue() {
        XCTAssertTrue(GeneralConfiguration().showMenuBarIcon)
        XCTAssertTrue(AppConfiguration().general.showMenuBarIcon)
    }

    func testAppConfigurationDecodesWithoutGeneralSection() throws {
        let yaml = """
        isEnabled: true
        """
        let data = Data(yaml.utf8)
        let configuration = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertTrue(configuration.general.showMenuBarIcon)
    }

    func testOldConfigWithLanguageFieldDecodesWithoutCrash() throws {
        let yaml = """
        general:
          language: en
          showMenuBarIcon: false
        """
        let data = Data(yaml.utf8)
        let configuration = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertFalse(configuration.general.showMenuBarIcon)
    }

    func testMatchingLocaleIdentifierMapsChineseVariants() {
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-Hans"), .zhHans)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-Hans-CN"), .zhHans)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-Hant"), .zhHant)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-TW"), .zhHant)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-HK"), .zhHant)
    }

    func testMatchingLocaleIdentifierMapsEnglishVariants() {
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "en"), .en)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "en-US"), .en)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "en-GB"), .en)
    }

    func testMatchingLocaleIdentifierMapsAdditionalLanguages() {
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "ja-JP"), .ja)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "ko-KR"), .ko)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "hi-IN"), .hi)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "es-ES"), .es)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "fr-FR"), .fr)
    }

    func testMatchingLocaleIdentifierReturnsNilForUnsupportedLanguages() {
        XCTAssertNil(AppLanguage(matchingLocaleIdentifier: "de"))
        XCTAssertNil(AppLanguage(matchingLocaleIdentifier: "pt"))
    }

    func testResolvingSystemPreferredReturnsSupportedLanguage() {
        let language = AppLanguage.resolvingSystemPreferred()
        XCTAssertTrue(AppLanguage.allCases.contains(language))
    }
}
