import Foundation

public struct GestureLiveMatchResult: Equatable {
    public var partialSignature: GestureSignature?
    public var exactMatch: GestureDefinition?
    public var hasPrefixMatch: Bool

    public init(
        partialSignature: GestureSignature?,
        exactMatch: GestureDefinition?,
        hasPrefixMatch: Bool
    ) {
        self.partialSignature = partialSignature
        self.exactMatch = exactMatch
        self.hasPrefixMatch = hasPrefixMatch
    }
}

public struct GestureLiveMatcher {
    public init() {}

    public func evaluate(
        trigger: GestureTrigger,
        partialSignature: GestureSignature?,
        targetBundleIdentifier: String?,
        in gestures: [GestureDefinition]
    ) -> GestureLiveMatchResult {
        guard let partialSignature, !partialSignature.tokens.isEmpty else {
            return GestureLiveMatchResult(
                partialSignature: partialSignature,
                exactMatch: nil,
                hasPrefixMatch: false
            )
        }

        let candidates = gestures.filter { $0.isEnabled && $0.trigger == trigger }
        let exactMatch = exactMatch(
            for: partialSignature,
            targetBundleIdentifier: targetBundleIdentifier,
            in: candidates
        )
        let hasPrefixMatch = candidates.contains { gesture in
            gesture.signature.tokens.starts(with: partialSignature.tokens)
        }

        return GestureLiveMatchResult(
            partialSignature: partialSignature,
            exactMatch: exactMatch,
            hasPrefixMatch: hasPrefixMatch
        )
    }

    private func exactMatch(
        for partialSignature: GestureSignature,
        targetBundleIdentifier: String?,
        in candidates: [GestureDefinition]
    ) -> GestureDefinition? {
        let exactCandidates = candidates.filter { $0.signature == partialSignature }

        if let targetBundleIdentifier,
           let appSpecific = exactCandidates.first(where: {
               $0.targetBundleIdentifier == targetBundleIdentifier
           }) {
            return appSpecific
        }

        return exactCandidates.first(where: { $0.targetBundleIdentifier == nil })
    }
}
