import AppKit
import SwiftUI

struct ApplicationBundleIconView: View {
    let bundleIdentifier: String
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let icon = Self.icon(for: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    static func icon(for bundleIdentifier: String) -> NSImage? {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }
}
