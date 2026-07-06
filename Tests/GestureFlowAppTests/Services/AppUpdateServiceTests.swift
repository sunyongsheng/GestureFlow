import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class AppUpdateServiceTests: XCTestCase {
    private func makePreferencesStore(automaticEnabled: Bool = false) -> UpdatePreferencesStore {
        let store = UpdatePreferencesStore(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        store.isAutomaticUpdateEnabled = automaticEnabled
        return store
    }

    func testManualCheckDelegatesToSparkleDirectlyWithStaticURL() async {
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: MockReleaseClient(result: .failure(GitHubReleaseClientError.invalidResponse)),
            updateController: controller,
            preferencesStore: makePreferencesStore(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        await service.checkForUpdates()

        XCTAssertEqual(
            controller.lastAppcastURL,
            GitHubReleaseClient.latestAppcastURL,
            "Manual check should delegate to Sparkle with the static appcast URL"
        )
    }

    func testManualCheckDoesNotFetchFromGitHub() async {
        let client = MockReleaseClient(result: .failure(GitHubReleaseClientError.invalidResponse))
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: client,
            updateController: controller,
            preferencesStore: makePreferencesStore(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        await service.checkForUpdates()

        XCTAssertFalse(client.fetchWasCalled, "Manual check should not fetch from GitHub")
    }

    func testBackgroundCheckTriggersSparkleWhenNewerVersionExists() async {
        let appcastURL = URL(string: "https://example.com/appcast.xml")!
        let client = MockReleaseClient(
            result: .success(
                GitHubReleaseInfo(
                    tagName: "release/v0.3.0",
                    version: SemanticVersion(major: 0, minor: 3, patch: 0),
                    appcastURL: appcastURL,
                    releaseNotes: nil
                )
            )
        )
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: client,
            updateController: controller,
            preferencesStore: makePreferencesStore(automaticEnabled: true),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        await service.checkForUpdatesInBackground()

        XCTAssertEqual(controller.lastAppcastURL, appcastURL)
    }

    func testBackgroundCheckSkipsSparkleWhenAlreadyUpToDate() async {
        let client = MockReleaseClient(
            result: .success(
                GitHubReleaseInfo(
                    tagName: "release/v0.2.0",
                    version: SemanticVersion(major: 0, minor: 2, patch: 0),
                    appcastURL: URL(string: "https://example.com/appcast.xml")!,
                    releaseNotes: nil
                )
            )
        )
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: client,
            updateController: controller,
            preferencesStore: makePreferencesStore(automaticEnabled: true),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        await service.checkForUpdatesInBackground()

        XCTAssertNil(controller.lastAppcastURL)
    }

    func testBackgroundCheckSkipsWhenAutomaticUpdatesDisabled() async {
        let client = MockReleaseClient(result: .failure(GitHubReleaseClientError.httpError(statusCode: 500)))
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: client,
            updateController: controller,
            preferencesStore: makePreferencesStore(automaticEnabled: false),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        await service.checkForUpdatesInBackground()

        XCTAssertFalse(client.fetchWasCalled)
        XCTAssertNil(controller.lastAppcastURL)
    }
}

private final class MockReleaseClient: GitHubReleaseFetching, @unchecked Sendable {
    let result: Result<GitHubReleaseInfo, Error>
    private(set) var fetchWasCalled = false

    init(result: Result<GitHubReleaseInfo, Error>) {
        self.result = result
    }

    func fetchLatestRelease() async throws -> GitHubReleaseInfo {
        fetchWasCalled = true
        switch result {
        case .success(let info):
            return info
        case .failure(let error):
            throw error
        }
    }
}

private final class MockUpdateController: AppUpdateControlling {
    var canCheckForUpdates = true
    var lastAppcastURL: URL?

    func checkForUpdates(appcastURL: URL) {
        lastAppcastURL = appcastURL
    }
}
