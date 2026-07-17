import AppKit

enum SettingsWindowFrontmostPresenter {
    typealias ActivateApplication = () -> Void

    static func activateExistingOrOpen(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        openWindow: () -> Void,
        application: NSApplication = .shared,
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) {
        let windows = mergedSettingsWindows(
            coordinator: coordinator,
            application: application
        )
        let attachedWindowIDs = attachedWindowIDs(for: coordinator)

        if activateExistingSettingsWindow(
            windows: windows,
            attachedWindowIDs: attachedWindowIDs,
            activateApplication: activateApplication
        ) {
            return
        }

        openWindow()
        // SwiftUI creates the WindowGroup asynchronously; focus is claimed from
        // `onSettingsDidAppear` / deferred `claimFrontmostSettingsWindow`.
    }

    static func activateExistingOrOpen(
        openWindow: () -> Void,
        windows: [NSWindow],
        attachedWindowIDs: Set<ObjectIdentifier> = [],
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) {
        if activateExistingSettingsWindow(
            windows: windows,
            attachedWindowIDs: attachedWindowIDs,
            activateApplication: activateApplication
        ) {
            return
        }

        openWindow()
    }

    @discardableResult
    static func activateExistingSettingsWindow(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        application: NSApplication = .shared,
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) -> Bool {
        activateExistingSettingsWindow(
            windows: mergedSettingsWindows(
                coordinator: coordinator,
                application: application
            ),
            attachedWindowIDs: attachedWindowIDs(for: coordinator),
            activateApplication: activateApplication
        )
    }

    @discardableResult
    static func activateExistingSettingsWindow(
        windows: [NSWindow],
        attachedWindowIDs: Set<ObjectIdentifier> = [],
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) -> Bool {
        let settingsWindows = windows.filter { window in
            isSettingsWindow(window)
                || attachedWindowIDs.contains(ObjectIdentifier(window))
        }
        guard let targetWindow = settingsWindows.first(where: \.isVisible) ?? settingsWindows.first else {
            return false
        }

        for window in settingsWindows where window !== targetWindow {
            window.close()
        }

        bringToFront(window: targetWindow, activateApplication: activateApplication)
        return true
    }

    /// Reclaim key focus after SwiftUI finishes creating/showing the settings window.
    @discardableResult
    static func claimFrontmostSettingsWindow(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        application: NSApplication = .shared,
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) -> Bool {
        activateExistingSettingsWindow(
            coordinator: coordinator,
            application: application,
            activateApplication: activateApplication
        )
    }

    static func closeAllSettingsWindows(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        application: NSApplication = .shared
    ) {
        closeAllSettingsWindows(
            windows: mergedSettingsWindows(
                coordinator: coordinator,
                application: application
            ),
            attachedWindowIDs: attachedWindowIDs(for: coordinator)
        )
    }

    static func closeAllSettingsWindows(
        windows: [NSWindow],
        attachedWindowIDs: Set<ObjectIdentifier> = []
    ) {
        for window in windows where isSettingsWindow(window)
            || attachedWindowIDs.contains(ObjectIdentifier(window))
        {
            window.close()
        }
    }

    static func bringToFront(
        window: NSWindow,
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        // Status-item dismissal often leaves another app active; `orderFrontRegardless`
        // is required for LSUIElement / accessory shells to surface the window.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        activateApplication()
    }

    private static func activateCurrentApplication() {
        NSApp.activate()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    private static func attachedWindowIDs(
        for coordinator: SettingsWindowCoordinator
    ) -> Set<ObjectIdentifier> {
        Set(coordinator.attachedSettingsWindows.map(ObjectIdentifier.init(_:)))
    }

    private static func mergedSettingsWindows(
        coordinator: SettingsWindowCoordinator,
        application: NSApplication
    ) -> [NSWindow] {
        var seen = Set<ObjectIdentifier>()
        var merged: [NSWindow] = []

        for window in coordinator.attachedSettingsWindows + application.windows {
            let id = ObjectIdentifier(window)
            guard seen.insert(id).inserted else { continue }
            merged.append(window)
        }

        return merged
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == SettingsWindowSceneIDs.settings
    }
}
