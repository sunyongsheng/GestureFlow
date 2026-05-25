import CoreGraphics
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureTargetApplicationResolverTests: XCTestCase {
    func testAppKitScreenBoundsConvertsCGWindowBoundsForHitTesting() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let cgWindowBounds = CGRect(x: 0, y: 780, width: 400, height: 300)

        let appKitBounds = GestureTargetWindowGeometry.appKitScreenBounds(
            for: cgWindowBounds,
            in: screenFrame
        )

        XCTAssertTrue(appKitBounds.contains(CGPoint(x: 100, y: 100)))
    }

    func testForegroundReturnsFrontmostApplication() {
        let workspace = SpyWorkspaceForegroundQuery()
        workspace.frontmostSnapshot = ForegroundApplicationSnapshot(
            bundleIdentifier: "com.apple.finder",
            processIdentifier: 101
        )
        let resolver = makeResolver(workspace: workspace)

        let resolved = resolver.resolve(policy: .foreground, at: GesturePoint(x: 0, y: 0))

        XCTAssertEqual(resolved.bundleIdentifier, "com.apple.finder")
        XCTAssertEqual(resolved.processIdentifier, 101)
    }

    func testUnderMouseReturnsTopmostEligibleWindowOwner() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 780, width: 400, height: 300),
                layer: 0,
                alpha: 1,
                ownerPID: 200,
                ownerName: "Safari",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[200] = "com.apple.Safari"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 100))

        XCTAssertEqual(resolved.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(resolved.processIdentifier, 200)
    }

    func testUnderMouseTargetsOwnApplicationWhenPressPointInsideWindowBounds() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 11,
                bounds: CGRect(x: 100, y: 200, width: 900, height: 700),
                layer: 0,
                alpha: 1,
                ownerPID: 999,
                ownerName: "GestureFlow",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[999] = "com.gestureflow.app"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [11]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)],
            ownProcessIdentifier: 999
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 200, y: 200))

        XCTAssertEqual(resolved.bundleIdentifier, "com.gestureflow.app")
        XCTAssertEqual(resolved.processIdentifier, 999)
    }

    func testUnderMouseTargetsOwnApplicationWhenPointInsideOwnCGWindowDespiteFullscreenOverlay() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 25,
                alpha: 1,
                ownerPID: 999,
                ownerName: "GestureFlow",
                isOnScreen: true
            ),
            WindowListEntry(
                windowNumber: 11,
                bounds: CGRect(x: 100, y: 200, width: 900, height: 700),
                layer: 0,
                alpha: 1,
                ownerPID: 999,
                ownerName: "GestureFlow",
                isOnScreen: true
            ),
            WindowListEntry(
                windowNumber: 12,
                bounds: CGRect(x: 0, y: 780, width: 400, height: 300),
                layer: 0,
                alpha: 1,
                ownerPID: 200,
                ownerName: "Safari",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[999] = "com.gestureflow.app"
        runningApplications.bundleIdentifiersByPID[200] = "com.apple.Safari"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10, 11]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)],
            ownProcessIdentifier: 999
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 300, y: 300))

        XCTAssertEqual(resolved.bundleIdentifier, "com.gestureflow.app")
        XCTAssertEqual(resolved.processIdentifier, 999)
    }

    func testUnderMouseSkipsGestureFlowFullscreenOverlayWindow() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 25,
                alpha: 1,
                ownerPID: 999,
                ownerName: "GestureFlow",
                isOnScreen: true
            ),
            WindowListEntry(
                windowNumber: 11,
                bounds: CGRect(x: 0, y: 780, width: 400, height: 300),
                layer: 0,
                alpha: 1,
                ownerPID: 200,
                ownerName: "Safari",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[999] = "com.gestureflow.app"
        runningApplications.bundleIdentifiersByPID[200] = "com.apple.Safari"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10, 11]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)],
            ownProcessIdentifier: 999
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 100))

        XCTAssertEqual(resolved.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(resolved.processIdentifier, 200)
    }

    func testUnderMouseReturnsTopmostWindowAtPoint() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 780, width: 400, height: 300),
                layer: 0,
                alpha: 1,
                ownerPID: 999,
                ownerName: "GestureFlow",
                isOnScreen: true
            ),
            WindowListEntry(
                windowNumber: 11,
                bounds: CGRect(x: 0, y: 780, width: 400, height: 300),
                layer: 0,
                alpha: 1,
                ownerPID: 200,
                ownerName: "Safari",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[999] = "com.gestureflow.app"
        runningApplications.bundleIdentifiersByPID[200] = "com.apple.Safari"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10, 11]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 100))

        XCTAssertEqual(resolved.bundleIdentifier, "com.gestureflow.app")
        XCTAssertEqual(resolved.processIdentifier, 999)
    }

    func testUnderMouseTargetsChromeWhenExposedRegionIsBelowPartiallyCoveringWindow() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 1400, y: 200, width: 500, height: 400),
                layer: 10,
                alpha: 1,
                ownerPID: 300,
                ownerName: "Notes",
                isOnScreen: true
            ),
            WindowListEntry(
                windowNumber: 11,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 0,
                alpha: 1,
                ownerPID: 400,
                ownerName: "Google Chrome",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[300] = "com.apple.Notes"
        runningApplications.bundleIdentifiersByPID[400] = "com.google.Chrome"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [11]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 100))

        XCTAssertEqual(resolved.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(resolved.processIdentifier, 400)
    }

    func testUnderMouseIgnoresOffStackWindowWithOverlappingBounds() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 10,
                alpha: 1,
                ownerPID: 300,
                ownerName: "Notes",
                isOnScreen: true
            ),
            WindowListEntry(
                windowNumber: 11,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 0,
                alpha: 1,
                ownerPID: 400,
                ownerName: "Google Chrome",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[300] = "com.apple.Notes"
        runningApplications.bundleIdentifiersByPID[400] = "com.google.Chrome"
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [11]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 100))

        XCTAssertEqual(resolved.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(resolved.processIdentifier, 400)
    }

    func testUnderMouseReturnsInvalidWhenNoWindow() {
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: SpyWindowListQuery(),
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 10, y: 10))

        XCTAssertFalse(resolved.isValid)
    }

    private func makeResolver(
        workspace: SpyWorkspaceForegroundQuery,
        windowList: SpyWindowListQuery = SpyWindowListQuery(),
        windowNumberQuery: WindowNumberQuerying = SpyWindowNumberQuery(),
        runningApplications: SpyRunningApplicationQuery = SpyRunningApplicationQuery(),
        screenFrames: [CGRect] = [CGRect(x: 0, y: 0, width: 100, height: 100)],
        desktopFrame: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
        ownProcessIdentifier: Int32 = 1
    ) -> GestureTargetApplicationResolver {
        GestureTargetApplicationResolver(
            ownProcessIdentifier: ownProcessIdentifier,
            workspace: workspace,
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplicationQuery: runningApplications,
            screenFramesProvider: { screenFrames },
            desktopFrameProvider: { desktopFrame }
        )
    }
}

private final class SpyWorkspaceForegroundQuery: WorkspaceForegroundQuerying {
    var frontmostSnapshot: ForegroundApplicationSnapshot?

    func frontmostApplication() -> ForegroundApplicationSnapshot? {
        frontmostSnapshot
    }
}

private final class SpyWindowListQuery: WindowListQuerying {
    var windows: [WindowListEntry] = []

    func onScreenWindows() -> [WindowListEntry] {
        windows
    }
}

private final class SpyWindowNumberQuery: WindowNumberQuerying {
    var windowNumbersAtPoint: [Int] = []

    func windowNumber(at screenPoint: CGPoint, belowWindowNumber: Int) -> Int {
        if belowWindowNumber == 0 {
            return windowNumbersAtPoint.first ?? 0
        }
        guard let index = windowNumbersAtPoint.firstIndex(of: belowWindowNumber),
              index + 1 < windowNumbersAtPoint.count else {
            return 0
        }
        return windowNumbersAtPoint[index + 1]
    }
}

private final class SpyRunningApplicationQuery: RunningApplicationQuerying {
    var bundleIdentifiersByPID: [Int32: String] = [:]

    func bundleIdentifier(forProcessIdentifier processIdentifier: Int32) -> String? {
        bundleIdentifiersByPID[processIdentifier]
    }
}
