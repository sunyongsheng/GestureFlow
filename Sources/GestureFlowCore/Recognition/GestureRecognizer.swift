import Foundation

public struct GestureRecognizer {
    private let normalizer: GestureNormalizer

    public init(normalizer: GestureNormalizer = GestureNormalizer()) {
        self.normalizer = normalizer
    }

    public func recognize(points: [GesturePoint]) -> GestureSignature? {
        let cleaned = normalizer.removeJitter(from: points)
        guard cleaned.count >= 2 else { return nil }
        guard normalizer.pathLength(of: cleaned) >= 24 else { return nil }

        var directions: [GestureDirection] = []

        for pair in zip(cleaned, cleaned.dropFirst()) {
            let dx = pair.1.x - pair.0.x
            let dy = pair.1.y - pair.0.y
            let direction: GestureDirection = abs(dx) >= abs(dy)
                ? (dx >= 0 ? .right : .left)
                : (dy >= 0 ? .down : .up)

            if directions.last != direction {
                directions.append(direction)
            }
        }

        return directions.isEmpty ? nil : GestureSignature(tokens: directions)
    }
}
