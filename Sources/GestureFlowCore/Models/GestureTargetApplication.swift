import Foundation

public enum GestureTargetApplication: String, Codable, CaseIterable, Sendable {
    case foreground
    case underMouse

    public static let defaultValue: GestureTargetApplication = .underMouse

    public var displayName: String {
        switch self {
        case .foreground:
            return "当前前台应用"
        case .underMouse:
            return "鼠标下方应用"
        }
    }
}

public struct ResolvedGestureTarget: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var processIdentifier: Int32?

    public init(bundleIdentifier: String?, processIdentifier: Int32?) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }

    public var isValid: Bool {
        bundleIdentifier != nil && processIdentifier != nil
    }

    public static let invalid = ResolvedGestureTarget(bundleIdentifier: nil, processIdentifier: nil)
}
