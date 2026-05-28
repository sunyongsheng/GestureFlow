import Foundation

public enum GestureMatchResult: Equatable {
    case none
    case exact(GestureDefinition)
    case prefix(GestureDefinition)

    public var gesture: GestureDefinition? {
        switch self {
        case .none:
            return nil
        case let .exact(gesture), let .prefix(gesture):
            return gesture
        }
    }

    public var isExact: Bool {
        if case .exact = self { return true }
        return false
    }
}

public struct GestureMatcher {
    public enum PrefixPolicy: Equatable {
        case disabled
        /// If there is no exact match, choose a prefix match for display/feedback.
        case fallbackToPrefix
    }

    public init() {}

    public func match(
        trigger: GestureTrigger,
        signature: GestureSignature?,
        targetBundleIdentifier: String?,
        prefixPolicy: PrefixPolicy,
        in gestures: [GestureDefinition]
    ) -> GestureMatchResult {
        guard let signature, !signature.tokens.isEmpty else { return .none }

        let candidates = gestures.filter { $0.isEnabled && $0.trigger == trigger }
        let exact = GestureCandidateSelector.preferred(
            among: candidates.filter { $0.signature == signature },
            targetBundleIdentifier: targetBundleIdentifier
        )
        if let exact {
            return .exact(exact)
        }

        guard prefixPolicy == .fallbackToPrefix else {
            return .none
        }

        let prefixMatches = candidates.filter { gesture in
            gesture.signature.tokens.starts(with: signature.tokens)
        }
        guard !prefixMatches.isEmpty else { return .none }

        let shortestTokenCount = prefixMatches.map(\.signature.tokens.count).min()
        let tied = prefixMatches.filter { $0.signature.tokens.count == shortestTokenCount }
        if let preferred = GestureCandidateSelector.preferred(
            among: tied,
            targetBundleIdentifier: targetBundleIdentifier
        ) {
            return .prefix(preferred)
        }

        if let shortest = prefixMatches.min(by: { $0.signature.tokens.count < $1.signature.tokens.count }) {
            return .prefix(shortest)
        }

        return .none
    }
}

