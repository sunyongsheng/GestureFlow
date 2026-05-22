import Foundation

public struct GestureConflict: Equatable {
    public var trigger: GestureTrigger
    public var signature: GestureSignature
    public var gestureIDs: [UUID]

    public init(
        trigger: GestureTrigger,
        signature: GestureSignature,
        gestureIDs: [UUID]
    ) {
        self.trigger = trigger
        self.signature = signature
        self.gestureIDs = gestureIDs
    }
}

public struct ConflictDetector {
    public init() {}

    public func detect(in gestures: [GestureDefinition]) -> [GestureConflict] {
        var conflicts: [GestureConflict] = []
        var seen: [GestureConflictKey: [UUID]] = [:]

        for gesture in gestures where gesture.isEnabled {
            let key = GestureConflictKey(trigger: gesture.trigger, signature: gesture.signature)
            seen[key, default: []].append(gesture.id)
        }

        for (key, ids) in seen where ids.count > 1 {
            conflicts.append(GestureConflict(
                trigger: key.trigger,
                signature: key.signature,
                gestureIDs: ids
            ))
        }

        return conflicts
    }
}

private struct GestureConflictKey: Hashable {
    var trigger: GestureTrigger
    var signature: GestureSignature
}
