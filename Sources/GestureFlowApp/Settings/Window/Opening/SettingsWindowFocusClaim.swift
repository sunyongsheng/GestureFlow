import AppKit

/// Reclaims key focus for the settings window after status-item presentation.
///
/// Native apps (e.g. Xcode) usually yield activation cleanly when the status menu
/// closes. Electron shells (e.g. Cursor) often keep being the active app even
/// after our window is ordered front via `orderFrontRegardless`, leaving the
/// settings window visible but not key. Retrying after we become active — and
/// once more shortly after — closes that race.
enum SettingsWindowFocusClaim {
    private static let retryDelays: [TimeInterval] = [0.05, 0.12, 0.25]

    private static var becomeActiveObserver: NSObjectProtocol?
    private static var claimGeneration = UUID()

    static func begin(
        coordinator: SettingsWindowCoordinator,
        notificationCenter: NotificationCenter = .default,
        scheduleAfter: @escaping (TimeInterval, @escaping () -> Void) -> Void = {
            DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1)
        },
        claim: @escaping (SettingsWindowCoordinator) -> Bool = {
            SettingsWindowFrontmostPresenter.claimFrontmostSettingsWindow(coordinator: $0)
        },
        isApplicationActive: @escaping () -> Bool = { NSApp.isActive },
        hasKeySettingsWindow: @escaping (SettingsWindowCoordinator) -> Bool = hasKeySettingsWindow(in:)
    ) {
        let generation = UUID()
        claimGeneration = generation
        removeBecomeActiveObserver(notificationCenter: notificationCenter)

        _ = claim(coordinator)
        if isApplicationActive(), hasKeySettingsWindow(coordinator) {
            return
        }

        becomeActiveObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard claimGeneration == generation else { return }
            _ = claim(coordinator)
            if hasKeySettingsWindow(coordinator) {
                removeBecomeActiveObserver(notificationCenter: notificationCenter)
            }
        }

        for delay in retryDelays {
            scheduleAfter(delay) {
                guard claimGeneration == generation else { return }
                _ = claim(coordinator)
                if isApplicationActive(), hasKeySettingsWindow(coordinator) {
                    removeBecomeActiveObserver(notificationCenter: notificationCenter)
                }
            }
        }

        scheduleAfter((retryDelays.last ?? 0) + 0.05) {
            guard claimGeneration == generation else { return }
            removeBecomeActiveObserver(notificationCenter: notificationCenter)
        }
    }

    static func cancel(notificationCenter: NotificationCenter = .default) {
        claimGeneration = UUID()
        removeBecomeActiveObserver(notificationCenter: notificationCenter)
    }

    private static func removeBecomeActiveObserver(
        notificationCenter: NotificationCenter
    ) {
        if let becomeActiveObserver {
            notificationCenter.removeObserver(becomeActiveObserver)
            self.becomeActiveObserver = nil
        }
    }

    private static func hasKeySettingsWindow(
        in coordinator: SettingsWindowCoordinator
    ) -> Bool {
        coordinator.attachedSettingsWindows.contains(where: \.isKeyWindow)
            || NSApp.windows.contains { window in
                window.identifier?.rawValue == SettingsWindowSceneIDs.settings
                    && window.isKeyWindow
            }
    }
}
