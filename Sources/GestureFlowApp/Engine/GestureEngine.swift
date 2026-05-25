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
    typealias FeedbackHandler = (GestureEngineFeedback) -> Void

    private static let underMouseTargetMissingMessage = "未找到鼠标下方的应用"
    private static let targetDeliveryFailedMessage = "无法发送到目标应用"

    private let appConfigurationProvider: AppConfigurationProvider
    private let gestureConfigurationProvider: GestureConfigurationProvider
    private let targetResolver: GestureTargetResolving
    private let permissionService: PermissionService
    private let eventTap: MouseEventTapControlling
    private let recognizer: GestureRecognizer
    private let matcher: ScopedGestureMatcher
    private let actionExecutor: ActionExecuting
    private let feedbackHandler: FeedbackHandler
    private let overlay: GestureOverlayDisplaying
    private var isTimeoutMarkerVisible = false
    /// Resolved at gesture start (before the fullscreen overlay is shown) for stable under-mouse targeting.
    private var pendingGestureTarget: ResolvedGestureTarget?

    private(set) var isRunning = false

    init(
        appConfigurationProvider: @escaping AppConfigurationProvider,
        gestureConfigurationProvider: @escaping GestureConfigurationProvider,
        targetResolver: GestureTargetResolving = GestureTargetApplicationResolver(),
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
        self.targetResolver = targetResolver
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
            self?.pendingGestureTarget = nil
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
        let work = { [self] in
            self.captureGestureTarget(at: point)
            let appearance = GestureTrailAppearance(feedback: self.appConfigurationProvider().feedback)
            self.overlay.beginGesture(at: self.displayPoint(for: point), appearance: appearance)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    private func captureGestureTarget(at startPoint: GesturePoint) {
        let policy = appConfigurationProvider().gestureTargetApplication
        pendingGestureTarget = targetResolver.resolve(policy: policy, at: startPoint)
    }

    private func handleGestureEnded(trigger: GestureTrigger, points: [GesturePoint]) {
        let finish = { [self] in
            self.finishGestureEnded(trigger: trigger, points: points)
        }
        if Thread.isMainThread {
            finish()
        } else {
            DispatchQueue.main.sync(execute: finish)
        }
    }

    private func finishGestureEnded(trigger: GestureTrigger, points: [GesturePoint]) {
        clearTimeoutMarkerIfNeeded()
        let completionPoint = points.last

        guard let signature = recognizer.recognize(points: points) else {
            overlay.completeGesture(with: .rejected, at: completionPoint)
            feedbackHandler(.rejected(trigger: trigger))
            return
        }

        guard let startPoint = points.first else {
            overlay.completeGesture(with: .rejected, at: completionPoint)
            feedbackHandler(.rejected(trigger: trigger))
            return
        }

        let targetPolicy = appConfigurationProvider().gestureTargetApplication
        let resolvedTarget = pendingGestureTarget
            ?? targetResolver.resolve(policy: targetPolicy, at: startPoint)
        pendingGestureTarget = nil

        if targetPolicy == .underMouse, !resolvedTarget.isValid {
            reportActionFailure(
                trigger: trigger,
                signature: signature,
                message: Self.underMouseTargetMissingMessage,
                at: completionPoint
            )
            return
        }

        guard let gesture = matcher.match(
            trigger: trigger,
            signature: signature,
            targetBundleIdentifier: resolvedTarget.bundleIdentifier,
            in: gestureConfigurationProvider().gestures
        ) else {
            overlay.completeGesture(with: .unmatched, at: completionPoint)
            feedbackHandler(.unmatched(trigger: trigger, signature: signature))
            return
        }

        guard gesture.shortcut.isRecorded else {
            reportActionFailure(
                trigger: trigger,
                signature: signature,
                message: "Shortcut is not configured",
                at: completionPoint
            )
            return
        }

        guard let targetProcessIdentifier = resolvedTarget.processIdentifier else {
            reportActionFailure(
                trigger: trigger,
                signature: signature,
                message: Self.targetDeliveryFailedMessage,
                at: completionPoint
            )
            return
        }

        do {
            try actionExecutor.execute(
                .keyboardShortcut(gesture.shortcut),
                targetProcessIdentifier: targetProcessIdentifier
            )
        } catch {
            reportActionFailure(
                trigger: trigger,
                signature: signature,
                message: error.localizedDescription,
                at: completionPoint
            )
            return
        }

        overlay.completeGesture(with: .recognized(name: gesture.name), at: completionPoint)
        feedbackHandler(.recognized(trigger: trigger, name: gesture.name))
    }

    private func reportActionFailure(
        trigger: GestureTrigger,
        signature: GestureSignature,
        message: String,
        at completionPoint: GesturePoint?
    ) {
        let signatureDescription = signature.tokens.map(\.rawValue).joined(separator: ",")
        print(
            "[GestureFlow] 分发失败 trigger=\(trigger.rawValue) signature=\(signatureDescription) detail=\(message)"
        )
        overlay.completeGesture(with: .actionFailed, at: completionPoint)
        feedbackHandler(
            .actionFailed(
                trigger: trigger,
                signature: signature,
                message: message
            )
        )
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
