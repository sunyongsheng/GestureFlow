import AppKit
import XCTest
@testable import GestureFlowApp

@MainActor
final class SettingsWindowLifecycleObserverTests: XCTestCase {
    func testAttachingWindowReportsSettingsDidAppear() {
        let notificationCenter = NotificationCenter()
        var didAppearCount = 0
        let coordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: { didAppearCount += 1 },
            onLastSettingsWindowDidClose: {}
        )
        let window = makeWindow()

        coordinator.attach(to: window)

        XCTAssertEqual(didAppearCount, 1)
    }

    func testReattachingSameWindowDoesNotDuplicateSettingsDidAppear() {
        let notificationCenter = NotificationCenter()
        var didAppearCount = 0
        let coordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: { didAppearCount += 1 },
            onLastSettingsWindowDidClose: {}
        )
        let window = makeWindow()

        coordinator.attach(to: window)
        coordinator.attach(to: window)

        XCTAssertEqual(didAppearCount, 1)
    }

    func testObservedWindowCloseReportsLastSettingsWindowDidClose() {
        let notificationCenter = NotificationCenter()
        var didCloseCount = 0
        let coordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: notificationCenter,
            onSettingsDidAppear: {},
            onLastSettingsWindowDidClose: { didCloseCount += 1 }
        )
        let window = makeWindow()
        coordinator.attach(to: window)

        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(didCloseCount, 1)
    }

    func testAttachingWindowConfiguresTransparentTitleBarAndFullSizeContent() {
        let coordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: NotificationCenter(),
            onSettingsDidAppear: {},
            onLastSettingsWindowDidClose: {}
        )
        let window = makeWindow()

        coordinator.attach(to: window)

        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertNil(window.toolbar)
        XCTAssertEqual(
            window.minSize.width,
            SettingsWindowMetrics.minimumContentSize.width
        )
    }

    func testClosingWindowPersistsFrame() {
        let suiteName = "SettingsWindowLifecycleObserverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = SettingsWindowFramePersistence(defaults: defaults)
        let notificationCenter = NotificationCenter()
        let coordinator = SettingsWindowLifecycleCoordinator(
            notificationCenter: notificationCenter,
            framePersistence: persistence,
            onSettingsDidAppear: {},
            onLastSettingsWindowDidClose: {}
        )
        let window = makeWindow()
        window.setFrame(NSRect(x: 88, y: 120, width: 1100, height: 700), display: false)

        coordinator.attach(to: window)
        notificationCenter.post(name: NSWindow.willCloseNotification, object: window)

        XCTAssertEqual(persistence.load()?.frame, window.frame)
    }

    func testAttachingWindowRestoresPersistedFrame() {
        let suiteName = "SettingsWindowLifecycleObserverTests.restore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let persistence = SettingsWindowFramePersistence(defaults: defaults)
        let savedFrame = NSRect(x: 140, y: 180, width: 1080, height: 680)
        persistence.save(windowFrame: savedFrame)

        let coordinator = SettingsWindowLifecycleCoordinator(
            framePersistence: persistence,
            onSettingsDidAppear: {},
            onLastSettingsWindowDidClose: {}
        )
        let window = makeWindow()

        coordinator.attach(to: window)

        XCTAssertEqual(window.frame, savedFrame)
    }
}

@MainActor
private func makeWindow() -> NSWindow {
    NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
}
