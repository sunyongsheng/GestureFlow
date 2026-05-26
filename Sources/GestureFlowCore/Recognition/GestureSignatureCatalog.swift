import Foundation

public struct GestureSignatureOption: Equatable, Identifiable {
    public var signature: GestureSignature
    public var displayName: String

    public var id: String {
        signature.tokens.map(\.rawValue).joined(separator: ",")
    }

    public init(signature: GestureSignature, displayName: String) {
        self.signature = signature
        self.displayName = displayName
    }
}

public struct GestureSignatureCatalog {
    public static let all: [GestureSignatureOption] = generate()

    /// Clockwise from top: up → right → down → left (matches a 4-column compass row).
    private static let directionRank: [GestureDirection: Int] = [
        .up: 0,
        .right: 1,
        .down: 2,
        .left: 3,
    ]

    private static func generate() -> [GestureSignatureOption] {
        var options: [GestureSignatureOption] = []

        func appendOption(tokens: [GestureDirection]) {
            let signature = GestureSignature(tokens: tokens)
            options.append(
                GestureSignatureOption(
                    signature: signature,
                    displayName: signature.chineseDisplayName
                )
            )
        }

        func build(length: Int, previous: GestureDirection?, current: [GestureDirection]) -> [[GestureDirection]] {
            if current.count == length {
                return [current]
            }

            var results: [[GestureDirection]] = []
            for direction in GestureDirection.allCases {
                if direction == previous {
                    continue
                }
                results.append(
                    contentsOf: build(length: length, previous: direction, current: current + [direction])
                )
            }
            return results
        }

        func compareTokens(_ lhs: [GestureDirection], _ rhs: [GestureDirection]) -> Bool {
            if lhs.count != rhs.count {
                return lhs.count < rhs.count
            }
            for (left, right) in zip(lhs, rhs) {
                let leftRank = directionRank[left] ?? 0
                let rightRank = directionRank[right] ?? 0
                if leftRank != rightRank {
                    return leftRank < rightRank
                }
            }
            return false
        }

        // Single strokes — one row in the picker.
        for direction in [GestureDirection.up, .right, .down, .left] {
            appendOption(tokens: [direction])
        }

        // Common two-stroke L shapes first, then the rest in clockwise token order.
        let length2DisplayOrder: [[GestureDirection]] = [
            [.down, .right],
            [.down, .left],
            [.up, .right],
            [.up, .left],
            [.right, .down],
            [.left, .down],
            [.right, .up],
            [.left, .up],
            [.down, .up],
            [.up, .down],
            [.right, .left],
            [.left, .right],
        ]
        for tokens in length2DisplayOrder {
            appendOption(tokens: tokens)
        }

        let length3Presets = build(length: 3, previous: nil, current: []).sorted(by: compareTokens)
        for tokens in length3Presets {
            appendOption(tokens: tokens)
        }

        for tokens in fourTokenDiagonalPresets {
            appendOption(tokens: tokens)
        }

        return options
    }

    /// Four-segment corner gestures, ordered for a single picker row (top-right → bottom-right → top-left → bottom-left).
    private static let fourTokenDiagonalPresets: [[GestureDirection]] = [
        [.right, .up, .left, .down],
        [.right, .down, .left, .up],
        [.left, .up, .right, .down],
        [.left, .down, .right, .up],
    ]
}
