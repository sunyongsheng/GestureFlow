import Foundation

public enum GestureSignatureLookup {
    public static func id(for signature: GestureSignature) -> String {
        signature.tokens.map(\.rawValue).joined(separator: ",")
    }

    public static func exists(
        _ signature: GestureSignature,
        gestureSignatures: [GestureSignature]
    ) -> Bool {
        if GestureSignatureCatalog.all.contains(where: { $0.signature == signature }) {
            return true
        }
        return gestureSignatures.contains(signature)
    }
}
