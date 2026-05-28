import XCTest
@testable import GestureFlowCore

final class GeneralConfigurationTests: XCTestCase {
    func testGeneralConfigurationDefaultsToZhHans() {
        XCTAssertEqual(GeneralConfiguration().language, .zhHans)
        XCTAssertEqual(AppConfiguration().general.language, .zhHans)
    }

    func testAppConfigurationDecodesWithoutGeneralSection() throws {
        let yaml = """
        isEnabled: true
        """
        let data = Data(yaml.utf8)
        let configuration = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.general.language, .zhHans)
    }

    func testAppConfigurationRoundTripsLanguageEn() throws {
        var configuration = AppConfiguration()
        configuration.general.language = .en

        let data = try YAMLConfigurationCoder.encode(configuration)
        let decoded = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertEqual(decoded.general.language, .en)
    }

    func testUnknownLanguageFallsBackToZhHans() throws {
        let yaml = """
        general:
          language: fr
        """
        let data = Data(yaml.utf8)
        let configuration = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertEqual(configuration.general.language, .zhHans)
    }
}
