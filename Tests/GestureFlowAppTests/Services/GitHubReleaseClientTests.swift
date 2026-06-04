import XCTest
@testable import GestureFlowApp

final class GitHubReleaseClientTests: XCTestCase {
    func testParsesAppcastFixture() throws {
        let fixture = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 0.2.1</title>
              <sparkle:version>0.2.1</sparkle:version>
              <sparkle:shortVersionString>0.2.1</sparkle:shortVersionString>
            </item>
          </channel>
        </rss>
        """.data(using: .utf8)!

        let client = GitHubReleaseClient(currentAppVersion: "0.1.1")
        let release = try client.parseAppcastData(fixture)

        XCTAssertEqual(release.tagName, "release/v0.2.1")
        XCTAssertEqual(release.version.description, "0.2.1")
        XCTAssertEqual(
            release.appcastURL.absoluteString,
            GitHubReleaseClient.latestAppcastURL.absoluteString
        )
    }

    func testMissingVersionInAppcastThrows() {
        let fixture = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0">
          <channel><item><title>empty</title></item></channel>
        </rss>
        """.data(using: .utf8)!

        let client = GitHubReleaseClient(currentAppVersion: "0.1.1")
        XCTAssertThrowsError(try client.parseAppcastData(fixture)) { error in
            XCTAssertEqual(error as? GitHubReleaseClientError, .missingAppcastAsset)
        }
    }

    func testInvalidVersionInAppcastThrows() {
        let fixture = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <sparkle:version>not-a-version</sparkle:version>
            </item>
          </channel>
        </rss>
        """.data(using: .utf8)!

        let client = GitHubReleaseClient(currentAppVersion: "0.1.1")
        XCTAssertThrowsError(try client.parseAppcastData(fixture)) { error in
            XCTAssertEqual(error as? GitHubReleaseClientError, .invalidTagName("not-a-version"))
        }
    }
}
