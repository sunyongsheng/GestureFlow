import AppKit
import SwiftUI

/// Owns the shared settings `SettingsViewModel` and attaches lifecycle handling to the
/// settings `WindowGroup` host window (via `SettingsWindowLifecycleObserver`).
final class SettingsWindowCoordinator: ObservableObject {
    var onSettingsDidAppear: () -> Void
    var onLastSettingsWindowDidClose: () -> Void

    @Published private(set) var viewModel: SettingsViewModel?
    private let attachedSettingsWindowTable = NSHashTable<NSWindow>.weakObjects()
    private let lifecycleCoordinator: SettingsWindowLifecycleCoordinator

    var attachedSettingsWindows: [NSWindow] {
        attachedSettingsWindowTable.allObjects
    }

    init(notificationCenter: NotificationCenter = .default) {
        self.onSettingsDidAppear = {}
        self.onLastSettingsWindowDidClose = {}
        self.lifecycleCoordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: {},
            onLastSettingsWindowDidClose: {}
        )
        self.lifecycleCoordinator.updateCallbacks(
            onSettingsDidAppear: { [weak self] in self?.onSettingsDidAppear() },
            onLastSettingsWindowDidClose: { [weak self] in self?.onLastSettingsWindowDidClose() }
        )
    }

    func install(viewModel: SettingsViewModel) {
        if self.viewModel == nil {
            self.viewModel = viewModel
        }
    }

    func attachSettingsWindow(_ window: NSWindow?) {
        guard let window else { return }

        window.identifier = NSUserInterfaceItemIdentifier(SettingsWindowSceneIDs.settings)
        attachedSettingsWindowTable.add(window)
        lifecycleCoordinator.attach(to: window)
    }
}
