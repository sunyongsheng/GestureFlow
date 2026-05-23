import Foundation

public struct ScopedGestureMatcher {
    public init() {}

    public func match(
        trigger: GestureTrigger,
        signature: GestureSignature,
        foregroundBundleIdentifier: String?,
        in gestures: [GestureDefinition]
    ) -> GestureDefinition? {
        let candidates = gestures.filter {
            $0.isEnabled &&
                $0.trigger == trigger &&
                $0.signature == signature
        }

        if let foregroundBundleIdentifier,
           let appSpecific = candidates.first(where: {
               $0.targetBundleIdentifier == foregroundBundleIdentifier
           }) {
            return appSpecific
        }

        return candidates.first(where: { $0.targetBundleIdentifier == nil })
    }
}
