import Foundation
import GestureFlowCore

struct GitHubReleaseInfo: Equatable, Sendable {
    let tagName: String
    let version: SemanticVersion
    let appcastURL: URL
}

enum GitHubReleaseClientError: Error, Equatable {
    case invalidResponse
    case httpError(statusCode: Int)
    case missingAppcastAsset
    case invalidTagName(String)
}

protocol GitHubReleaseFetching: Sendable {
    func fetchLatestRelease() async throws -> GitHubReleaseInfo
}

final class GitHubReleaseClient: GitHubReleaseFetching, @unchecked Sendable {
    static let repository = "sunyongsheng/GestureFlow"
    static let appcastAssetName = "appcast.xml"
    /// Avoids GitHub REST API rate limits (403 when unauthenticated quota is exhausted).
    static let latestAppcastURL = URL(
        string: "https://github.com/sunyongsheng/GestureFlow/releases/latest/download/appcast.xml"
    )!

    private let session: URLSession
    private let currentAppVersion: String

    init(session: URLSession = .shared, currentAppVersion: String) {
        self.session = session
        self.currentAppVersion = currentAppVersion
    }

    func fetchLatestRelease() async throws -> GitHubReleaseInfo {
        var request = URLRequest(url: Self.latestAppcastURL)
        request.setValue("GestureFlow/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubReleaseClientError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw GitHubReleaseClientError.httpError(statusCode: httpResponse.statusCode)
        }

        return try parseAppcastData(data)
    }

    func parseAppcastData(_ data: Data) throws -> GitHubReleaseInfo {
        guard let xml = String(data: data, encoding: .utf8) else {
            throw GitHubReleaseClientError.invalidResponse
        }

        guard let versionString = Self.sparkleVersion(in: xml) else {
            throw GitHubReleaseClientError.missingAppcastAsset
        }

        let version: SemanticVersion
        do {
            version = try SemanticVersion(parsing: versionString)
        } catch {
            throw GitHubReleaseClientError.invalidTagName(versionString)
        }

        let tagName = "release/v\(version)"
        return GitHubReleaseInfo(
            tagName: tagName,
            version: version,
            appcastURL: Self.latestAppcastURL
        )
    }

    private static func sparkleVersion(in xml: String) -> String? {
        // Prefer shortVersionString (marketing semver) for our pre-Sparkle check.
        // sparkle:version matches CFBundleVersion and is only used by Sparkle internally.
        let patterns = [
            "<sparkle:shortVersionString>\\s*([^<]+?)\\s*</sparkle:shortVersionString>",
            "<sparkle:version>\\s*([^<]+?)\\s*</sparkle:version>"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: xml) else {
                continue
            }
            let value = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }
}

#if DEBUG
extension GitHubReleaseClient {
    static func makeForTesting(currentAppVersion: String) -> GitHubReleaseClient {
        GitHubReleaseClient(session: .shared, currentAppVersion: currentAppVersion)
    }
}
#endif
