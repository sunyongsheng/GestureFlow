import Foundation

public enum ConfigurationPathFormatting {
    public static func homeDirectoryURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
    }

    public static func expandPath(
        _ path: String,
        homeDirectory: URL? = nil
    ) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = (homeDirectory ?? homeDirectoryURL()).path

        if trimmed == "~" {
            return home
        }

        if trimmed.hasPrefix("~/") {
            return URL(fileURLWithPath: home, isDirectory: true)
                .appendingPathComponent(String(trimmed.dropFirst(2)))
                .path
        }

        return trimmed
    }

    public static func shortenHomePath(
        _ path: String,
        homeDirectory: URL? = nil
    ) -> String {
        let home = (homeDirectory ?? homeDirectoryURL()).path
        if path == home {
            return "~"
        }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    public static func normalizedDirectoryURL(
        from path: String,
        homeDirectory: URL? = nil
    ) -> URL? {
        let expanded = expandPath(path, homeDirectory: homeDirectory)
        guard !expanded.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: expanded, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    public static func normalizedPathsEqual(
        _ lhs: String,
        _ rhs: String,
        homeDirectory: URL? = nil
    ) -> Bool {
        guard let left = normalizedDirectoryURL(from: lhs, homeDirectory: homeDirectory),
              let right = normalizedDirectoryURL(from: rhs, homeDirectory: homeDirectory) else {
            return false
        }
        return left == right
    }
}
