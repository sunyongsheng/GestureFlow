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
        self.coordinator.onSettingsDidAppear = { [weak presentationController] in
            presentationController?.handleSettingsDidAppear()
        }
        self.coordinator.onLastSettingsWindowDidClose = { [weak presentationController] in
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
            scheduleOnMain {
                _ = opener.openSettingsWindow()
                presentationController.prepareToShowSettings()
            }
        }
    }
}
