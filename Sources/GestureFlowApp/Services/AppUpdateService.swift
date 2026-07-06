import Foundation
import GestureFlowCore
import os

final class AppUpdateService {
    private static let logger = Logger(subsystem: "com.gestureflow.app", category: "AppUpdate")

    private let releaseClient: GitHubReleaseFetching
    private let updateController: AppUpdateControlling
    private let preferencesStore: UpdatePreferencesStore
    private let scheduler: UpdateScheduler
    private let currentVersion: SemanticVersion

    init(
        releaseClient: GitHubReleaseFetching,
        updateController: AppUpdateControlling,
        preferencesStore: UpdatePreferencesStore,
        scheduler: UpdateScheduler,
        currentAppVersion: String
    ) {
        self.releaseClient = releaseClient
        self.updateController = updateController
        self.preferencesStore = preferencesStore
        self.scheduler = scheduler
        self.currentVersion = (try? SemanticVersion(parsing: currentAppVersion))
            ?? SemanticVersion(major: 0, minor: 0, patch: 0)
    }

    var canCheckForUpdates: Bool {
        updateController.canCheckForUpdates
    }

    var isAutomaticUpdateEnabled: Bool {
        preferencesStore.isAutomaticUpdateEnabled
    }

    func setAutomaticUpdateEnabled(_ isEnabled: Bool, onFire: @escaping () -> Void) {
        preferencesStore.isAutomaticUpdateEnabled = isEnabled
        if isEnabled {
            scheduler.startRepeating(onFire: onFire)
            Task { await performAutomaticUpdateCheck() }
        } else {
            scheduler.stop()
        }
    }

    func startAutomaticUpdatesIfNeeded(onFire: @escaping () -> Void) {
        guard preferencesStore.isAutomaticUpdateEnabled else { return }
        scheduler.startRepeating(onFire: onFire)
        Task { await performAutomaticUpdateCheck() }
    }

    func stopAutomaticUpdates() {
        scheduler.stop()
    }

    /// Manual check: delegates directly to Sparkle's UI.
    func checkForUpdates() async {
        await MainActor.run {
            updateController.checkForUpdates(appcastURL: GitHubReleaseClient.latestAppcastURL)
        }
    }

    /// Scheduled background check: silently fetches from GitHub, then delegates to Sparkle only if a newer version exists.
    func checkForUpdatesInBackground() async {
        guard preferencesStore.isAutomaticUpdateEnabled else { return }
        guard scheduler.shouldPerformCheck(lastCheckDate: preferencesStore.lastUpdateCheckDate) else {
            return
        }
        await performAutomaticUpdateCheck()
    }

    private func performAutomaticUpdateCheck() async {
        do {
            let release = try await releaseClient.fetchLatestRelease()
            preferencesStore.lastUpdateCheckDate = Date()

            guard release.version > currentVersion else { return }

            await MainActor.run {
                updateController.checkForUpdates(appcastURL: release.appcastURL)
            }
        } catch {
            Self.logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
