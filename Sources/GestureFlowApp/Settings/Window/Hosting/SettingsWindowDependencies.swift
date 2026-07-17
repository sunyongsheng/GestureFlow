/// Shared settings window wiring for the SwiftUI `WindowGroup` host and AppKit coordinators.
///
/// - `coordinator`: view model + window lifecycle callbacks
/// - `opener`: status bar / AppKit → same path as Cmd+, (`openWindow`)
/// - `presentationController`: accessory ↔ regular activation policy
final class SettingsWindowDependencies {
    static let shared = SettingsWindowDependencies()

    let coordinator: SettingsWindowCoordinator
    let opener: SettingsWindowOpener
    let presentationController: AppPresentationController

    init(
        coordinator: SettingsWindowCoordinator = SettingsWindowCoordinator(),
        opener: SettingsWindowOpener = SettingsWindowOpener(),
        presentationController: AppPresentationController = AppPresentationController()
    ) {
        self.coordinator = coordinator
        self.opener = opener
        self.presentationController = presentationController
        self.coordinator.onSettingsDidAppear = { [weak presentationController, weak coordinator] in
            presentationController?.handleSettingsDidAppear()
            // WindowGroup creation is async relative to `openWindow`; claim key focus
            // only after the host window has attached.
            guard let coordinator else { return }
            SettingsWindowFocusClaim.begin(coordinator: coordinator)
        }
        self.coordinator.onLastSettingsWindowDidClose = { [weak presentationController] in
            SettingsWindowFocusClaim.cancel()
            presentationController?.handleLastSettingsWindowDidClose()
        }
    }

    func presentSettings(
        viewModel: SettingsViewModel,
        source: SettingsPresentationSource,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) {
        Self.presentSettings(
            viewModel: viewModel,
            source: source,
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: scheduleOnMain
        )
    }

    static func presentSettings(
        viewModel: SettingsViewModel,
        source: SettingsPresentationSource,
        coordinator: SettingsWindowCoordinator,
        opener: SettingsWindowOpener,
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) {
        presentationController.cancelPendingAccessoryFallbackIfNeeded()
        coordinator.install(viewModel: viewModel)

        switch source {
        case .launch:
            // `WindowGroup` creates the initial window; only promote activation policy.
            scheduleOnMain {
                presentationController.prepareToShowSettings()
            }
        case .menuBar:
            // 1) Become a regular app so the window can take key focus.
            // 2) Open / reopen the settings scene.
            // 3) Start a focus claim that retries against apps (e.g. Electron)
            //    which keep activation after the status-item menu dismisses.
            scheduleOnMain {
                presentationController.prepareToShowSettings()
                _ = opener.openSettingsWindow()
                SettingsWindowFocusClaim.begin(coordinator: coordinator)
            }
        }
    }
}
