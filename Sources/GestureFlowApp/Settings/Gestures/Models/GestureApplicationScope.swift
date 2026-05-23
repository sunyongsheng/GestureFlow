import Foundation

enum GestureApplicationScope: Hashable {
    case global
    case application(bundleIdentifier: String)

    var targetBundleIdentifier: String? {
        switch self {
        case .global:
            return nil
        case .application(let bundleIdentifier):
            return bundleIdentifier
        }
    }

    init(targetBundleIdentifier: String?) {
        if let targetBundleIdentifier {
            self = .application(bundleIdentifier: targetBundleIdentifier)
        } else {
            self = .global
        }
    }
}
