import Foundation

public struct ScopedGestureMatcher {
    public init() {}

    public func match(
        trigger: GestureTrigger,
        signature: GestureSignature,
        targetBundleIdentifier: String?,
        in gestures: [GestureDefinition]
    ) -> GestureDefinition? {
        let candidates = gestures.filter {
            $0.isEnabled &&
                $0.trigger == trigger &&
                $0.signature == signature
        }

        if let targetBundleIdentifier,
           let appSpecific = candidates.first(where: {
               $0.targetBundleIdentifier == targetBundleIdentifier
           }) {
            return appSpecific
        }

        return candidates.first(where: { $0.targetBundleIdentifier == nil })
    }
}
