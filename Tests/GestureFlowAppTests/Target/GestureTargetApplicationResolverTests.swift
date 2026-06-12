import AppKit
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

    func testUnderMouseSkipsElectronHelperOverlayToReachChromeBelow() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 0,
                alpha: 1,
                ownerPID: 500,
                ownerName: "Cursor",
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
        runningApplications.bundleIdentifiersByPID[500] = "com.cursor.app.helper"
        runningApplications.bundleIdentifiersByPID[400] = "com.google.Chrome"
        runningApplications.activationPoliciesByPID[500] = .prohibited
        runningApplications.activationPoliciesByPID[400] = .regular
        runningApplications.regularBundleIdentifiers = ["com.cursor.app", "com.google.Chrome"]
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

        XCTAssertEqual(resolved.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(resolved.processIdentifier, 400)
    }

    func testUnderMouseTargetsElectronWhenOnlyRendererWindowAtPoint() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 200, width: 1200, height: 800),
                layer: 0,
                alpha: 1,
                ownerPID: 500,
                ownerName: "Cursor",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[500] = "com.cursor.app.helper"
        runningApplications.activationPoliciesByPID[500] = .prohibited
        runningApplications.regularBundleIdentifiers = ["com.cursor.app"]
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10]
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 300))

        XCTAssertEqual(resolved.bundleIdentifier, "com.cursor.app")
        XCTAssertEqual(resolved.processIdentifier, 500)
    }

    func testUnderMouseSkipsTransparentOverlayToReachChromeBelow() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 0,
                alpha: 0.5,
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
        runningApplications.activationPoliciesByPID[300] = .regular
        runningApplications.activationPoliciesByPID[400] = .regular
        runningApplications.regularBundleIdentifiers = ["com.apple.Notes", "com.google.Chrome"]
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

        XCTAssertEqual(resolved.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(resolved.processIdentifier, 400)
    }

    func testUnderMousePrefersAccessibilityTargetWhenRegularOverlaySitsAboveChrome() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                layer: 0,
                alpha: 1,
                ownerPID: 500,
                ownerName: "Cursor",
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
        runningApplications.bundleIdentifiersByPID[500] = "com.todesktop.230313mzl4w4u92"
        runningApplications.bundleIdentifiersByPID[400] = "com.google.Chrome"
        runningApplications.activationPoliciesByPID[500] = .regular
        runningApplications.activationPoliciesByPID[400] = .regular
        runningApplications.regularBundleIdentifiers = [
            "com.todesktop.230313mzl4w4u92",
            "com.google.Chrome"
        ]
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10, 11]
        let accessibilityQuery = SpyAccessibilityApplicationQuery()
        accessibilityQuery.targetsByPoint[CGPoint(x: 100, y: 100)] = ResolvedGestureTarget(
            bundleIdentifier: "com.google.Chrome",
            processIdentifier: 400
        )
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            accessibilityQuery: accessibilityQuery,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 100))

        XCTAssertEqual(resolved.bundleIdentifier, "com.google.Chrome")
        XCTAssertEqual(resolved.processIdentifier, 400)
    }

    func testUnderMouseKeepsStackTargetWhenAccessibilityAgreesOnSingleWindow() {
        let windowList = SpyWindowListQuery()
        windowList.windows = [
            WindowListEntry(
                windowNumber: 10,
                bounds: CGRect(x: 0, y: 200, width: 1200, height: 800),
                layer: 0,
                alpha: 1,
                ownerPID: 500,
                ownerName: "Cursor",
                isOnScreen: true
            )
        ]
        let runningApplications = SpyRunningApplicationQuery()
        runningApplications.bundleIdentifiersByPID[500] = "com.todesktop.230313mzl4w4u92"
        runningApplications.activationPoliciesByPID[500] = .regular
        runningApplications.regularBundleIdentifiers = ["com.todesktop.230313mzl4w4u92"]
        let windowNumberQuery = SpyWindowNumberQuery()
        windowNumberQuery.windowNumbersAtPoint = [10]
        let accessibilityQuery = SpyAccessibilityApplicationQuery()
        accessibilityQuery.targetsByPoint[CGPoint(x: 100, y: 300)] = ResolvedGestureTarget(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            processIdentifier: 500
        )
        let resolver = makeResolver(
            workspace: SpyWorkspaceForegroundQuery(),
            windowList: windowList,
            windowNumberQuery: windowNumberQuery,
            runningApplications: runningApplications,
            accessibilityQuery: accessibilityQuery,
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let resolved = resolver.resolve(policy: .underMouse, at: GesturePoint(x: 100, y: 300))

        XCTAssertEqual(resolved.bundleIdentifier, "com.todesktop.230313mzl4w4u92")
        XCTAssertEqual(resolved.processIdentifier, 500)
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
        accessibilityQuery: AccessibilityApplicationQuerying = SpyAccessibilityApplicationQuery(),
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
            accessibilityQuery: accessibilityQuery,
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

private final class SpyAccessibilityApplicationQuery: AccessibilityApplicationQuerying {
    var targetsByPoint: [CGPoint: ResolvedGestureTarget] = [:]

    func applicationAtScreenPoint(_ point: CGPoint) -> ResolvedGestureTarget? {
        targetsByPoint[point]
    }
}

private final class SpyRunningApplicationQuery: RunningApplicationQuerying {
    var bundleIdentifiersByPID: [Int32: String] = [:]
    var activationPoliciesByPID: [Int32: NSApplication.ActivationPolicy] = [:]
    var regularBundleIdentifiers: Set<String> = []

    func bundleIdentifier(forProcessIdentifier processIdentifier: Int32) -> String? {
        bundleIdentifiersByPID[processIdentifier]
    }

    func activationPolicy(forProcessIdentifier processIdentifier: Int32) -> NSApplication.ActivationPolicy? {
        activationPoliciesByPID[processIdentifier]
    }

    func hasRegularRunningApplication(withBundleIdentifier bundleIdentifier: String) -> Bool {
        regularBundleIdentifiers.contains(bundleIdentifier)
    }
}
