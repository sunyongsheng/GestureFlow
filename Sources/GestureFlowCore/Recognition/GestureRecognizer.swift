import Foundation

public struct GestureRecognizer {
    /// Maximum direction segments allowed when drawing a custom signature in settings.
    public static let maxRecordingSegmentCount = 8
    static let jitterDistance: Double = 8
    static let minimumPathLength: Double = 24

    private let normalizer: GestureNormalizer

    public init(normalizer: GestureNormalizer = GestureNormalizer()) {
        self.normalizer = normalizer
    }

    public func recognize(
        points: [GesturePoint],
        coordinateSystem: GesturePointCoordinateSystem = .screen,
        maxTokenCount: Int? = nil
    ) -> GestureSignature? {
        let cleaned = normalizer.removeJitter(from: points, minimumDistance: Self.jitterDistance)
        guard cleaned.count >= 2 else { return nil }
        guard normalizer.pathLength(of: cleaned) >= Self.minimumPathLength else { return nil }

        var directions: [GestureDirection] = []

        for pair in zip(cleaned, cleaned.dropFirst()) {
            let direction = Self.direction(from: pair.0, to: pair.1, coordinateSystem: coordinateSystem)
            if directions.last != direction {
                directions.append(direction)
            }
        }

        if let maxTokenCount, directions.count > maxTokenCount {
            directions = Array(directions.prefix(maxTokenCount))
        }

        return directions.isEmpty ? nil : GestureSignature(tokens: directions)
    }

    static func direction(
        from start: GesturePoint,
        to end: GesturePoint,
        coordinateSystem: GesturePointCoordinateSystem
    ) -> GestureDirection {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if abs(dx) >= abs(dy) {
            return dx >= 0 ? .right : .left
        }
        switch coordinateSystem {
        case .screen:
            return dy <= 0 ? .down : .up
        case .view:
            return dy >= 0 ? .down : .up
        }
    }
}

/// Recognizes a gesture while its points arrive: after each `append`, `signature` equals
/// `GestureRecognizer().recognize(points:)` over the points so far, at O(1) cost per point.
public struct IncrementalGestureRecognizer {
    private let coordinateSystem: GesturePointCoordinateSystem
    private var lastKeptPoint: GesturePoint?
    private var keptPointCount = 0
    private var pathLength: Double = 0
    private var directions: [GestureDirection] = []

    public init(coordinateSystem: GesturePointCoordinateSystem = .screen) {
        self.coordinateSystem = coordinateSystem
    }

    public var signature: GestureSignature? {
        guard keptPointCount >= 2,
              pathLength >= GestureRecognizer.minimumPathLength,
              !directions.isEmpty else {
            return nil
        }
        return GestureSignature(tokens: directions)
    }

    public mutating func append(_ point: GesturePoint) {
        guard let lastKeptPoint else {
            self.lastKeptPoint = point
            keptPointCount = 1
            return
        }

        let distance = hypot(point.x - lastKeptPoint.x, point.y - lastKeptPoint.y)
        guard distance >= GestureRecognizer.jitterDistance else { return }

        pathLength += distance
        keptPointCount += 1
        let direction = GestureRecognizer.direction(
            from: lastKeptPoint,
            to: point,
            coordinateSystem: coordinateSystem
        )
        if directions.last != direction {
            directions.append(direction)
        }
        self.lastKeptPoint = point
    }
}
