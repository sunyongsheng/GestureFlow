import Foundation
import GestureFlowCore
import os

enum ManualUpdateCheckOutcome: Equatable {
    case upToDate
    case delegatedToSparkle
    case failed(GitHubReleaseClientError)
}

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
            Task { await checkForUpdatesIfNeeded(force: false) }
        } else {
            scheduler.stop()
        }
    }

    func startAutomaticUpdatesIfNeeded(onFire: @escaping () -> Void) {
        guard preferencesStore.isAutomaticUpdateEnabled else { return }
        scheduler.startRepeating(onFire: onFire)
        Task { await checkForUpdatesIfNeeded(force: false) }
    }

    func stopAutomaticUpdates() {
        scheduler.stop()
    }

    func checkForUpdatesIfNeeded(
        force: Bool,
        onManualProgress: (@MainActor (Bool) -> Void)? = nil,
        onManualOutcome: (@MainActor (ManualUpdateCheckOutcome) -> Void)? = nil
    ) async {
        if !force {
            guard preferencesStore.isAutomaticUpdateEnabled else { return }
            guard scheduler.shouldPerformCheck(lastCheckDate: preferencesStore.lastUpdateCheckDate) else {
                return
            }
        }

        if force {
            await MainActor.run { onManualProgress?(true) }
        }

        let manualOutcome = await performUpdateCheck(force: force)

        if force {
            await MainActor.run {
                onManualProgress?(false)
                if let manualOutcome {
                    onManualOutcome?(manualOutcome)
                }
            }
        }
    }

    private func performUpdateCheck(force: Bool) async -> ManualUpdateCheckOutcome? {
        do {
            let release = try await releaseClient.fetchLatestRelease()
            preferencesStore.lastUpdateCheckDate = Date()

            if release.version <= currentVersion {
                return force ? .upToDate : nil
            }

            await MainActor.run {
                updateController.checkForUpdates(appcastURL: release.appcastURL)
            }
            return force ? .delegatedToSparkle : nil
        } catch let error as GitHubReleaseClientError {
            Self.logger.error("Update check failed: \(String(describing: error), privacy: .public)")
            return force ? .failed(error) : nil
        } catch {
            Self.logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            return force ? .failed(.invalidResponse) : nil
        }
    }
}
