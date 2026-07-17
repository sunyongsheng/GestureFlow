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
    private let activateApp: () -> Void
    private let scheduleOnMain: (@escaping () -> Void) -> Void

    private var pendingAccessoryFallbackToken = UUID()
    private(set) var state: State = .accessoryBackground

    init(
        application: NSApplication = .shared,
        setActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Bool = { NSApp.setActivationPolicy($0) },
        activateApp: @escaping () -> Void = {
            NSApp.activate()
            NSRunningApplication.current.activate(options: [.activateAllWindows])
        },
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.application = application
        self.setActivationPolicy = setActivationPolicy
        self.activateApp = activateApp
        self.scheduleOnMain = scheduleOnMain
    }

    func prepareToShowSettings() {
        switch state {
        case .accessoryBackground:
            _ = setActivationPolicy(.regular)
            state = .promotingToForeground
            scheduleDeferredActivationRequest()
        case .returningToAccessory:
            // Policy is still `.regular` until the cancelled fallback runs; re-request
            // activation so a reopen after close can reclaim key focus.
            state = .promotingToForeground
            scheduleDeferredActivationRequest()
        case .promotingToForeground, .foregroundSettingsVisible:
            break
        }
    }

    func handleSettingsDidAppear() {
        guard state != .accessoryBackground else { return }
        pendingAccessoryFallbackToken = UUID()
        state = .foregroundSettingsVisible
        scheduleDeferredActivationRequest()
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

    private func scheduleDeferredActivationRequest() {
        scheduleOnMain { [weak self] in
            guard let self else { return }
            self.scheduleOnMain { [weak self] in
                guard let self else { return }
                guard self.state == .promotingToForeground || self.state == .foregroundSettingsVisible else { return }

                self.activateApp()
            }
        }
    }
}
