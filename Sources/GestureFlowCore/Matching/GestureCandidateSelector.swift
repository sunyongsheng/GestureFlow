import Foundation

enum GestureCandidateSelector {
    /// Picks app-specific gesture when targeting an app; otherwise the global (nil bundle) gesture.
    static func preferred(
        among candidates: [GestureDefinition],
        targetBundleIdentifier: String?
    ) -> GestureDefinition? {
        guard !candidates.isEmpty else { return nil }
        if let targetBundleIdentifier,
           let appSpecific = candidates.first(where: {
               $0.targetBundleIdentifier == targetBundleIdentifier
           }) {
            return appSpecific
        }
        return candidates.first(where: { $0.targetBundleIdentifier == nil })
    }
}
