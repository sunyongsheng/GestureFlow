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

        func build(length: Int, previous: GestureDirection?, current: [GestureDirection]) {
            if current.count == length {
                appendOption(tokens: current)
                return
            }

            for direction in GestureDirection.allCases {
                if direction == previous {
                    continue
                }
                build(length: length, previous: direction, current: current + [direction])
            }
        }

        for length in 1...3 {
            build(length: length, previous: nil, current: [])
        }

        for tokens in Self.fourTokenDiagonalPresets {
            appendOption(tokens: tokens)
        }

        return options
    }

    /// Four-segment corner gestures (e.g. right-down-left-up).
    private static let fourTokenDiagonalPresets: [[GestureDirection]] = [
        [.right, .down, .left, .up],
        [.left, .down, .right, .up],
        [.right, .up, .left, .down],
        [.left, .up, .right, .down],
    ]
}
