import Foundation

public struct GesturePoint: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct GestureNormalizer {
    public init() {}

    public func removeJitter(from points: [GesturePoint], minimumDistance: Double = 8) -> [GesturePoint] {
        guard let first = points.first else { return [] }
        var result = [first]

        for point in points.dropFirst() {
            guard let last = result.last else { continue }
            let dx = point.x - last.x
            let dy = point.y - last.y

            if hypot(dx, dy) >= minimumDistance {
                result.append(point)
            }
        }

        return result
    }

    public func normalizeBoundingBox(_ points: [GesturePoint]) -> [GesturePoint] {
        guard points.count >= 2 else { return points }

        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)

        return points.map {
            GesturePoint(
                x: ($0.x - minX) / width,
                y: ($0.y - minY) / height
            )
        }
    }

    public func pathLength(of points: [GesturePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }
}
