import AppKit
import SwiftUI

final class SettingsSceneBridge: ObservableObject {
    var onSettingsDidAppear: () -> Void
    var onLastSettingsWindowDidClose: () -> Void

    @Published private(set) var viewModel: SettingsViewModel?
    private let notificationCenter: NotificationCenter
    private let lifecycleCoordinator: SettingsWindowLifecycleCoordinator
    private var presentationObservers: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = .default,
        onSettingsDidAppear: @escaping () -> Void = {},
        onLastSettingsWindowDidClose: @escaping () -> Void = {}
    ) {
        self.notificationCenter = notificationCenter
        self.onSettingsDidAppear = onSettingsDidAppear
        self.onLastSettingsWindowDidClose = onLastSettingsWindowDidClose
        self.lifecycleCoordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: {},
            onLastSettingsWindowDidClose: {}
        )
        self.lifecycleCoordinator.updateCallbacks(
            onSettingsDidAppear: { [weak self] in self?.onSettingsDidAppear() },
            onLastSettingsWindowDidClose: { [weak self] in self?.onLastSettingsWindowDidClose() }
        )
        installPresentationObservers()
    }

    deinit {
        presentationObservers.forEach(notificationCenter.removeObserver)
    }

    func install(viewModel: SettingsViewModel) {
        if self.viewModel == nil {
            self.viewModel = viewModel
        }
    }

    func handleSettingsDidAppear() {
        onSettingsDidAppear()
    }

    func handleLastSettingsWindowDidClose() {
        onLastSettingsWindowDidClose()
    }

    func attachSettingsWindow(_ window: NSWindow?) {
        lifecycleCoordinator.attach(to: window)
    }

    private func installPresentationObservers() {
        let notificationNames: [Notification.Name] = [
            NSWindow.didBecomeMainNotification,
            NSWindow.didBecomeKeyNotification
        ]

        presentationObservers = notificationNames.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                self?.handlePotentialSettingsWindow(notification, eventName: name.rawValue)
            }
        }
    }

    private func handlePotentialSettingsWindow(_ notification: Notification, eventName: String) {
        guard let window = notification.object as? NSWindow else { return }
        let looksLikeSettingsWindow = Self.looksLikeSettingsWindow(window)
        guard looksLikeSettingsWindow else { return }
        attachSettingsWindow(window)
    }

    private static func looksLikeSettingsWindow(_ window: NSWindow) -> Bool {
        if let identifier = window.identifier?.rawValue,
           identifier.localizedCaseInsensitiveContains("settings") {
            return true
        }

        return window.title.localizedCaseInsensitiveContains("settings")
    }
}
