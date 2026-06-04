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

    private let session: URLSession
    private let currentAppVersion: String

    init(session: URLSession = .shared, currentAppVersion: String) {
        self.session = session
        self.currentAppVersion = currentAppVersion
    }

    func fetchLatestRelease() async throws -> GitHubReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GestureFlow/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubReleaseClientError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw GitHubReleaseClientError.httpError(statusCode: httpResponse.statusCode)
        }

        return try parseReleaseData(data)
    }

    func parseReleaseData(_ data: Data) throws -> GitHubReleaseInfo {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any],
              let tagName = object["tag_name"] as? String else {
            throw GitHubReleaseClientError.invalidResponse
        }

        let version: SemanticVersion
        do {
            version = try SemanticVersion(parsing: tagName)
        } catch {
            throw GitHubReleaseClientError.invalidTagName(tagName)
        }

        guard let assets = object["assets"] as? [[String: Any]] else {
            throw GitHubReleaseClientError.missingAppcastAsset
        }

        guard let appcastURL = assets.compactMap({ asset -> URL? in
            guard let name = asset["name"] as? String,
                  name == Self.appcastAssetName,
                  let urlString = asset["browser_download_url"] as? String else {
                return nil
            }
            return URL(string: urlString)
        }).first else {
            throw GitHubReleaseClientError.missingAppcastAsset
        }

        return GitHubReleaseInfo(tagName: tagName, version: version, appcastURL: appcastURL)
    }
}

#if DEBUG
extension GitHubReleaseClient {
    static func makeForTesting(currentAppVersion: String) -> GitHubReleaseClient {
        GitHubReleaseClient(session: .shared, currentAppVersion: currentAppVersion)
    }
}
#endif
