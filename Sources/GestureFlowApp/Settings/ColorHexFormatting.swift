import AppKit
import SwiftUI

enum ColorHexFormatting {
    static func nsColor(fromHex hex: String) -> NSColor? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    static func color(fromHex hex: String, fallback: NSColor = .systemBlue) -> Color {
        Color(nsColor: nsColor(fromHex: hex) ?? fallback.usingColorSpace(.sRGB) ?? fallback)
    }

    static func hexString(from color: Color) -> String {
        hexString(from: NSColor(color))
    }

    static func hexString(from nsColor: NSColor) -> String {
        guard let rgb = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }

        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
