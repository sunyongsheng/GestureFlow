import XCTest
@testable import GestureFlowCore

final class YAMLConfigurationCoderTests: XCTestCase {
    func testEncodesAndDecodesAppConfiguration() throws {
        let configuration = AppConfiguration(
            isEnabled: true,
            feedback: FeedbackConfiguration(
                trailColorHex: "#AABBCC",
                trailWidth: 5,
                trailOpacity: 0.5
            )
        )

        let data = try YAMLConfigurationCoder.encode(configuration)
        let decoded = try YAMLConfigurationCoder.decode(AppConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
    }
}
