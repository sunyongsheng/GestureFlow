import AppKit
import CoreGraphics
import Foundation
import GestureFlowCore

protocol ActionExecuting {
    func execute(
        _ action: GestureAction,
        targetProcessIdentifier: pid_t?,
        targetBundleIdentifier: String?
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

final class ActionExecutor: ActionExecuting {
    private let keyEventPoster: KeyboardEventPosting
    private let workspaceOpener: WorkspaceOpening
    private let systemCommandRunner: SystemCommandRunning
    private let applicationActivator: ApplicationActivating
    private let processActivator: ProcessActivating
    private let currentProcessIdentifier: Int32

    init(
        keyEventPoster: KeyboardEventPosting = CGKeyboardEventPoster(),
        workspaceOpener: WorkspaceOpening = NSWorkspaceOpener(),
        systemCommandRunner: SystemCommandRunning = ProcessSystemCommandRunner(),
        applicationActivator: ApplicationActivating = NSApplicationActivator(),
        processActivator: ProcessActivating = NSProcessActivator(),
        currentProcessIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) {
        self.keyEventPoster = keyEventPoster
        self.workspaceOpener = workspaceOpener
        self.systemCommandRunner = systemCommandRunner
        self.applicationActivator = applicationActivator
        self.processActivator = processActivator
        self.currentProcessIdentifier = currentProcessIdentifier
    }

    func execute(
        _ action: GestureAction,
        targetProcessIdentifier: pid_t? = nil,
        targetBundleIdentifier: String? = nil
    ) throws {
        switch action {
        case let .keyboardShortcut(shortcut):
            try executeKeyboardShortcut(
                shortcut,
                targetProcessIdentifier: targetProcessIdentifier,
                targetBundleIdentifier: targetBundleIdentifier
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
        targetBundleIdentifier: String?
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

        _ = processActivator.activate(
            processIdentifier: targetProcessIdentifier,
            bundleIdentifier: targetBundleIdentifier
        )

        try postKeyboardShortcut(
            shortcut,
            flags: flags,
            targetProcessIdentifier: targetProcessIdentifier
        )
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
                targetBundleIdentifier: nil
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

    @discardableResult
    static func activateTarget(bundleIdentifier: String) -> Bool {
        if let application = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.activationPolicy == .regular }),
            activateTarget(application: application),
            isTargetFrontmost(bundleIdentifier: bundleIdentifier)
        {
            return true
        }

        if activateViaWorkspace(bundleIdentifier: bundleIdentifier),
           isTargetFrontmost(bundleIdentifier: bundleIdentifier)
        {
            return true
        }

        return false
    }

    static func isTargetFrontmost(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier
    }

    @discardableResult
    private static func activateViaWorkspace(bundleIdentifier: String) -> Bool {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        configuration.addsToRecentItems = false

        final class ActivationState: @unchecked Sendable {
            var completed = false
            var error: Error?
        }

        let state = ActivationState()
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
            state.error = error
            state.completed = true
        }

        let deadline = Date().addingTimeInterval(0.5)
        while !state.completed, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return state.completed && state.error == nil
    }

    @discardableResult
    private static func forceActivate(_ application: NSRunningApplication) -> Bool {
        application.activate(options: foregroundOptions.union(.activateIgnoringOtherApps))
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
        _ = ApplicationActivationSupport.activateTarget(processIdentifier: processIdentifier)
        if let bundleIdentifier,
           ApplicationActivationSupport.isTargetFrontmost(bundleIdentifier: bundleIdentifier)
        {
            return true
        }
        guard let bundleIdentifier else {
            return NSRunningApplication(processIdentifier: processIdentifier) != nil
                && NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier
        }
        return ApplicationActivationSupport.activateTarget(bundleIdentifier: bundleIdentifier)
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
