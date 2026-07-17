import Foundation

/// Shared settings window wiring for the SwiftUI `WindowGroup` host and AppKit coordinators.
///
/// - `coordinator`: view model + window lifecycle callbacks
/// - `opener`: status bar / AppKit → same path as Cmd+, (`openWindow`)
/// - `presentationController`: accessory ↔ regular activation policy
/// - `presentationFlow`: launch / menu-bar / silent-launch orchestration
final class SettingsWindowDependencies {
    static let shared = SettingsWindowDependencies()

    let coordinator: SettingsWindowCoordinator
    let opener: SettingsWindowOpener
    let presentationController: AppPresentationController
    let presentationFlow: SettingsPresentationFlow

    init(
        coordinator: SettingsWindowCoordinator = SettingsWindowCoordinator(),
        opener: SettingsWindowOpener = SettingsWindowOpener(),
        presentationController: AppPresentationController = AppPresentationController(),
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.coordinator = coordinator
        self.opener = opener
        self.presentationController = presentationController
        self.presentationFlow = SettingsPresentationFlow(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: scheduleOnMain
        )
        self.coordinator.onSettingsDidAppear = { [weak presentationController, weak coordinator] in
            presentationController?.handleSettingsDidAppear()
            // WindowGroup creation is async relative to `openWindow`; claim key focus
            // only after the host window has attached.
            guard let coordinator else { return }
            SettingsWindowFrontmostPresenter.beginKeyFocusClaim(coordinator: coordinator)
        }
        self.coordinator.onLastSettingsWindowDidClose = { [weak presentationController] in
            SettingsWindowFrontmostPresenter.cancelKeyFocusClaim()
            presentationController?.handleLastSettingsWindowDidClose()
        }
    }

    func presentSettings(
        viewModel: SettingsViewModel,
        source: SettingsPresentationSource
    ) {
        presentationFlow.present(viewModel: viewModel, source: source)
    }

    static func presentSettings(
        viewModel: SettingsViewModel,
        source: SettingsPresentationSource,
        coordinator: SettingsWindowCoordinator,
        opener: SettingsWindowOpener,
        presentationController: AppPresentationController,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void
    ) {
        SettingsPresentationFlow(
            coordinator: coordinator,
            opener: opener,
            presentationController: presentationController,
            scheduleOnMain: scheduleOnMain
        ).present(viewModel: viewModel, source: source)
    }
}
