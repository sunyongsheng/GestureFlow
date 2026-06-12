import AppKit
import CoreGraphics
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class ActionExecutorTests: XCTestCase {
    func testKeyboardShortcutPostsKeyDownAndKeyUpWithMappedModifiers() throws {
        let keyEventPoster = SpyKeyboardEventPoster()
        let executor = ActionExecutor(keyEventPoster: keyEventPoster)

        try executor.execute(
            .keyboardShortcut(
                KeyboardShortcutAction(
                    keyCode: 12,
                    modifiers: [.command, .shift, .option, .control]
                )
            ),
            targetProcessIdentifier: nil,
            targetBundleIdentifier: nil
        )

        let expectedFlags: CGEventFlags = [
            .maskCommand,
            .maskShift,
            .maskAlternate,
            .maskControl
        ]
        XCTAssertEqual(
            keyEventPoster.events,
            [
                .init(keyCode: 12, flags: expectedFlags, isKeyDown: true),
                .init(keyCode: 12, flags: expectedFlags, isKeyDown: false)
            ]
        )
    }

    func testOpenApplicationResolvesBundleIdentifierAndOpensApplicationURL() throws {
        let workspace = SpyWorkspaceOpener()
        let appURL = URL(fileURLWithPath: "/Applications/Finder.app")
        workspace.applicationURLsByBundleIdentifier["com.apple.finder"] = appURL
        let executor = ActionExecutor(workspaceOpener: workspace)

        try executor.execute(
            .openApplication(
                OpenApplicationAction(bundleIdentifier: "com.apple.finder")
            ),
            targetProcessIdentifier: nil,
            targetBundleIdentifier: nil
        )

        XCTAssertEqual(workspace.openedApplicationURLs, [appURL])
    }

    func testOpenApplicationThrowsWhenBundleIdentifierCannotBeResolved() {
        let workspace = SpyWorkspaceOpener()
        let executor = ActionExecutor(workspaceOpener: workspace)

        XCTAssertThrowsError(
            try executor.execute(
                .openApplication(
                    OpenApplicationAction(bundleIdentifier: "missing.bundle")
                ),
                targetProcessIdentifier: nil,
                targetBundleIdentifier: nil
            )
        ) { error in
            XCTAssertEqual(
                error as? ActionExecutionError,
                .applicationNotFound(bundleIdentifier: "missing.bundle")
            )
        }
    }

    func testOpenURLUsesWorkspaceURLAdapter() throws {
        let workspace = SpyWorkspaceOpener()
        let url = URL(string: "https://example.com")!
        let executor = ActionExecutor(workspaceOpener: workspace)

        try executor.execute(
            .openURL(OpenURLAction(url: url)),
            targetProcessIdentifier: nil,
            targetBundleIdentifier: nil
        )

        XCTAssertEqual(workspace.openedURLs, [url])
    }

    func testKeyboardShortcutPostsToCurrentProcessWhenTargetIsSelf() throws {
        let keyEventPoster = SpyKeyboardEventPoster()
        let applicationActivator = SpyApplicationActivator()
        let currentPID: pid_t = 42
        let executor = ActionExecutor(
            keyEventPoster: keyEventPoster,
            applicationActivator: applicationActivator,
            currentProcessIdentifier: currentPID
        )

        try executor.execute(
            .keyboardShortcut(KeyboardShortcutAction(keyCode: 9, modifiers: [.command])),
            targetProcessIdentifier: currentPID,
            targetBundleIdentifier: nil
        )

        XCTAssertEqual(applicationActivator.activateCount, 1)
        XCTAssertEqual(
            keyEventPoster.postedEvents.map(\.targetProcessIdentifier),
            [currentPID, currentPID]
        )
    }

    func testKeyboardShortcutActivatesTargetProcessBeforePosting() throws {
        let keyEventPoster = SpyKeyboardEventPoster()
        let processActivator = SpyProcessActivator()
        let executor = ActionExecutor(
            keyEventPoster: keyEventPoster,
            processActivator: processActivator
        )
        let targetPID: pid_t = 432

        try executor.execute(
            .keyboardShortcut(KeyboardShortcutAction(keyCode: 9, modifiers: [.command])),
            targetProcessIdentifier: targetPID,
            targetBundleIdentifier: "com.example.app"
        )

        XCTAssertEqual(processActivator.activatedProcessIdentifiers, [targetPID])
        XCTAssertEqual(
            keyEventPoster.postedEvents.map(\.targetProcessIdentifier),
            [targetPID, targetPID]
        )
    }

    func testShowDesktopUsesCommandF3Shortcut() throws {
        let keyEventPoster = SpyKeyboardEventPoster()
        let executor = ActionExecutor(keyEventPoster: keyEventPoster)

        try executor.execute(
            .systemCommand(.showDesktop),
            targetProcessIdentifier: nil,
            targetBundleIdentifier: nil
        )

        XCTAssertEqual(
            keyEventPoster.events,
            [
                .init(keyCode: 99, flags: [.maskCommand], isKeyDown: true),
                .init(keyCode: 99, flags: [.maskCommand], isKeyDown: false)
            ]
        )
    }

    func testLockScreenRunsCGSessionSuspendCommand() throws {
        let commandRunner = SpySystemCommandRunner()
        let executor = ActionExecutor(systemCommandRunner: commandRunner)

        try executor.execute(
            .systemCommand(.lockScreen),
            targetProcessIdentifier: nil,
            targetBundleIdentifier: nil
        )

        XCTAssertEqual(
            commandRunner.commands,
            [
                .init(
                    executableURL: URL(
                        fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
                    ),
                    arguments: ["-suspend"]
                )
            ]
        )
    }
}

private struct PostedKeyboardEvent: Equatable {
    var event: KeyboardEventPost
    var targetProcessIdentifier: pid_t?
}

private final class SpyApplicationActivator: ApplicationActivating {
    private(set) var activateCount = 0

    func activateCurrentApplication() {
        activateCount += 1
    }
}

private final class SpyProcessActivator: ProcessActivating {
    private(set) var activatedProcessIdentifiers: [pid_t] = []

    @discardableResult
    func activate(processIdentifier: pid_t, bundleIdentifier: String?) -> Bool {
        activatedProcessIdentifiers.append(processIdentifier)
        return true
    }
}

private final class SpyKeyboardEventPoster: KeyboardEventPosting {
    private(set) var events: [KeyboardEventPost] = []
    private(set) var postedEvents: [PostedKeyboardEvent] = []

    func post(_ event: KeyboardEventPost, targetProcessIdentifier: pid_t?) throws {
        events.append(event)
        postedEvents.append(
            PostedKeyboardEvent(
                event: event,
                targetProcessIdentifier: targetProcessIdentifier
            )
        )
    }
}

private final class SpyWorkspaceOpener: WorkspaceOpening {
    var applicationURLsByBundleIdentifier: [String: URL] = [:]
    private(set) var openedApplicationURLs: [URL] = []
    private(set) var openedURLs: [URL] = []

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        applicationURLsByBundleIdentifier[bundleIdentifier]
    }

    func openApplication(at applicationURL: URL) throws {
        openedApplicationURLs.append(applicationURL)
    }

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}

private final class SpySystemCommandRunner: SystemCommandRunning {
    struct Command: Equatable {
        var executableURL: URL
        var arguments: [String]
    }

    private(set) var commands: [Command] = []

    func run(executableURL: URL, arguments: [String]) throws -> Int32 {
        commands.append(Command(executableURL: executableURL, arguments: arguments))
        return 0
    }
}
