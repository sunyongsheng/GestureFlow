import AppKit

final class AppPresentationController {
    enum State: Equatable {
        case accessoryBackground
        case promotingToForeground
        case foregroundSettingsVisible
        case returningToAccessory
    }

    private let application: NSApplication
    private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool
    private let scheduleOnMain: (@escaping () -> Void) -> Void

    private var pendingAccessoryFallbackToken = UUID()
    private(set) var state: State = .accessoryBackground

    init(
        application: NSApplication = .shared,
        setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Bool = { NSApp.setActivationPolicy($0) },
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.application = application
        self.setActivationPolicy = setActivationPolicy
        self.scheduleOnMain = scheduleOnMain
    }

    /// Promotes to `.regular` so the settings window can become key.
    ///
    /// Does not activate the app — activation is owned by
    /// `SettingsWindowFrontmostPresenter` focus claim so menu-bar opens do not
    /// stack SkyLight / `NSApp.activate` multiple times.
    func prepareToShowSettings() {
        switch state {
        case .accessoryBackground:
            _ = setActivationPolicy(.regular)
            state = .promotingToForeground
        case .returningToAccessory:
            // Policy is still `.regular` until the cancelled fallback runs.
            state = .promotingToForeground
        case .promotingToForeground, .foregroundSettingsVisible:
            break
        }
    }

    func handleSettingsDidAppear() {
        guard state != .accessoryBackground else { return }
        pendingAccessoryFallbackToken = UUID()
        state = .foregroundSettingsVisible
    }

    func handleLastSettingsWindowDidClose() {
        state = .returningToAccessory
        let token = UUID()
        pendingAccessoryFallbackToken = token

        scheduleOnMain { [weak self] in
            guard let self else { return }
            guard self.pendingAccessoryFallbackToken == token else { return }
            guard self.state == .returningToAccessory else { return }

            _ = self.application
            _ = self.setActivationPolicy(.accessory)
            self.state = .accessoryBackground
        }
    }

    func cancelPendingAccessoryFallbackIfNeeded() {
        pendingAccessoryFallbackToken = UUID()
    }
}
