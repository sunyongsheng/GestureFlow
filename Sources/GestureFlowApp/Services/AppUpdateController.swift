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
        #if DEBUG
        return false
        #else
        return updaterController.updater.canCheckForUpdates
        #endif
    }

    func checkForUpdates(appcastURL: URL) {
        pendingFeedURL = appcastURL
        updaterController.checkForUpdates(nil)
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        pendingFeedURL?.absoluteString
    }
}
