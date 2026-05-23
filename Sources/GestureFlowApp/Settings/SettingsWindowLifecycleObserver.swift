import AppKit
import SwiftUI

final class SettingsWindowLifecycleCoordinator {
    private let notificationCenter: NotificationCenter
    private let framePersistence: SettingsWindowFramePersistence
    private var onSettingsDidAppear: () -> Void
    private var onLastSettingsWindowDidClose: () -> Void

    private weak var observedWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var frameObservers: [NSObjectProtocol] = []
    private var configuredWindowIDs: Set<ObjectIdentifier> = []
    private var isApplyingPersistedFrame = false

    init(
        notificationCenter: NotificationCenter = .default,
        framePersistence: SettingsWindowFramePersistence = SettingsWindowFramePersistence(),
        onSettingsDidAppear: @escaping () -> Void,
        onLastSettingsWindowDidClose: @escaping () -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.framePersistence = framePersistence
        self.onSettingsDidAppear = onSettingsDidAppear
        self.onLastSettingsWindowDidClose = onLastSettingsWindowDidClose
    }

    deinit {
        removeCloseObserver()
    }

    func attach(to window: NSWindow?) {
        guard let window else {
            removeCloseObserver()
            observedWindow = nil
            return
        }

        let isNewWindow = observedWindow !== window
        if isNewWindow {
            removeCloseObserver()
            observedWindow = window
            closeObserver = notificationCenter.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: nil
            ) { [weak self, weak window] _ in
                guard let self, let window else { return }
                self.handleObservedWindowWillClose(window)
            }
        }

        let windowID = ObjectIdentifier(window)
        if configuredWindowIDs.contains(windowID) == false {
            configureWindowAppearance(window)
            configuredWindowIDs.insert(windowID)
        }

        if isNewWindow {
            onSettingsDidAppear()
        }
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
        persistWindowFrame(window)
        removeCloseObserver()
        removeFrameObservers()
        configuredWindowIDs.remove(ObjectIdentifier(window))
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
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        // Avoid assigning an empty NSToolbar — it has no delegate and can crash during layout.
        window.toolbar = nil
        window.minSize = NSSize(
            width: SettingsWindowMetrics.minimumContentSize.width,
            height: SettingsWindowMetrics.minimumContentSize.height
        )
        installFrameObservers(for: window)
        restoreWindowFrame(window)
    }

    private func restoreWindowFrame(_ window: NSWindow) {
        isApplyingPersistedFrame = true
        defer { isApplyingPersistedFrame = false }

        if framePersistence.restoreFrame(for: window) == false {
            window.setContentSize(
                NSSize(
                    width: SettingsWindowMetrics.defaultContentSize.width,
                    height: SettingsWindowMetrics.defaultContentSize.height
                )
            )
        }
    }

    private func installFrameObservers(for window: NSWindow) {
        guard frameObservers.isEmpty else { return }

        frameObservers = [
            notificationCenter.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let self, let window else { return }
                self.persistWindowFrameIfNeeded(window)
            },
            notificationCenter.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let self, let window else { return }
                self.persistWindowFrameIfNeeded(window)
            }
        ]
    }

    private func removeFrameObservers() {
        for observer in frameObservers {
            notificationCenter.removeObserver(observer)
        }
        frameObservers = []
    }

    private func persistWindowFrameIfNeeded(_ window: NSWindow) {
        guard isApplyingPersistedFrame == false else { return }
        persistWindowFrame(window)
    }

    private func persistWindowFrame(_ window: NSWindow) {
        framePersistence.save(windowFrame: window.frame)
    }
}

struct SettingsWindowLifecycleObserver: NSViewRepresentable {
    let coordinator: SettingsWindowCoordinator

    func makeNSView(context: Context) -> SettingsWindowLifecycleTrackingView {
        let view = SettingsWindowLifecycleTrackingView()
        view.onWindowChange = { window in
            coordinator.attachSettingsWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: SettingsWindowLifecycleTrackingView, context: Context) {
        if let window = nsView.window {
            coordinator.attachSettingsWindow(window)
        }
    }
}

final class SettingsWindowLifecycleTrackingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
