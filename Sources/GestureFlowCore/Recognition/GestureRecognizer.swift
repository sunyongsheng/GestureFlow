import Foundation

public struct GestureRecognizer {
    /// Maximum direction segments allowed when drawing a custom signature in settings.
    public static let maxRecordingSegmentCount = 8

    private let normalizer: GestureNormalizer

    public init(normalizer: GestureNormalizer = GestureNormalizer()) {
        self.normalizer = normalizer
    }

    public func recognize(
        points: [GesturePoint],
        coordinateSystem: GesturePointCoordinateSystem = .screen,
        maxTokenCount: Int? = nil
    ) -> GestureSignature? {
        let cleaned = normalizer.removeJitter(from: points)
        guard cleaned.count >= 2 else { return nil }
        guard normalizer.pathLength(of: cleaned) >= 24 else { return nil }

        var directions: [GestureDirection] = []

        for pair in zip(cleaned, cleaned.dropFirst()) {
            let dx = pair.1.x - pair.0.x
            let dy = pair.1.y - pair.0.y
            let direction: GestureDirection
            if abs(dx) >= abs(dy) {
                direction = dx >= 0 ? .right : .left
            } else {
                direction = verticalDirection(deltaY: dy, coordinateSystem: coordinateSystem)
            }

            if directions.last != direction {
                directions.append(direction)
            }
        }

        if let maxTokenCount, directions.count > maxTokenCount {
            directions = Array(directions.prefix(maxTokenCount))
        }

        return directions.isEmpty ? nil : GestureSignature(tokens: directions)
    }

    private func verticalDirection(
        deltaY: Double,
        coordinateSystem: GesturePointCoordinateSystem
    ) -> GestureDirection {
        switch coordinateSystem {
        case .screen:
            return deltaY <= 0 ? .down : .up
        case .view:
            return deltaY >= 0 ? .down : .up
        }
    }
}
