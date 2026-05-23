import AppKit

enum SettingsWindowFrontmostPresenter {
    typealias ActivateApplication = () -> Void

    static func activateExistingOrOpen(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        openWindow: () -> Void,
        application: NSApplication = .shared,
        activateApplication: @escaping ActivateApplication = {
            NSApp.activate(ignoringOtherApps: true)
        }
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
    }

    static func activateExistingOrOpen(
        openWindow: () -> Void,
        windows: [NSWindow],
        attachedWindowIDs: Set<ObjectIdentifier> = [],
        activateApplication: @escaping ActivateApplication = {
            NSApp.activate(ignoringOtherApps: true)
        }
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
        activateApplication: @escaping ActivateApplication = {
            NSApp.activate(ignoringOtherApps: true)
        }
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
        activateApplication: @escaping ActivateApplication = {
            NSApp.activate(ignoringOtherApps: true)
        }
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

        if targetWindow.isMiniaturized {
            targetWindow.deminiaturize(nil)
        }

        targetWindow.makeKeyAndOrderFront(nil)
        activateApplication()
        return true
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
