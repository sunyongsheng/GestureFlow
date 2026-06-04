import AppKit
import Sparkle

protocol AppUpdateControlling: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates(appcastURL: URL)
}

final class AppUpdateController: NSObject, AppUpdateControlling, SPUUpdaterDelegate {
    private var pendingFeedURL: URL?
    private lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
        return controller
    }()

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates(appcastURL: URL) {
        #if DEBUG
        // Sparkle install is disabled in development builds.
        #else
        pendingFeedURL = appcastURL
        updaterController.checkForUpdates(nil)
        #endif
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        pendingFeedURL?.absoluteString
    }
}
