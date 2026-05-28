import XCTest
@testable import GestureFlowCore

final class GeneralConfigurationTests: XCTestCase {
    func testGeneralConfigurationDefaultsToSystemPreferredLanguage() {
        XCTAssertEqual(GeneralConfiguration().language, AppLanguage.resolvingSystemPreferred())
        XCTAssertEqual(AppConfiguration().general.language, AppLanguage.resolvingSystemPreferred())
    }

    func testAppConfigurationDecodesWithoutGeneralSection() throws {
        let yaml = """
        isEnabled: true
        """
        let data = Data(yaml.utf8)
        let configuration = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.general.language, AppLanguage.resolvingSystemPreferred())
    }

    func testAppConfigurationRoundTripsLanguageEn() throws {
        var configuration = AppConfiguration()
        configuration.general.language = .en

        let data = try YAMLConfigurationCoder.encode(configuration)
        let decoded = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertEqual(decoded.general.language, .en)
    }

    func testUnknownLanguageFallsBackToEnglish() throws {
        let yaml = """
        general:
          language: fr
        """
        let data = Data(yaml.utf8)
        let configuration = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertEqual(configuration.general.language, .en)
    }

    func testMatchingLocaleIdentifierMapsChineseVariants() {
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-Hans"), .zhHans)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-Hans-CN"), .zhHans)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "zh-TW"), .zhHans)
    }

    func testMatchingLocaleIdentifierMapsEnglishVariants() {
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "en"), .en)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "en-US"), .en)
        XCTAssertEqual(AppLanguage(matchingLocaleIdentifier: "en-GB"), .en)
    }

    func testMatchingLocaleIdentifierReturnsNilForUnsupportedLanguages() {
        XCTAssertNil(AppLanguage(matchingLocaleIdentifier: "fr"))
        XCTAssertNil(AppLanguage(matchingLocaleIdentifier: "ja"))
    }

    func testResolvingSystemPreferredReturnsSupportedLanguage() {
        let language = AppLanguage.resolvingSystemPreferred()
        XCTAssertTrue(AppLanguage.allCases.contains(language))
    }
}
