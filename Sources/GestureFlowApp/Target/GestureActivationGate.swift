import Foundation
import GestureFlowCore

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

    /// Returns `nil` when the gesture should pass through without activation; otherwise the target resolved at gesture start.
    func resolvedTargetForGestureActivation(at startPoint: GesturePoint) -> ResolvedGestureTarget? {
        let config = configurationProvider()
        let target = targetResolver.resolve(
            policy: config.gestureTargetApplication,
            at: startPoint
        )

        guard !config.ignoredApplicationBundleIdentifiers.isEmpty else {
            return target
        }

        guard let bundleIdentifier = target.bundleIdentifier else {
            return target
        }
        if bundleIdentifier == ownBundleIdentifier {
            return target
        }
        if config.ignoredApplicationBundleIdentifiers.contains(bundleIdentifier) {
            return nil
        }
        return target
    }
}
