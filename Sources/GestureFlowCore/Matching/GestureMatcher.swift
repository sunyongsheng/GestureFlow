public struct GestureMatcher {
    public init() {}

    public func match(
        trigger: GestureTrigger,
        signature: GestureSignature,
        in gestures: [GestureDefinition]
    ) -> GestureDefinition? {
        gestures.first {
            $0.isEnabled &&
                $0.trigger == trigger &&
                $0.signature == signature
        }
    }
}
