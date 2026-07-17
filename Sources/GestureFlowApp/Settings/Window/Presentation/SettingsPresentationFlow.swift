import AppKit

enum SettingsPresentationSource {
    case launch
    case menuBar
}

/// Single orchestration entry for settings-window presentation paths.
///
/// Paths stay distinct (silent login / cold-launch / menu-bar), but all decisions
/// and sequencing live here instead of being scattered across AppDelegate,
/// GestureFlowApplication, and SettingsWindowDependencies.
final class SettingsPresentationFlow {
    private let coordinator: SettingsWindowCoordinator
    private let opener: SettingsWindowOpener
    private let presentationController: AppPresentationController
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let dismissAutoOpenedWindows: () -> Void

    init(
        coordinator: SettingsWindowCoordinator,
        opener: SettingsWindowOpener,
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) },
        dismissAutoOpenedWindows: @escaping () -> Void = {
            SettingsWindowFrontmostPresenter.closeAllSettingsWindows()
        }
    ) {
        self.coordinator = coordinator
        self.opener = opener
        self.presentationController = presentationController
        self.scheduleOnMain = scheduleOnMain
        self.dismissAutoOpenedWindows = dismissAutoOpenedWindows
    }

    static func shouldPresentSettingsOnLaunch(
        detector: LaunchReasonDetecting = LaunchReasonDetector()
    ) -> Bool {
        !detector.wasLaunchedAtLogin
    }

    func present(viewModel: SettingsViewModel, source: SettingsPresentationSource) {
        switch source {
        case .launch:
            presentOnLaunch(viewModel: viewModel)
        case .menuBar:
            presentFromMenuBar(viewModel: viewModel)
        }
    }

    /// Cold start: WindowGroup creates the initial window; only promote policy.
    func presentOnLaunch(viewModel: SettingsViewModel) {
        presentationController.cancelPendingAccessoryFallbackIfNeeded()
        coordinator.install(viewModel: viewModel)
        scheduleOnMain { [presentationController] in
            presentationController.prepareToShowSettings()
        }
    }

    /// Menu bar / Cmd+, : promote, open, then reclaim key focus when a window
    /// already exists. New windows claim once from `onSettingsDidAppear`.
    func presentFromMenuBar(viewModel: SettingsViewModel) {
        presentationController.cancelPendingAccessoryFallbackIfNeeded()
        coordinator.install(viewModel: viewModel)
        scheduleOnMain { [presentationController, opener, coordinator] in
            presentationController.prepareToShowSettings()
            _ = opener.openSettingsWindow()
            // Reopen: appear does not re-fire, so claim here.
            // First open: wait for attach → `onSettingsDidAppear` claim (avoids a
            // no-op claim generation that races the appear path).
            if SettingsWindowFrontmostPresenter.hasSettingsWindow(coordinator: coordinator) {
                SettingsWindowFrontmostPresenter.beginKeyFocusClaim(coordinator: coordinator)
            }
        }
    }

    /// Login-item launch: keep accessory shell and close any auto-created window.
    func dismissAutoOpenedWindowsForSilentLaunch() {
        scheduleOnMain { [dismissAutoOpenedWindows] in
            dismissAutoOpenedWindows()
        }
    }
}
