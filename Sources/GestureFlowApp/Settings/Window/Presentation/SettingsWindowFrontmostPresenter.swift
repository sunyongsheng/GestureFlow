import AppKit
import Darwin

enum SettingsWindowFrontmostPresenter {
    typealias ActivateApplication = () -> Void

    // MARK: - App activation

    /// Forces this process frontmost when cooperative `NSApp.activate()` is declined.
    ///
    /// macOS 14+ treats `NSRunningApplication.activate` as cooperative. Electron shells
    /// (e.g. Cursor) often keep frontmost ownership; SkyLight
    /// `_SLPSSetFrontProcessWithOptions` is the reliable LSUIElement self-activation path.
    /// Activation is asynchronous — pair with `beginKeyFocusClaim` / `didBecomeActive`.
    static func activateCurrentApplication() {
        forceFrontProcessForCurrentApplication()
        NSApp.activate()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    // MARK: - Open / front (one-shot)

    /// Orders an existing settings window without force-activating.
    ///
    /// Activation is owned by `beginKeyFocusClaim` so reopen paths do not stack
    /// SkyLight calls while `isActive` is still false asynchronously.
    @discardableResult
    static func orderExistingSettingsWindow(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        application: NSApplication = .shared
    ) -> Bool {
        activateExistingSettingsWindow(
            coordinator: coordinator,
            application: application,
            activateApplication: {}
        )
    }

    static func hasSettingsWindow(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        application: NSApplication = .shared
    ) -> Bool {
        let attachedIDs = attachedWindowIDs(for: coordinator)
        return mergedSettingsWindows(coordinator: coordinator, application: application).contains { window in
            isSettingsWindow(window) || attachedIDs.contains(ObjectIdentifier(window))
        }
    }

    static func activateExistingOrOpen(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        openWindow: () -> Void,
        application: NSApplication = .shared
    ) {
        if orderExistingSettingsWindow(coordinator: coordinator, application: application) {
            return
        }

        openWindow()
        // SwiftUI creates the WindowGroup asynchronously; key focus is claimed via
        // `beginKeyFocusClaim` after the host window attaches.
    }

    static func activateExistingOrOpen(
        openWindow: () -> Void,
        windows: [NSWindow],
        attachedWindowIDs: Set<ObjectIdentifier> = []
    ) {
        if activateExistingSettingsWindow(
            windows: windows,
            attachedWindowIDs: attachedWindowIDs,
            activateApplication: {}
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

    /// One-shot reclaim after SwiftUI finishes creating/showing the settings window.
    ///
    /// Activates only when this app is not already active, so menu-bar / appear /
    /// `didBecomeActive` claims do not stack SkyLight force-activation.
    @discardableResult
    static func claimFrontmostSettingsWindow(
        coordinator: SettingsWindowCoordinator = SettingsWindowDependencies.shared.coordinator,
        application: NSApplication = .shared,
        isApplicationActive: @escaping () -> Bool = { NSApp.isActive },
        activateApplication: @escaping ActivateApplication = activateCurrentApplication
    ) -> Bool {
        activateExistingSettingsWindow(
            coordinator: coordinator,
            application: application,
            activateApplication: {
                guard isApplicationActive() == false else { return }
                activateApplication()
            }
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

        // Force-activate first (SkyLight when cooperative activate is declined), then
        // make key. `orderFrontRegardless` still helps LSUIElement / status-item cases.
        activateApplication()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // MARK: - Key focus claim (event-driven)

    /// Reclaims key focus after status-item presentation.
    ///
    /// Claims once immediately, then once on `didBecomeActive` if we are not yet key.
    /// SkyLight force-activation is asynchronous, so Electron frontmost apps often only
    /// become preempted after that notification — not synchronously in `bringToFront`.
    private static var keyFocusBecomeActiveObserver: NSObjectProtocol?
    private static var keyFocusClaimGeneration = UUID()

    static func beginKeyFocusClaim(
        coordinator: SettingsWindowCoordinator,
        notificationCenter: NotificationCenter = .default,
        claim: @escaping (SettingsWindowCoordinator) -> Bool = {
            claimFrontmostSettingsWindow(coordinator: $0)
        },
        isApplicationActive: @escaping () -> Bool = { NSApp.isActive },
        hasKeySettingsWindow: @escaping (SettingsWindowCoordinator) -> Bool = hasKeySettingsWindow(in:)
    ) {
        let generation = UUID()
        keyFocusClaimGeneration = generation
        removeKeyFocusBecomeActiveObserver(notificationCenter: notificationCenter)

        _ = claim(coordinator)
        if isApplicationActive(), hasKeySettingsWindow(coordinator) {
            return
        }

        keyFocusBecomeActiveObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard keyFocusClaimGeneration == generation else { return }
            _ = claim(coordinator)
            removeKeyFocusBecomeActiveObserver(notificationCenter: notificationCenter)
        }
    }

    static func cancelKeyFocusClaim(notificationCenter: NotificationCenter = .default) {
        keyFocusClaimGeneration = UUID()
        removeKeyFocusBecomeActiveObserver(notificationCenter: notificationCenter)
    }

    // MARK: - Private

    /// `kCurrentProcess` from HIServices (unavailable to Swift as a symbol).
    private static let currentProcessPSN = ProcessSerialNumber(
        highLongOfPSN: 0,
        lowLongOfPSN: 2
    )

    /// User-generated CPS activation request (more likely to preempt another front app).
    private static let cpsUserGenerated: UInt32 = 0x200

    private typealias GetProcessForPIDFn = @convention(c) (
        pid_t,
        UnsafeMutablePointer<ProcessSerialNumber>
    ) -> Int32

    private typealias SLPSSetFrontProcessWithOptionsFn = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        UInt32,
        UInt32
    ) -> Int32

    private static let getProcessForPID: GetProcessForPIDFn? = {
        loadSymbol(
            "GetProcessForPID",
            from: "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        )
    }()

    private static let slpsSetFrontProcessWithOptions: SLPSSetFrontProcessWithOptionsFn? = {
        loadSymbol(
            "_SLPSSetFrontProcessWithOptions",
            from: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        )
    }()

    private static func forceFrontProcessForCurrentApplication() {
        var psn = currentProcessPSN
        if let getProcessForPID {
            var resolved = ProcessSerialNumber()
            if getProcessForPID(ProcessInfo.processInfo.processIdentifier, &resolved) == 0 {
                psn = resolved
            }
        }

        guard let slpsSetFrontProcessWithOptions else { return }
        _ = withUnsafeMutablePointer(to: &psn) { pointer in
            slpsSetFrontProcessWithOptions(pointer, 0, cpsUserGenerated)
        }
    }

    private static func loadSymbol<T>(
        _ name: String,
        from path: String
    ) -> T? {
        guard
            let handle = dlopen(path, RTLD_LAZY),
            let symbol = dlsym(handle, name)
        else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }

    private static func removeKeyFocusBecomeActiveObserver(
        notificationCenter: NotificationCenter
    ) {
        if let keyFocusBecomeActiveObserver {
            notificationCenter.removeObserver(keyFocusBecomeActiveObserver)
            self.keyFocusBecomeActiveObserver = nil
        }
    }

    private static func hasKeySettingsWindow(
        in coordinator: SettingsWindowCoordinator
    ) -> Bool {
        coordinator.attachedSettingsWindows.contains(where: \.isKeyWindow)
            || NSApp.windows.contains { window in
                isSettingsWindow(window) && window.isKeyWindow
            }
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
