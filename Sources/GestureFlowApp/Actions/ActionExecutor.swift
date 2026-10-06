import AppKit
import CoreGraphics
import Foundation
import GestureFlowCore

protocol ActionExecuting {
    func execute(
        _ action: GestureAction,
        targetProcessIdentifier: pid_t?,
        targetBundleIdentifier: String?,
        gestureOriginScreenPoint: CGPoint?
    ) throws
}

enum ActionExecutionError: Error, Equatable {
    case keyboardEventCreationFailed(keyCode: UInt16, isKeyDown: Bool)
    case applicationNotFound(bundleIdentifier: String)
    case applicationOpenFailed(bundleIdentifier: String)
    case urlOpenFailed(URL)
    case systemCommandFailed(executableURL: URL, terminationStatus: Int32)
}

extension ActionExecutionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .keyboardEventCreationFailed(keyCode, isKeyDown):
            let phase = isKeyDown ? "down" : "up"
            return "Failed to create key \(phase) event for key code \(keyCode)"
        case let .applicationNotFound(bundleIdentifier):
            return "Application not found: \(bundleIdentifier)"
        case let .applicationOpenFailed(bundleIdentifier):
            return "Failed to open application: \(bundleIdentifier)"
        case let .urlOpenFailed(url):
            return "Failed to open URL: \(url.absoluteString)"
        case let .systemCommandFailed(executableURL, terminationStatus):
            return "System command failed: \(executableURL.path) exited with \(terminationStatus)"
        }
    }
}

struct KeyboardEventPost: Equatable {
    var keyCode: UInt16
    var flags: CGEventFlags
    var isKeyDown: Bool
}

protocol KeyboardEventPosting {
    func post(_ event: KeyboardEventPost, targetProcessIdentifier: pid_t?) throws
}

protocol WorkspaceOpening {
    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
    func openApplication(at applicationURL: URL) throws
    func open(_ url: URL) -> Bool
}

protocol SystemCommandRunning {
    func run(executableURL: URL, arguments: [String]) throws -> Int32
}

protocol ApplicationActivating {
    func activateCurrentApplication()
}

protocol ProcessActivating {
    @discardableResult
    func activate(processIdentifier: pid_t, bundleIdentifier: String?) -> Bool
}

struct FrontmostApplicationInfo: Equatable {
    var processIdentifier: pid_t
    var bundleIdentifier: String?
}

protocol FrontmostApplicationQuerying {
    func frontmostApplication() -> FrontmostApplicationInfo?
}

protocol TargetWindowRaising {
    func raiseWindow(at screenPoint: CGPoint, for processIdentifier: pid_t)
}

protocol TargetActivationWaiting {
    /// Calls `deliver` on the main queue once the target becomes the active app, or when waiting times out.
    func waitForActivation(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        then deliver: @escaping () -> Void
    )
}

final class ActionExecutor: ActionExecuting {
    private let keyEventPoster: KeyboardEventPosting
    private let workspaceOpener: WorkspaceOpening
    private let systemCommandRunner: SystemCommandRunning
    private let applicationActivator: ApplicationActivating
    private let processActivator: ProcessActivating
    private let frontmostQuery: FrontmostApplicationQuerying
    private let windowRaiser: TargetWindowRaising
    private let activationWaiter: TargetActivationWaiting
    private let currentProcessIdentifier: Int32

    init(
        keyEventPoster: KeyboardEventPosting = CGKeyboardEventPoster(),
        workspaceOpener: WorkspaceOpening = NSWorkspaceOpener(),
        systemCommandRunner: SystemCommandRunning = ProcessSystemCommandRunner(),
        applicationActivator: ApplicationActivating = NSApplicationActivator(),
        processActivator: ProcessActivating = NSProcessActivator(),
        frontmostQuery: FrontmostApplicationQuerying = NSFrontmostApplicationQuery(),
        windowRaiser: TargetWindowRaising = AXTargetWindowRaiser(),
        activationWaiter: TargetActivationWaiting = WorkspaceActivationWaiter(),
        currentProcessIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) {
        self.keyEventPoster = keyEventPoster
        self.workspaceOpener = workspaceOpener
        self.systemCommandRunner = systemCommandRunner
        self.applicationActivator = applicationActivator
        self.processActivator = processActivator
        self.frontmostQuery = frontmostQuery
        self.windowRaiser = windowRaiser
        self.activationWaiter = activationWaiter
        self.currentProcessIdentifier = currentProcessIdentifier
    }

    func execute(
        _ action: GestureAction,
        targetProcessIdentifier: pid_t? = nil,
        targetBundleIdentifier: String? = nil,
        gestureOriginScreenPoint: CGPoint? = nil
    ) throws {
        switch action {
        case let .keyboardShortcut(shortcut):
            try executeKeyboardShortcut(
                shortcut,
                targetProcessIdentifier: targetProcessIdentifier,
                targetBundleIdentifier: targetBundleIdentifier,
                gestureOriginScreenPoint: gestureOriginScreenPoint
            )
        case let .openApplication(application):
            try openApplication(application)
        case let .openURL(urlAction):
            try openURL(urlAction)
        case let .systemCommand(command):
            try executeSystemCommand(command)
        }
    }

    private func executeKeyboardShortcut(
        _ shortcut: KeyboardShortcutAction,
        targetProcessIdentifier: pid_t?,
        targetBundleIdentifier: String?,
        gestureOriginScreenPoint: CGPoint?
    ) throws {
        let flags = shortcut.modifiers.cgEventFlags

        guard let targetProcessIdentifier else {
            try postKeyboardShortcut(shortcut, flags: flags, targetProcessIdentifier: nil)
            return
        }

        if targetProcessIdentifier == currentProcessIdentifier {
            applicationActivator.activateCurrentApplication()
            try postKeyboardShortcut(
                shortcut,
                flags: flags,
                targetProcessIdentifier: targetProcessIdentifier
            )
            return
        }

        let frontmost = frontmostQuery.frontmostApplication()
        let effectiveTargetPID: pid_t
        let skipActivation: Bool

        if frontmost?.processIdentifier == targetProcessIdentifier {
            effectiveTargetPID = targetProcessIdentifier
            skipActivation = true
        } else if let frontmost,
                  isFrontmostRelatedToTarget(frontmost: frontmost, targetBundleIdentifier: targetBundleIdentifier) {
            effectiveTargetPID = frontmost.processIdentifier
            skipActivation = true
        } else {
            effectiveTargetPID = targetProcessIdentifier
            skipActivation = false
        }

        guard !skipActivation else {
            try postKeyboardShortcut(
                shortcut,
                flags: flags,
                targetProcessIdentifier: effectiveTargetPID
            )
            return
        }

        _ = processActivator.activate(
            processIdentifier: targetProcessIdentifier,
            bundleIdentifier: targetBundleIdentifier
        )
        // Activation lands asynchronously; the window raise and the shortcut need the target active first.
        activationWaiter.waitForActivation(
            processIdentifier: targetProcessIdentifier,
            bundleIdentifier: targetBundleIdentifier
        ) { [self] in
            if let gestureOriginScreenPoint {
                windowRaiser.raiseWindow(
                    at: gestureOriginScreenPoint,
                    for: targetProcessIdentifier
                )
            }
            do {
                try postKeyboardShortcut(
                    shortcut,
                    flags: flags,
                    targetProcessIdentifier: effectiveTargetPID
                )
            } catch {
                print("[GestureFlow] 分发失败 detail=\(error.localizedDescription)")
            }
        }
    }

    private func isFrontmostRelatedToTarget(
        frontmost: FrontmostApplicationInfo,
        targetBundleIdentifier: String?
    ) -> Bool {
        guard let frontmostBundle = frontmost.bundleIdentifier,
              let targetBundle = targetBundleIdentifier else {
            return false
        }
        if frontmostBundle == targetBundle {
            return true
        }
        if let parentOfFrontmost = ApplicationBundleIdentifierSupport.parentBundleIdentifier(
            forHelperBundleIdentifier: frontmostBundle
        ), parentOfFrontmost == targetBundle {
            return true
        }
        return false
    }

    private func postKeyboardShortcut(
        _ shortcut: KeyboardShortcutAction,
        flags: CGEventFlags,
        targetProcessIdentifier: pid_t?
    ) throws {
        try keyEventPoster.post(
            KeyboardEventPost(keyCode: shortcut.keyCode, flags: flags, isKeyDown: true),
            targetProcessIdentifier: targetProcessIdentifier
        )
        try keyEventPoster.post(
            KeyboardEventPost(keyCode: shortcut.keyCode, flags: flags, isKeyDown: false),
            targetProcessIdentifier: targetProcessIdentifier
        )
    }

    private func openApplication(_ action: OpenApplicationAction) throws {
        guard let applicationURL = workspaceOpener.applicationURL(
            forBundleIdentifier: action.bundleIdentifier
        ) else {
            throw ActionExecutionError.applicationNotFound(
                bundleIdentifier: action.bundleIdentifier
            )
        }

        do {
            try workspaceOpener.openApplication(at: applicationURL)
        } catch {
            throw ActionExecutionError.applicationOpenFailed(
                bundleIdentifier: action.bundleIdentifier
            )
        }
    }

    private func openURL(_ action: OpenURLAction) throws {
        guard workspaceOpener.open(action.url) else {
            throw ActionExecutionError.urlOpenFailed(action.url)
        }
    }

    private func executeSystemCommand(_ command: SystemCommandAction) throws {
        switch command {
        case .showDesktop:
            try executeKeyboardShortcut(
                KeyboardShortcutAction(keyCode: 99, modifiers: [.command]),
                targetProcessIdentifier: nil,
                targetBundleIdentifier: nil,
                gestureOriginScreenPoint: nil
            )
        case .lockScreen:
            try runLockScreenCommand()
        }
    }

    private func runLockScreenCommand() throws {
        let executableURL = URL(
            fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        )
        let terminationStatus = try systemCommandRunner.run(
            executableURL: executableURL,
            arguments: ["-suspend"]
        )
        guard terminationStatus == 0 else {
            throw ActionExecutionError.systemCommandFailed(
                executableURL: executableURL,
                terminationStatus: terminationStatus
            )
        }
    }
}

private struct CGKeyboardEventPoster: KeyboardEventPosting {
    func post(_ event: KeyboardEventPost, targetProcessIdentifier: pid_t?) throws {
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        guard let cgEvent = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: event.keyCode,
            keyDown: event.isKeyDown
        ) else {
            throw ActionExecutionError.keyboardEventCreationFailed(
                keyCode: event.keyCode,
                isKeyDown: event.isKeyDown
            )
        }

        cgEvent.flags = event.flags
        if let targetProcessIdentifier {
            cgEvent.postToPid(targetProcessIdentifier)
        } else {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}

private enum ApplicationActivationSupport {
    static let foregroundOptions: NSApplication.ActivationOptions = [.activateAllWindows]

    static func activatableApplication(
        for application: NSRunningApplication
    ) -> NSRunningApplication {
        guard application.activationPolicy != .regular,
              let bundleIdentifier = application.bundleIdentifier else {
            return application
        }

        let candidateBundleIdentifiers = [
            bundleIdentifier,
            ApplicationBundleIdentifierSupport.parentBundleIdentifier(
                forHelperBundleIdentifier: bundleIdentifier
            )
        ].compactMap { $0 }

        for candidateBundleIdentifier in candidateBundleIdentifiers {
            if let regularApplication = NSRunningApplication
                .runningApplications(withBundleIdentifier: candidateBundleIdentifier)
                .first(where: { $0.activationPolicy == .regular })
            {
                return regularApplication
            }
        }

        return application
    }

    @discardableResult
    static func activateTarget(application: NSRunningApplication) -> Bool {
        NSApp.yieldActivation(to: application)
        if let bundleIdentifier = application.bundleIdentifier {
            NSApp.yieldActivation(toApplicationWithBundleIdentifier: bundleIdentifier)
        }
        if application.activate(options: foregroundOptions) {
            return true
        }
        return forceActivate(application)
    }

    @discardableResult
    static func activateTarget(processIdentifier: pid_t) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            return false
        }
        return activateTarget(application: activatableApplication(for: application))
    }

    static func requestActivationViaWorkspace(bundleIdentifier: String) {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
    }

    @discardableResult
    private static func forceActivate(_ application: NSRunningApplication) -> Bool {
        application.activate(options: foregroundOptions.union(.activateIgnoringOtherApps))
    }
}

struct AXTargetWindowRaiser: TargetWindowRaising {
    private let mainScreenHeightProvider: () -> CGFloat

    init(mainScreenHeightProvider: @escaping () -> CGFloat = {
        NSScreen.main?.frame.height ?? 0
    }) {
        self.mainScreenHeightProvider = mainScreenHeightProvider
    }

    /// Raises the topmost interactive window at the given AppKit screen point.
    /// Skips non-interactive overlay windows (e.g. watermark widgets) that may
    /// sit above the real content window.
    func raiseWindow(at screenPoint: CGPoint, for processIdentifier: pid_t) {
        let mainScreenHeight = mainScreenHeightProvider()
        let quartzPoint = CGPoint(x: screenPoint.x, y: mainScreenHeight - screenPoint.y)

        AccessibilityMessaging.applyTimeout()
        let app = AXUIElementCreateApplication(processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            app, kAXWindowsAttribute as CFString, &windowsRef
        ) == .success,
            let windows = windowsRef as? [AXUIElement] else {
            return
        }

        var bestCandidate: AXUIElement?

        for window in windows {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                window, kAXPositionAttribute as CFString, &positionRef
            ) == .success,
                AXUIElementCopyAttributeValue(
                    window, kAXSizeAttribute as CFString, &sizeRef
                ) == .success else {
                continue
            }

            var position = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
                  AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
                continue
            }

            let windowFrame = CGRect(origin: position, size: size)
            guard windowFrame.contains(quartzPoint) else { continue }

            if isInteractiveWindow(window) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return
            }

            if bestCandidate == nil {
                bestCandidate = window
            }
        }

        if let fallback = bestCandidate {
            AXUIElementPerformAction(fallback, kAXRaiseAction as CFString)
        }
    }

    private func isInteractiveWindow(_ window: AXUIElement) -> Bool {
        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            window, kAXSubroleAttribute as CFString, &subroleRef
        ) == .success,
            let subrole = subroleRef as? String,
            subrole == (kAXStandardWindowSubrole as String) {
            return true
        }

        var closeButtonRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            window, kAXCloseButtonAttribute as CFString, &closeButtonRef
        ) == .success {
            return true
        }

        return false
    }
}

private struct NSFrontmostApplicationQuery: FrontmostApplicationQuerying {
    func frontmostApplication() -> FrontmostApplicationInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier
        )
    }
}

private struct NSApplicationActivator: ApplicationActivating {
    func activateCurrentApplication() {
        NSRunningApplication.current.activate(options: ApplicationActivationSupport.foregroundOptions)
    }
}

private struct NSProcessActivator: ProcessActivating {
    @discardableResult
    func activate(processIdentifier: pid_t, bundleIdentifier: String?) -> Bool {
        let didRequestActivation = ApplicationActivationSupport.activateTarget(processIdentifier: processIdentifier)
        // Direct activation is cooperative on macOS 14+ and can be declined for a background agent.
        if let bundleIdentifier {
            ApplicationActivationSupport.requestActivationViaWorkspace(bundleIdentifier: bundleIdentifier)
        }
        return didRequestActivation
    }
}

final class WorkspaceActivationWaiter: TargetActivationWaiting {
    private let notificationCenter: NotificationCenter
    private let timeout: TimeInterval

    init(
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        timeout: TimeInterval = 0.5
    ) {
        self.notificationCenter = notificationCenter
        self.timeout = timeout
    }

    func waitForActivation(
        processIdentifier: pid_t,
        bundleIdentifier: String?,
        then deliver: @escaping () -> Void
    ) {
        // An app that is already active never posts another activation notification.
        if let application = NSRunningApplication(processIdentifier: processIdentifier),
           ApplicationActivationSupport.activatableApplication(for: application).isActive {
            deliver()
            return
        }

        let pending = PendingActivation(notificationCenter: notificationCenter, deliver: deliver)
        pending.observer = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  Self.isActivation(
                      of: application,
                      processIdentifier: processIdentifier,
                      bundleIdentifier: bundleIdentifier
                  ) else {
                return
            }
            pending.finish()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            pending.finish()
        }
    }

    private static func isActivation(
        of application: NSRunningApplication,
        processIdentifier: pid_t,
        bundleIdentifier: String?
    ) -> Bool {
        if application.processIdentifier == processIdentifier {
            return true
        }
        guard let bundleIdentifier, let activatedBundleIdentifier = application.bundleIdentifier else {
            return false
        }
        return activatedBundleIdentifier == bundleIdentifier
            || ApplicationBundleIdentifierSupport.parentBundleIdentifier(
                forHelperBundleIdentifier: activatedBundleIdentifier
            ) == bundleIdentifier
    }
}

private final class PendingActivation: @unchecked Sendable {
    var observer: NSObjectProtocol?
    private let notificationCenter: NotificationCenter
    private var deliver: (() -> Void)?

    init(notificationCenter: NotificationCenter, deliver: @escaping () -> Void) {
        self.notificationCenter = notificationCenter
        self.deliver = deliver
    }

    func finish() {
        guard let deliver else { return }
        self.deliver = nil
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
        deliver()
    }
}

private struct NSWorkspaceOpener: WorkspaceOpening {
    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    func openApplication(at applicationURL: URL) throws {
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

private struct ProcessSystemCommandRunner: SystemCommandRunning {
    func run(executableURL: URL, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

private extension Array where Element == KeyboardModifier {
    var cgEventFlags: CGEventFlags {
        reduce([]) { flags, modifier in
            var flags = flags
            switch modifier {
            case .command:
                flags.insert(.maskCommand)
            case .option:
                flags.insert(.maskAlternate)
            case .control:
                flags.insert(.maskControl)
            case .shift:
                flags.insert(.maskShift)
            }
            return flags
        }
    }
}
