import Foundation

final class AppUpdateService {
    private let releaseClient: GitHubReleaseFetching
    private let updateController: AppUpdateControlling
    private let preferencesStore: UpdatePreferencesStore
    private let scheduler: UpdateScheduler

    init(
        releaseClient: GitHubReleaseFetching,
        updateController: AppUpdateControlling,
        preferencesStore: UpdatePreferencesStore,
        scheduler: UpdateScheduler
    ) {
        self.releaseClient = releaseClient
        self.updateController = updateController
        self.preferencesStore = preferencesStore
        self.scheduler = scheduler
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

    func checkForUpdatesIfNeeded(force: Bool) async {
        if !force {
            guard preferencesStore.isAutomaticUpdateEnabled else { return }
            guard scheduler.shouldPerformCheck(lastCheckDate: preferencesStore.lastUpdateCheckDate) else {
                return
            }
        }

        preferencesStore.lastUpdateCheckDate = Date()

        do {
            let release = try await releaseClient.fetchLatestRelease()
            await MainActor.run {
                updateController.checkForUpdates(appcastURL: release.appcastURL)
            }
        } catch {
            // Automatic checks fail silently; manual checks surface Sparkle errors when feed is unreachable.
        }
    }
}
