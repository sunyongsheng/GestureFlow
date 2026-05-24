import XCTest
@testable import GestureFlowCore

final class ConfigurationPathFormattingTests: XCTestCase {
    private var homeDirectory: URL!

    override func setUp() {
        super.setUp()
        homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
    }

    func testExpandAndShortenHomePath() {
        let expanded = ConfigurationPathFormatting.expandPath(
            "~/Documents/GestureFlow",
            homeDirectory: homeDirectory
        )
        XCTAssertEqual(
            expanded,
            homeDirectory.appendingPathComponent("Documents/GestureFlow").path
        )

        let shortened = ConfigurationPathFormatting.shortenHomePath(expanded, homeDirectory: homeDirectory)
        XCTAssertEqual(shortened, "~/Documents/GestureFlow")
    }

    func testNormalizedPathsEqualForTildeAndAbsolutePaths() throws {
        let directory = homeDirectory.appendingPathComponent("sync-config", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let absolute = directory.path
        let tilde = ConfigurationPathFormatting.shortenHomePath(absolute, homeDirectory: homeDirectory)

        XCTAssertTrue(
            ConfigurationPathFormatting.normalizedPathsEqual(absolute, tilde, homeDirectory: homeDirectory)
        )
    }
}
