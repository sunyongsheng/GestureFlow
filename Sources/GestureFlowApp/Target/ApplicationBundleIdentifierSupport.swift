import Foundation

enum ApplicationBundleIdentifierSupport {
    static func parentBundleIdentifier(forHelperBundleIdentifier bundleIdentifier: String) -> String? {
        let lowercased = bundleIdentifier.lowercased()
        guard let helperRange = lowercased.range(of: ".helper") else {
            return nil
        }
        let endIndex = bundleIdentifier.index(
            bundleIdentifier.startIndex,
            offsetBy: lowercased.distance(from: lowercased.startIndex, to: helperRange.lowerBound)
        )
        let parent = String(bundleIdentifier[..<endIndex])
        return parent.isEmpty ? nil : parent
    }
}
