import Foundation

public struct GestureSignatureOption: Equatable, Identifiable {
    public var signature: GestureSignature
    public var displayName: String

    public var id: String { displayName }

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

        return options
    }
}
