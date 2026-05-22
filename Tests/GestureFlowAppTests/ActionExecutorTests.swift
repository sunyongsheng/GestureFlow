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
            )
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
            )
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
                )
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

        try executor.execute(.openURL(OpenURLAction(url: url)))

        XCTAssertEqual(workspace.openedURLs, [url])
    }

    func testShowDesktopUsesCommandF3Shortcut() throws {
        let keyEventPoster = SpyKeyboardEventPoster()
        let executor = ActionExecutor(keyEventPoster: keyEventPoster)

        try executor.execute(.systemCommand(.showDesktop))

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

        try executor.execute(.systemCommand(.lockScreen))

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

private final class SpyKeyboardEventPoster: KeyboardEventPosting {
    private(set) var events: [KeyboardEventPost] = []

    func post(_ event: KeyboardEventPost) throws {
        events.append(event)
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
