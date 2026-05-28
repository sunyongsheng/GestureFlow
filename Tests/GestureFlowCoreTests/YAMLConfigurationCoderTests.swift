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

    func testEncodesNonASCIIGestureNamesAsLiteralUTF8() throws {
        let configuration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "关闭窗口",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.down, .right]),
                    shortcut: KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
                )
            ]
        )

        let data = try YAMLConfigurationCoder.encode(configuration)
        let yaml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(yaml.contains("关闭窗口"))
        XCTAssertFalse(yaml.contains("\\u"))
    }
}
