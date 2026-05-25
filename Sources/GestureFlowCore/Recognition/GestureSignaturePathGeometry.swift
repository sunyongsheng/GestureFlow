import Foundation

public struct PathPoint: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum GestureSignaturePathGeometry {
    private static let unitSegmentLength: Double = 1
    private static let oppositeStaggerOffset: Double = 0.22

    public static func polyline(for signature: GestureSignature) -> [PathPoint] {
        guard !signature.tokens.isEmpty else { return [] }

        var points = [PathPoint(x: 0, y: 0)]
        var x = 0.0
        var y = 0.0

        for index in signature.tokens.indices {
            let direction = signature.tokens[index]
            let previousDirection = index > 0 ? signature.tokens[index - 1] : nil

            if let previousDirection, isOpposite(previousDirection, direction) {
                let priorTokens = signature.tokens[..<index]
                let staggerDirection = staggerDirection(
                    entering: direction,
                    priorTokens: priorTokens,
                    signatureTokens: signature.tokens[...]
                )
                apply(staggerDirection, offset: oppositeStaggerOffset, x: &x, y: &y)
                points.append(PathPoint(x: x, y: y))
            }

            apply(direction, offset: unitSegmentLength, x: &x, y: &y)
            points.append(PathPoint(x: x, y: y))
        }

        return points
    }

    public static func terminalDirection(for signature: GestureSignature) -> GestureDirection? {
        signature.tokens.last
    }

    public static func fittedPolyline(
        for signature: GestureSignature,
        paddingRatio: Double = 0.12
    ) -> [PathPoint] {
        let points = polyline(for: signature)
        guard !points.isEmpty else { return [] }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return points
        }

        let width = max(maxX - minX, 1e-6)
        let height = max(maxY - minY, 1e-6)
        let padding = max(0, min(paddingRatio, 0.4))
        let inner = 1 - 2 * padding
        let scale = min(inner / width, inner / height)

        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        return points.map { point in
            let nx = 0.5 + (point.x - centerX) * scale
            let ny = 0.5 + (point.y - centerY) * scale
            return PathPoint(x: nx, y: ny)
        }
    }

    private static func isOpposite(_ lhs: GestureDirection, _ rhs: GestureDirection) -> Bool {
        switch (lhs, rhs) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left):
            return true
        default:
            return false
        }
    }

    private static func staggerDirection(
        entering direction: GestureDirection,
        priorTokens: ArraySlice<GestureDirection>,
        signatureTokens: ArraySlice<GestureDirection>
    ) -> GestureDirection {
        switch direction {
        case .left, .right:
            return lastVerticalDirection(in: priorTokens)
                ?? lastVerticalDirection(in: signatureTokens)
                ?? .down
        case .up, .down:
            return lastHorizontalDirection(in: priorTokens)
                ?? lastHorizontalDirection(in: signatureTokens)
                ?? .right
        }
    }

    private static func lastVerticalDirection(in tokens: ArraySlice<GestureDirection>) -> GestureDirection? {
        for direction in tokens.reversed() where direction == .up || direction == .down {
            return direction
        }
        return nil
    }

    private static func lastHorizontalDirection(in tokens: ArraySlice<GestureDirection>) -> GestureDirection? {
        for direction in tokens.reversed() where direction == .left || direction == .right {
            return direction
        }
        return nil
    }

    private static func apply(
        _ direction: GestureDirection,
        offset: Double,
        x: inout Double,
        y: inout Double
    ) {
        switch direction {
        case .up:
            y -= offset
        case .down:
            y += offset
        case .left:
            x -= offset
        case .right:
            x += offset
        }
    }
}
