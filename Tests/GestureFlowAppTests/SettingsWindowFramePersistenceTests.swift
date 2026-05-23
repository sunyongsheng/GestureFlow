import AppKit
import XCTest
@testable import GestureFlowApp

final class SettingsWindowFramePersistenceTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var persistence: SettingsWindowFramePersistence!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "SettingsWindowFramePersistenceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        persistence = SettingsWindowFramePersistence(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaultsSuiteName = nil
        defaults = nil
        persistence = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() {
        let frame = NSRect(x: 120, y: 240, width: 1060, height: 660)

        persistence.save(windowFrame: frame)

        XCTAssertEqual(persistence.load()?.frame, frame)
    }

    func testConstrainedFrameEnforcesMinimumSize() {
        let frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        let minimumSize = NSSize(width: 1000, height: 620)

        let adjusted = SettingsWindowFramePersistence.constrainedFrame(
            frame,
            minimumSize: minimumSize,
            screens: []
        )

        XCTAssertEqual(adjusted.size.width, 1000)
        XCTAssertEqual(adjusted.size.height, 620)
    }

    func testConstrainedFrameRepositionsOffscreenFrame() {
        let screen = NSScreen.screens.first!
        let offscreen = NSRect(
            x: screen.visibleFrame.maxX + 200,
            y: screen.visibleFrame.maxY + 200,
            width: 1060,
            height: 660
        )

        let adjusted = SettingsWindowFramePersistence.constrainedFrame(
            offscreen,
            minimumSize: NSSize(width: 1000, height: 620),
            screens: [screen]
        )

        XCTAssertFalse(adjusted.intersection(screen.visibleFrame).isNull)
    }
}
