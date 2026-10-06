import Foundation
import GestureFlowCore

/// A press that GestureFlow tracks. Its target resolves on first access, so presses that never turn
/// into a gesture (plain right clicks) skip the window-stack and Accessibility lookups.
final class GestureActivation {
    private let resolveTarget: () -> ResolvedGestureTarget
    private lazy var resolvedTarget = resolveTarget()

    var target: ResolvedGestureTarget {
        resolvedTarget
    }

    init(resolveTarget: @escaping () -> ResolvedGestureTarget) {
        self.resolveTarget = resolveTarget
    }

    convenience init(target: ResolvedGestureTarget) {
        self.init(resolveTarget: { target })
    }
}

final class GestureActivationGate {
    typealias ConfigurationProvider = () -> AppConfiguration

    private let configurationProvider: ConfigurationProvider
    private let targetResolver: GestureTargetResolving
    private let ownBundleIdentifier: String?

    init(
        configurationProvider: @escaping ConfigurationProvider,
        targetResolver: GestureTargetResolving,
        ownBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.configurationProvider = configurationProvider
        self.targetResolver = targetResolver
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    /// Returns `nil` when the press should pass through without activation. The target is resolved at
    /// press time only when the ignore list needs it to make that decision.
    func gestureActivation(at startPoint: GesturePoint) -> GestureActivation? {
        let config = configurationProvider()
        let policy = config.gestureTargetApplication

        guard !config.ignoredApplicationBundleIdentifiers.isEmpty else {
            return GestureActivation { [targetResolver] in
                targetResolver.resolve(policy: policy, at: startPoint)
            }
        }

        let target = targetResolver.resolve(policy: policy, at: startPoint)
        guard let bundleIdentifier = target.bundleIdentifier else {
            return GestureActivation(target: target)
        }
        if bundleIdentifier == ownBundleIdentifier {
            return GestureActivation(target: target)
        }
        if config.ignoredApplicationBundleIdentifiers.contains(bundleIdentifier) {
            return nil
        }
        return GestureActivation(target: target)
    }
}
