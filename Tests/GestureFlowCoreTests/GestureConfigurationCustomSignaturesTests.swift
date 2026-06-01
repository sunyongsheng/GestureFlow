import XCTest
@testable import GestureFlowCore

final class GestureConfigurationCustomSignaturesTests: XCTestCase {
    func testDefaultTemplateHasEmptyCustomGestureSignatures() {
        XCTAssertTrue(GestureConfiguration.defaultTemplate.gestureSignatures.isEmpty)
    }

    func testEncodesAndDecodesCustomGestureSignatures() throws {
        var configuration = GestureConfiguration.defaultTemplate
        configuration.gestureSignatures = [
            GestureSignature(tokens: [.up, .left]),
            GestureSignature(tokens: [.down, .right, .up]),
        ]

        let data = try YAMLConfigurationCoder.encode(configuration)
        let decoded = try YAMLConfigurationCoder.decode(GestureConfiguration.self, from: data)

        XCTAssertEqual(decoded.gestureSignatures, configuration.gestureSignatures)
    }

    func testLoadMissingFieldDefaultsToEmptyCustomGestureSignatures() throws {
        let yaml = """
        applicationBundleIdentifiers: []
        gestures: []
        """

        let decoded = try YAMLConfigurationCoder.decode(
            GestureConfiguration.self,
            from: Data(yaml.utf8)
        )

        XCTAssertTrue(decoded.gestureSignatures.isEmpty)
    }
}
