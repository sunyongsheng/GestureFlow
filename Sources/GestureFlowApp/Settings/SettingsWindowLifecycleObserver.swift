import AppKit
import SwiftUI

final class SettingsWindowLifecycleCoordinator {
    private let notificationCenter: NotificationCenter
    private var onSettingsDidAppear: () -> Void
    private var onLastSettingsWindowDidClose: () -> Void

    private weak var observedWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        onSettingsDidAppear: @escaping () -> Void,
        onLastSettingsWindowDidClose: @escaping () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.onSettingsDidAppear = onSettingsDidAppear
        self.onLastSettingsWindowDidClose = onLastSettingsWindowDidClose
    }

    deinit {
        removeCloseObserver()
    }

    func attach(to window: NSWindow?) {
        guard observedWindow !== window else { return }

        removeCloseObserver()
        observedWindow = window

        guard let window else { return }

        configureWindowAppearance(window)

        closeObserver = notificationCenter.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: nil
        ) { [weak self, weak window] _ in
            guard let self, let window else { return }
            self.handleObservedWindowWillClose(window)
        }

        onSettingsDidAppear()
    }

    func updateCallbacks(
        onSettingsDidAppear: @escaping () -> Void,
        onLastSettingsWindowDidClose: @escaping () -> Void
    ) {
        self.onSettingsDidAppear = onSettingsDidAppear
        self.onLastSettingsWindowDidClose = onLastSettingsWindowDidClose
    }

    private func handleObservedWindowWillClose(_ window: NSWindow) {
        guard observedWindow === window else { return }
        removeCloseObserver()
        observedWindow = nil
        onLastSettingsWindowDidClose()
    }

    private func removeCloseObserver() {
        if let closeObserver {
            notificationCenter.removeObserver(closeObserver)
            self.closeObserver = nil
        }
    }

    private func configureWindowAppearance(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
    }
}

struct SettingsWindowLifecycleObserver: NSViewRepresentable {
    let bridge: SettingsSceneBridge

    func makeNSView(context: Context) -> SettingsWindowLifecycleTrackingView {
        let view = SettingsWindowLifecycleTrackingView()
        view.onWindowChange = { window in
            bridge.attachSettingsWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: SettingsWindowLifecycleTrackingView, context: Context) {
        bridge.attachSettingsWindow(nsView.window)
    }
}

final class SettingsWindowLifecycleTrackingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
