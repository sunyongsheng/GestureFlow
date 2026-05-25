import Foundation

public protocol GestureTargetResolving: Sendable {
    func resolve(
        policy: GestureTargetApplication,
        at startPoint: GesturePoint
    ) -> ResolvedGestureTarget
}
