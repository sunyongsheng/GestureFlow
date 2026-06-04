import Foundation

public enum SemanticVersionParseError: Error, Equatable {
    case invalidFormat(String)
}

public struct SemanticVersion: Equatable, Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(parsing rawValue: String) throws {
        let trimmed: String
        if rawValue.hasPrefix("release/v") {
            trimmed = String(rawValue.dropFirst("release/v".count))
        } else if rawValue.hasPrefix("v") {
            trimmed = String(rawValue.dropFirst())
        } else {
            trimmed = rawValue
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else {
            throw SemanticVersionParseError.invalidFormat(rawValue)
        }

        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
