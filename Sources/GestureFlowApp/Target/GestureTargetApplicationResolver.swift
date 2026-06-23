import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import GestureFlowCore

protocol WorkspaceForegroundQuerying {
    func frontmostApplication() -> ForegroundApplicationSnapshot?
}

struct ForegroundApplicationSnapshot: Equatable {
    var bundleIdentifier: String?
    var processIdentifier: Int32
}

protocol WindowListQuerying {
    func onScreenWindows() -> [WindowListEntry]
}

struct WindowListEntry: Equatable {
    var windowNumber: Int
    var bounds: CGRect
    var layer: Int
    var alpha: Double
    var ownerPID: Int32
    var ownerName: String
    var isOnScreen: Bool
}

protocol RunningApplicationQuerying {
    func bundleIdentifier(forProcessIdentifier processIdentifier: Int32) -> String?
    func activationPolicy(forProcessIdentifier processIdentifier: Int32) -> NSApplication.ActivationPolicy?
    func hasRegularRunningApplication(withBundleIdentifier bundleIdentifier: String) -> Bool
}

protocol WindowNumberQuerying {
    func windowNumber(at screenPoint: CGPoint, belowWindowNumber: Int) -> Int
}

protocol AccessibilityApplicationQuerying {
    func applicationAtScreenPoint(_ point: CGPoint) -> ResolvedGestureTarget?
}

enum GestureTargetWindowGeometry {
    /// Converts `CGWindowListCopyWindowInfo` bounds (global, top-left origin) into AppKit screen space.
    static func appKitScreenBounds(for windowBounds: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: windowBounds.origin.x,
            y: screenFrame.maxY + screenFrame.minY - windowBounds.origin.y - windowBounds.height,
            width: windowBounds.width,
            height: windowBounds.height
        )
    }
}

final class GestureTargetApplicationResolver: GestureTargetResolving, @unchecked Sendable {
    private let ownProcessIdentifier: Int32
    private let workspace: WorkspaceForegroundQuerying
    private let windowList: WindowListQuerying
    private let windowNumberQuery: WindowNumberQuerying
    private let runningApplicationQuery: RunningApplicationQuerying
    private let accessibilityQuery: AccessibilityApplicationQuerying
    private let screenFramesProvider: () -> [CGRect]
    private let desktopFrameProvider: () -> CGRect
    private let excludedOwnerNames: Set<String>

    init(
        ownProcessIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier,
        workspace: WorkspaceForegroundQuerying = NSWorkspaceForegroundQuery(),
        windowList: WindowListQuerying = CGWindowListQuery(),
        windowNumberQuery: WindowNumberQuerying = NSWindowNumberQuery(),
        runningApplicationQuery: RunningApplicationQuerying = NSRunningApplicationQuery(),
        accessibilityQuery: AccessibilityApplicationQuerying = AXApplicationQuery(),
        screenFramesProvider: @escaping () -> [CGRect] = {
            NSScreen.screens.map(\.frame)
        },
        desktopFrameProvider: @escaping () -> CGRect = {
            NSScreen.screens.map(\.frame).reduce(into: CGRect.null) { partial, frame in
                partial = partial.union(frame)
            }
        },
        excludedOwnerNames: Set<String> = ["Dock", "Window Server", "Control Center"]
    ) {
        self.ownProcessIdentifier = ownProcessIdentifier
        self.workspace = workspace
        self.windowList = windowList
        self.windowNumberQuery = windowNumberQuery
        self.runningApplicationQuery = runningApplicationQuery
        self.accessibilityQuery = accessibilityQuery
        self.screenFramesProvider = screenFramesProvider
        self.desktopFrameProvider = desktopFrameProvider
        self.excludedOwnerNames = excludedOwnerNames
    }

    func resolve(
        policy: GestureTargetApplication,
        at startPoint: GesturePoint
    ) -> ResolvedGestureTarget {
        switch policy {
        case .foreground:
            return resolveForeground()
        case .underMouse:
            return resolveUnderMouse(at: startPoint)
        }
    }

    private func resolveForeground() -> ResolvedGestureTarget {
        guard let application = workspace.frontmostApplication() else {
            return .invalid
        }
        return ResolvedGestureTarget(
            bundleIdentifier: application.bundleIdentifier,
            processIdentifier: application.processIdentifier
        )
    }

    /// Top-to-bottom hit test at the press point: first eligible window whose bounds contain the point wins.
    private func resolveUnderMouse(at startPoint: GesturePoint) -> ResolvedGestureTarget {
        let screenPoint = CGPoint(x: startPoint.x, y: startPoint.y)
        let windowNumbers = windowNumbersAtPoint(screenPoint)
        let stackTarget = resolveFromWindowStack(
            at: screenPoint,
            windowNumbers: windowNumbers
        )
        return reconcileWithAccessibilityTarget(
            stackTarget: stackTarget,
            at: screenPoint,
            windowCountAtPoint: windowNumbers.count
        )
    }

    private func resolveFromWindowStack(
        at screenPoint: CGPoint,
        windowNumbers: [Int]
    ) -> ResolvedGestureTarget {
        let screenFrame = screenFrame(containing: screenPoint)
        let desktopFrame = desktopFrameProvider()
        let windowsByNumber = Dictionary(
            uniqueKeysWithValues: windowList.onScreenWindows().map { ($0.windowNumber, $0) }
        )

        for (index, windowNumber) in windowNumbers.enumerated() {
            guard let window = windowsByNumber[windowNumber],
                  eligibilityRejectionReason(for: window, desktopFrame: desktopFrame) == nil else {
                continue
            }

            let appKitBounds = GestureTargetWindowGeometry.appKitScreenBounds(
                for: window.bounds,
                in: screenFrame
            )
            guard appKitBounds.contains(screenPoint),
                  let target = makeResolvedTarget(for: window) else {
                continue
            }

            let remainingWindowNumbers = Array(windowNumbers.dropFirst(index + 1))
            if shouldDeferTarget(
                window: window,
                inFavorOfWindowsBelow: remainingWindowNumbers
            ) {
                continue
            }

            return target
        }

        return .invalid
    }

    private func reconcileWithAccessibilityTarget(
        stackTarget: ResolvedGestureTarget,
        at screenPoint: CGPoint,
        windowCountAtPoint: Int
    ) -> ResolvedGestureTarget {
        guard let accessibilityTarget = accessibilityQuery.applicationAtScreenPoint(screenPoint),
              accessibilityTarget.isValid else {
            return stackTarget
        }

        guard stackTarget.isValid else {
            return accessibilityTarget
        }

        if stackTarget.bundleIdentifier != accessibilityTarget.bundleIdentifier,
           windowCountAtPoint >= 2 {
            return accessibilityTarget
        }

        return stackTarget
    }

    private func makeResolvedTarget(for window: WindowListEntry) -> ResolvedGestureTarget? {
        guard let ownerBundleIdentifier = runningApplicationQuery.bundleIdentifier(
            forProcessIdentifier: window.ownerPID
        ) else {
            return nil
        }

        let bundleIdentifier = regularizedBundleIdentifier(forOwnerBundleIdentifier: ownerBundleIdentifier)
        return ResolvedGestureTarget(
            bundleIdentifier: bundleIdentifier,
            processIdentifier: window.ownerPID
        )
    }

    private func regularizedBundleIdentifier(forOwnerBundleIdentifier ownerBundleIdentifier: String) -> String {
        guard let parentBundleIdentifier = ApplicationBundleIdentifierSupport.parentBundleIdentifier(
            forHelperBundleIdentifier: ownerBundleIdentifier
        ),
            runningApplicationQuery.hasRegularRunningApplication(withBundleIdentifier: parentBundleIdentifier)
        else {
            return ownerBundleIdentifier
        }
        return parentBundleIdentifier
    }

    private func shouldDeferTarget(
        window: WindowListEntry,
        inFavorOfWindowsBelow remainingWindowNumbers: [Int]
    ) -> Bool {
        guard !remainingWindowNumbers.isEmpty else { return false }

        if window.alpha < 0.95 {
            return true
        }

        guard let activationPolicy = runningApplicationQuery.activationPolicy(
            forProcessIdentifier: window.ownerPID
        ) else {
            return false
        }

        return activationPolicy != .regular
    }

    private func windowNumbersAtPoint(_ screenPoint: CGPoint) -> [Int] {
        var numbers: [Int] = []
        var belowWindowNumber = 0
        while true {
            let windowNumber = windowNumberQuery.windowNumber(
                at: screenPoint,
                belowWindowNumber: belowWindowNumber
            )
            guard windowNumber != 0 else { break }
            numbers.append(windowNumber)
            belowWindowNumber = windowNumber
        }
        return numbers
    }

    private func eligibilityRejectionReason(
        for window: WindowListEntry,
        desktopFrame: CGRect
    ) -> String? {
        guard window.isOnScreen else { return "off-screen" }
        guard window.alpha > 0.01 else { return "transparent" }
        guard window.bounds.width >= 2, window.bounds.height >= 2 else { return "too-small" }
        guard !excludedOwnerNames.contains(window.ownerName) else { return "excluded-owner" }
        if isGestureFlowFullscreenOverlayWindow(window, desktopFrame: desktopFrame) {
            return "gesture-overlay"
        }
        return nil
    }

    private func isGestureFlowFullscreenOverlayWindow(
        _ window: WindowListEntry,
        desktopFrame: CGRect
    ) -> Bool {
        guard window.ownerPID == ownProcessIdentifier else { return false }
        let desktopArea = desktopFrame.width * desktopFrame.height
        guard desktopArea > 0 else { return false }
        let windowArea = window.bounds.width * window.bounds.height
        return windowArea >= desktopArea * 0.8
    }

    private func screenFrame(containing screenPoint: CGPoint) -> CGRect {
        screenFramesProvider().first(where: { $0.contains(screenPoint) }) ?? desktopFrameProvider()
    }
}

private struct NSRunningApplicationQuery: RunningApplicationQuerying {
    func bundleIdentifier(forProcessIdentifier processIdentifier: Int32) -> String? {
        NSRunningApplication(processIdentifier: pid_t(processIdentifier))?.bundleIdentifier
    }

    func activationPolicy(forProcessIdentifier processIdentifier: Int32) -> NSApplication.ActivationPolicy? {
        NSRunningApplication(processIdentifier: pid_t(processIdentifier))?.activationPolicy
    }

    func hasRegularRunningApplication(withBundleIdentifier bundleIdentifier: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).contains {
            $0.activationPolicy == .regular
        }
    }
}

private struct NSWorkspaceForegroundQuery: WorkspaceForegroundQuerying {
    func frontmostApplication() -> ForegroundApplicationSnapshot? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return ForegroundApplicationSnapshot(
            bundleIdentifier: application.bundleIdentifier,
            processIdentifier: application.processIdentifier
        )
    }
}

private struct AXApplicationQuery: AccessibilityApplicationQuerying {
    func applicationAtScreenPoint(_ point: CGPoint) -> ResolvedGestureTarget? {
        let mainScreenHeight = NSScreen.main?.frame.height ?? 0
        let quartzY = mainScreenHeight - point.y

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(point.x),
            Float(quartzY),
            &element
        )
        guard status == .success, let element else {
            return nil
        }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success,
              let application = NSRunningApplication(processIdentifier: processIdentifier),
              let bundleIdentifier = application.bundleIdentifier else {
            return nil
        }

        let resolvedBundleIdentifier = regularizedBundleIdentifier(for: bundleIdentifier)
        return ResolvedGestureTarget(
            bundleIdentifier: resolvedBundleIdentifier,
            processIdentifier: processIdentifier
        )
    }

    private func regularizedBundleIdentifier(for ownerBundleIdentifier: String) -> String {
        guard let parentBundleIdentifier = ApplicationBundleIdentifierSupport.parentBundleIdentifier(
            forHelperBundleIdentifier: ownerBundleIdentifier
        ),
            NSRunningApplication.runningApplications(withBundleIdentifier: parentBundleIdentifier).contains(
                where: { $0.activationPolicy == .regular }
            )
        else {
            return ownerBundleIdentifier
        }
        return parentBundleIdentifier
    }
}

private struct NSWindowNumberQuery: WindowNumberQuerying {
    func windowNumber(at screenPoint: CGPoint, belowWindowNumber: Int) -> Int {
        NSWindow.windowNumber(
            at: NSPoint(x: screenPoint.x, y: screenPoint.y),
            belowWindowWithWindowNumber: belowWindowNumber
        )
    }
}

private struct CGWindowListQuery: WindowListQuerying {
    func onScreenWindows() -> [WindowListEntry] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap(WindowListEntry.init(rawWindowInfo:))
    }
}

private extension WindowListEntry {
    init?(rawWindowInfo: [String: Any]) {
        guard let boundsDictionary = rawWindowInfo[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
              let layer = rawWindowInfo[kCGWindowLayer as String] as? Int,
              let alpha = rawWindowInfo[kCGWindowAlpha as String] as? Double,
              let ownerPID = rawWindowInfo[kCGWindowOwnerPID as String] as? Int32,
              let ownerName = rawWindowInfo[kCGWindowOwnerName as String] as? String else {
            return nil
        }

        let windowNumber = rawWindowInfo[kCGWindowNumber as String] as? Int ?? 0
        let isOnScreen = rawWindowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
        self.init(
            windowNumber: windowNumber,
            bounds: bounds,
            layer: layer,
            alpha: alpha,
            ownerPID: ownerPID,
            ownerName: ownerName,
            isOnScreen: isOnScreen
        )
    }
}
