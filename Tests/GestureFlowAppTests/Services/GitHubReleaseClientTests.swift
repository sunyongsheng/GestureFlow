import XCTest
@testable import GestureFlowApp

final class GitHubReleaseClientTests: XCTestCase {
    func testParsesLatestReleaseFixture() throws {
        let fixture = """
        {
          "tag_name": "release/v0.2.0",
          "assets": [
            {
              "name": "GestureFlow-0.2.0-macos.zip",
              "browser_download_url": "https://example.com/app.zip"
            },
            {
              "name": "appcast.xml",
              "browser_download_url": "https://example.com/appcast.xml"
            }
          ]
        }
        """.data(using: .utf8)!

        let client = GitHubReleaseClient(currentAppVersion: "0.1.1")
        let release = try client.parseReleaseData(fixture)

        XCTAssertEqual(release.tagName, "release/v0.2.0")
        XCTAssertEqual(release.version.description, "0.2.0")
        XCTAssertEqual(release.appcastURL.absoluteString, "https://example.com/appcast.xml")
    }

    func testMissingAppcastThrows() {
        let fixture = """
        {
          "tag_name": "release/v0.2.0",
          "assets": [
            {
              "name": "GestureFlow-0.2.0-macos.zip",
              "browser_download_url": "https://example.com/app.zip"
            }
          ]
        }
        """.data(using: .utf8)!

        let client = GitHubReleaseClient(currentAppVersion: "0.1.1")
        XCTAssertThrowsError(try client.parseReleaseData(fixture)) { error in
            XCTAssertEqual(error as? GitHubReleaseClientError, .missingAppcastAsset)
        }
    }

    func testInvalidTagNameThrows() {
        let fixture = """
        {
          "tag_name": "broken-tag",
          "assets": [
            {
              "name": "appcast.xml",
              "browser_download_url": "https://example.com/appcast.xml"
            }
          ]
        }
        """.data(using: .utf8)!

        let client = GitHubReleaseClient(currentAppVersion: "0.1.1")
        XCTAssertThrowsError(try client.parseReleaseData(fixture)) { error in
            XCTAssertEqual(error as? GitHubReleaseClientError, .invalidTagName("broken-tag"))
        }
    }
}
