import AppKit
import Foundation
import GestureFlowCore

enum GestureEngineFeedback: Equatable {
    case recognized(trigger: GestureTrigger, name: String)
    case unmatched(trigger: GestureTrigger, signature: GestureSignature)
    case rejected(trigger: GestureTrigger)
    case actionFailed(trigger: GestureTrigger, signature: GestureSignature, message: String)
}

final class GestureEngine {
    typealias AppConfigurationProvider = () -> AppConfiguration
    typealias GestureConfigurationProvider = () -> GestureConfiguration
    typealias ForegroundApplicationBundleIdentifierProvider = () -> String?
    typealias FeedbackHandler = (GestureEngineFeedback) -> Void

    private let appConfigurationProvider: AppConfigurationProvider
    private let gestureConfigurationProvider: GestureConfigurationProvider
    private let foregroundApplicationBundleIdentifierProvider: ForegroundApplicationBundleIdentifierProvider
    private let permissionService: PermissionService
    private let eventTap: MouseEventTapControlling
    private let recognizer: GestureRecognizer
    private let matcher: ScopedGestureMatcher
    private let actionExecutor: ActionExecuting
    private let feedbackHandler: FeedbackHandler
    private let overlay: GestureOverlayDisplaying
    private var isTimeoutMarkerVisible = false

    private(set) var isRunning = false

    init(
        appConfigurationProvider: @escaping AppConfigurationProvider,
        gestureConfigurationProvider: @escaping GestureConfigurationProvider,
        foregroundApplicationBundleIdentifierProvider: @escaping ForegroundApplicationBundleIdentifierProvider = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        permissionService: PermissionService = PermissionService(),
        eventTap: MouseEventTapControlling = MouseEventTap(),
        recognizer: GestureRecognizer = GestureRecognizer(),
        matcher: ScopedGestureMatcher = ScopedGestureMatcher(),
        overlay: GestureOverlayDisplaying = NoopGestureOverlay(),
        actionExecutor: ActionExecuting = ActionExecutor(),
        feedbackHandler: @escaping FeedbackHandler = { feedback in
            print("GestureFlow feedback: \(feedback)")
        }
    ) {
        self.appConfigurationProvider = appConfigurationProvider
        self.gestureConfigurationProvider = gestureConfigurationProvider
        self.foregroundApplicationBundleIdentifierProvider = foregroundApplicationBundleIdentifierProvider
        self.permissionService = permissionService
        self.eventTap = eventTap
        self.recognizer = recognizer
        self.matcher = matcher
        self.overlay = overlay
        self.actionExecutor = actionExecutor
        self.feedbackHandler = feedbackHandler
        installCallbacks()
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard permissionService.isAccessibilityTrusted else {
            permissionService.promptForAccessibilityPermission()
            return false
        }

        isRunning = eventTap.start()
        return isRunning
    }

    func stop() {
        guard isRunning else { return }
        eventTap.stop()
        isTimeoutMarkerVisible = false
        overlay.cancelGesture()
        isRunning = false
    }

    private func installCallbacks() {
        eventTap.onGestureBegan = { [weak self] _, point in
            self?.clearTimeoutMarkerIfNeeded()
            self?.handleGestureBegan(at: point)
        }
        eventTap.onGestureMoved = { [weak self] point in
            self?.overlay.appendGesturePoint(self?.displayPoint(for: point) ?? point)
        }
        eventTap.onGestureEnded = { [weak self] trigger, points in
            self?.handleGestureEnded(trigger: trigger, points: points)
        }
        eventTap.onGestureCancelled = { [weak self] in
            self?.clearTimeoutMarkerIfNeeded()
            self?.overlay.cancelGesture()
        }
        eventTap.onRightClickTimeout = { [weak self] point in
            self?.showTimeoutMarker(at: point)
        }
        eventTap.onRightClickTimeoutCleared = { [weak self] in
            self?.clearTimeoutMarkerIfNeeded()
        }
    }

    private func handleGestureBegan(at point: GesturePoint) {
        let appearance = GestureTrailAppearance(feedback: appConfigurationProvider().feedback)
        overlay.beginGesture(at: displayPoint(for: point), appearance: appearance)
    }

    private func handleGestureEnded(trigger: GestureTrigger, points: [GesturePoint]) {
        clearTimeoutMarkerIfNeeded()
        let completionPoint = points.last

        guard let signature = recognizer.recognize(points: points) else {
            overlay.completeGesture(with: .rejected, at: completionPoint)
            feedbackHandler(.rejected(trigger: trigger))
            return
        }

        guard let gesture = matcher.match(
            trigger: trigger,
            signature: signature,
            foregroundBundleIdentifier: foregroundApplicationBundleIdentifierProvider(),
            in: gestureConfigurationProvider().gestures
        ) else {
            overlay.completeGesture(with: .unmatched, at: completionPoint)
            feedbackHandler(.unmatched(trigger: trigger, signature: signature))
            return
        }

        guard gesture.shortcut.isRecorded else {
            overlay.completeGesture(with: .actionFailed, at: completionPoint)
            feedbackHandler(
                .actionFailed(
                    trigger: trigger,
                    signature: signature,
                    message: "Shortcut is not configured"
                )
            )
            return
        }

        do {
            try actionExecutor.execute(.keyboardShortcut(gesture.shortcut))
        } catch {
            overlay.completeGesture(with: .actionFailed, at: completionPoint)
            feedbackHandler(
                .actionFailed(
                    trigger: trigger,
                    signature: signature,
                    message: error.localizedDescription
                )
            )
            return
        }

        overlay.completeGesture(with: .recognized(name: gesture.name), at: completionPoint)
        feedbackHandler(.recognized(trigger: trigger, name: gesture.name))
    }

    private func displayPoint(for point: GesturePoint) -> GesturePoint {
        point
    }

    private func showTimeoutMarker(at point: GesturePoint) {
        let appearance = GestureTrailAppearance(feedback: appConfigurationProvider().feedback)
        isTimeoutMarkerVisible = true
        overlay.showMarker(
            GestureOverlayMarker(
                point: displayPoint(for: point),
                style: .timeoutOrigin
            ),
            appearance: appearance
        )
    }

    private func clearTimeoutMarkerIfNeeded() {
        guard isTimeoutMarkerVisible else { return }
        isTimeoutMarkerVisible = false
        overlay.clearMarker()
    }
}
