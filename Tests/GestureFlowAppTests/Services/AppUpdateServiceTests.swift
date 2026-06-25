import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class AppUpdateServiceTests: XCTestCase {
    private func makePreferencesStore() -> UpdatePreferencesStore {
        UpdatePreferencesStore(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
    }

    func testManualCheckReportsUpToDateWhenReleaseNotNewer() async {
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
            preferencesStore: makePreferencesStore(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        var outcome: ManualUpdateCheckOutcome?
        await service.checkForUpdatesIfNeeded(force: true, onManualOutcome: { outcome = $0 })

        XCTAssertEqual(outcome, .upToDate)
        XCTAssertNil(controller.lastAppcastURL)
    }

    func testManualCheckDelegatesToSparkleWhenReleaseIsNewer() async {
        let appcastURL = URL(string: "https://example.com/appcast.xml")!
        let client = MockReleaseClient(
            result: .success(
                GitHubReleaseInfo(
                    tagName: "release/v0.3.0",
                    version: SemanticVersion(major: 0, minor: 3, patch: 0),
                    appcastURL: appcastURL,
                    releaseNotes: "• Some improvement"
                )
            )
        )
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: client,
            updateController: controller,
            preferencesStore: makePreferencesStore(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0",
            allowsSparkleInstall: true
        )

        var outcome: ManualUpdateCheckOutcome?
        await service.checkForUpdatesIfNeeded(force: true, onManualOutcome: { outcome = $0 })

        XCTAssertEqual(outcome, .delegatedToSparkle)
        XCTAssertEqual(controller.lastAppcastURL, appcastURL)
    }

    func testManualCheckBlocksSparkleInstallWhenDisabled() async {
        let client = MockReleaseClient(
            result: .success(
                GitHubReleaseInfo(
                    tagName: "release/v0.3.0",
                    version: SemanticVersion(major: 0, minor: 3, patch: 0),
                    appcastURL: URL(string: "https://example.com/appcast.xml")!,
                    releaseNotes: "• Bug fix"
                )
            )
        )
        let controller = MockUpdateController()
        let service = AppUpdateService(
            releaseClient: client,
            updateController: controller,
            preferencesStore: makePreferencesStore(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0",
            allowsSparkleInstall: false
        )

        var outcome: ManualUpdateCheckOutcome?
        await service.checkForUpdatesIfNeeded(force: true, onManualOutcome: { outcome = $0 })

        XCTAssertEqual(
            outcome,
            .installUnavailableInDevelopment(
                latestVersion: SemanticVersion(major: 0, minor: 3, patch: 0),
                releaseNotes: "• Bug fix"
            )
        )
        XCTAssertNil(controller.lastAppcastURL)
    }

    func testManualCheckSurfacesGitHubError() async {
        let client = MockReleaseClient(result: .failure(GitHubReleaseClientError.missingAppcastAsset))
        let service = AppUpdateService(
            releaseClient: client,
            updateController: MockUpdateController(),
            preferencesStore: makePreferencesStore(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        var outcome: ManualUpdateCheckOutcome?
        await service.checkForUpdatesIfNeeded(force: true, onManualOutcome: { outcome = $0 })

        XCTAssertEqual(outcome, .failed(.missingAppcastAsset))
    }

    func testAutomaticCheckDoesNotSurfaceManualOutcome() async {
        let client = MockReleaseClient(result: .failure(GitHubReleaseClientError.httpError(statusCode: 500)))
        let service = AppUpdateService(
            releaseClient: client,
            updateController: MockUpdateController(),
            preferencesStore: {
                let store = UpdatePreferencesStore(
                    defaults: UserDefaults(suiteName: "test.\(UUID())")!
                )
                store.isAutomaticUpdateEnabled = true
                return store
            }(),
            scheduler: UpdateScheduler(),
            currentAppVersion: "0.2.0"
        )

        var outcome: ManualUpdateCheckOutcome?
        await service.checkForUpdatesIfNeeded(force: false, onManualOutcome: { outcome = $0 })

        XCTAssertNil(outcome)
    }
}

private final class MockReleaseClient: GitHubReleaseFetching, @unchecked Sendable {
    let result: Result<GitHubReleaseInfo, Error>

    init(result: Result<GitHubReleaseInfo, Error>) {
        self.result = result
    }

    func fetchLatestRelease() async throws -> GitHubReleaseInfo {
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
