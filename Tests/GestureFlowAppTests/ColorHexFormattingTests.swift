import AppKit
import XCTest
@testable import GestureFlowApp

final class ColorHexFormattingTests: XCTestCase {
    func testParsesSixDigitHexColor() {
        let color = ColorHexFormatting.nsColor(fromHex: "#4A90E2")

        XCTAssertNotNil(color)
        XCTAssertEqual(ColorHexFormatting.hexString(from: color!), "#4A90E2")
    }

    func testHexStringRoundTripsParsedHexColor() {
        let hex = "#FFAA00"
        let parsed = ColorHexFormatting.nsColor(fromHex: hex)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(ColorHexFormatting.hexString(from: parsed!), hex)
    }
}
