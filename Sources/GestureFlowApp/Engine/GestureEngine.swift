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

    private let appConfigurationProvider: AppConfigurationProvider
    private let gestureConfigurationProvider: GestureConfigurationProvider
    private let targetResolver: GestureTargetResolving
    private let permissionService: PermissionService
    private let eventTap: MouseEventTapControlling
    private let recognizer: GestureRecognizer
    private let matcher: ScopedGestureMatcher
    private let liveMatcher: GestureLiveMatcher
    private let actionExecutor: ActionExecuting
    private let feedbackHandler: FeedbackHandler
    private let overlay: GestureOverlayDisplaying
    private var isTimeoutMarkerVisible = false
    /// Resolved at gesture start (before the fullscreen overlay is shown) for stable under-mouse targeting.
    private var pendingGestureTarget: ResolvedGestureTarget?
    private var activeGesturePoints: [GesturePoint] = []
    private var activeGestureTrigger: GestureTrigger?

    private(set) var isRunning = false

    init(
        appConfigurationProvider: @escaping AppConfigurationProvider,
        gestureConfigurationProvider: @escaping GestureConfigurationProvider,
        targetResolver: GestureTargetResolving = GestureTargetApplicationResolver(),
        permissionService: PermissionService = PermissionService(),
        eventTap: MouseEventTapControlling = MouseEventTap(),
        recognizer: GestureRecognizer = GestureRecognizer(),
        matcher: ScopedGestureMatcher = ScopedGestureMatcher(),
        liveMatcher: GestureLiveMatcher = GestureLiveMatcher(),
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
        self.liveMatcher = liveMatcher
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
        eventTap.onGestureBegan = { [weak self] trigger, point in
            self?.clearTimeoutMarkerIfNeeded()
            self?.handleGestureBegan(trigger: trigger, at: point)
        }
        eventTap.onGestureMoved = { [weak self] point in
            self?.handleGestureMoved(to: point)
        }
        eventTap.onGestureEnded = { [weak self] trigger, points in
            self?.handleGestureEnded(trigger: trigger, points: points)
        }
        eventTap.onGestureCancelled = { [weak self] in
            self?.clearTimeoutMarkerIfNeeded()
            self?.pendingGestureTarget = nil
            self?.clearActiveGesture()
            self?.overlay.cancelGesture()
        }
        eventTap.onRightClickTimeout = { [weak self] point in
            self?.showTimeoutMarker(at: point)
        }
        eventTap.onRightClickTimeoutCleared = { [weak self] in
            self?.clearTimeoutMarkerIfNeeded()
        }
    }

    private func handleGestureBegan(trigger: GestureTrigger, at point: GesturePoint) {
        let work = { [self] in
            self.captureGestureTarget(at: point)
            self.activeGestureTrigger = trigger
            self.activeGesturePoints = [point]
            let appearance = GestureTrailAppearance(feedback: self.appConfigurationProvider().feedback)
            self.overlay.beginGesture(at: self.displayPoint(for: point), appearance: appearance)
            self.refreshLiveGestureFeedback(at: point)
        }
        runOnMain(work)
    }

    private func handleGestureMoved(to point: GesturePoint) {
        let work = { [self] in
            guard !self.activeGesturePoints.isEmpty else { return }
            self.activeGesturePoints.append(point)
            let displayPoint = self.displayPoint(for: point)
            self.overlay.appendGesturePoint(displayPoint)
            self.refreshLiveGestureFeedback(at: point)
        }
        runOnMain(work)
    }

    private func captureGestureTarget(at startPoint: GesturePoint) {
        let policy = appConfigurationProvider().gestureTargetApplication
        pendingGestureTarget = targetResolver.resolve(policy: policy, at: startPoint)
    }

    private func handleGestureEnded(trigger: GestureTrigger, points: [GesturePoint]) {
        runOnMain { [self] in
            self.finishGestureEnded(trigger: trigger, points: points)
        }
    }

    private func finishGestureEnded(trigger: GestureTrigger, points: [GesturePoint]) {
        clearActiveGesture()
        clearTimeoutMarkerIfNeeded()
        let completionPoint = points.last

        let hideAfter = overlayHideDelay()

        guard let signature = recognizer.recognize(points: points) else {
            overlay.completeGesture(with: .rejected, at: completionPoint, hideAfter: hideAfter)
            feedbackHandler(.rejected(trigger: trigger))
            return
        }

        guard let startPoint = points.first else {
            overlay.completeGesture(with: .rejected, at: completionPoint, hideAfter: hideAfter)
            feedbackHandler(.rejected(trigger: trigger))
            return
        }

        let targetPolicy = appConfigurationProvider().gestureTargetApplication
        let resolvedTarget = pendingGestureTarget
            ?? targetResolver.resolve(policy: targetPolicy, at: startPoint)
        pendingGestureTarget = nil
        let matchedGesture = matcher.match(
            trigger: trigger,
            signature: signature,
            targetBundleIdentifier: resolvedTarget.bundleIdentifier,
            in: gestureConfigurationProvider().gestures
        )

        if targetPolicy == .underMouse, !resolvedTarget.isValid {
            let overlayCompletion: GestureOverlayCompletion = if let matchedGesture {
                .targetNotFound(
                    gestureID: matchedGesture.id,
                    storedName: matchedGesture.name
                )
            } else {
                .unmatched
            }
            reportGestureFailure(
                overlayCompletion: overlayCompletion,
                trigger: trigger,
                signature: signature,
                message: AppServices.localization.string(.engineUnderMouseTargetMissing),
                at: completionPoint
            )
            return
        }

        guard let gesture = matchedGesture else {
            overlay.completeGesture(with: .unmatched, at: completionPoint, hideAfter: hideAfter)
            feedbackHandler(.unmatched(trigger: trigger, signature: signature))
            return
        }

        guard gesture.shortcut.isRecorded else {
            reportGestureFailure(
                overlayCompletion: .shortcutNotConfigured(
                    gestureID: gesture.id,
                    storedName: gesture.name
                ),
                trigger: trigger,
                signature: signature,
                message: "Shortcut is not configured",
                at: completionPoint
            )
            return
        }

        guard let targetProcessIdentifier = resolvedTarget.processIdentifier else {
            reportGestureFailure(
                overlayCompletion: .deliveryFailed(
                    gestureID: gesture.id,
                    storedName: gesture.name
                ),
                trigger: trigger,
                signature: signature,
                message: AppServices.localization.string(.engineTargetDeliveryFailed),
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
            reportGestureFailure(
                overlayCompletion: .executionFailed(
                    gestureID: gesture.id,
                    storedName: gesture.name
                ),
                trigger: trigger,
                signature: signature,
                message: error.localizedDescription,
                at: completionPoint
            )
            return
        }

        overlay.completeGesture(
            with: .recognized(gestureID: gesture.id, storedName: gesture.name),
            at: completionPoint,
            hideAfter: hideAfter
        )
        feedbackHandler(
            .recognized(
                trigger: trigger,
                name: AppServices.localization.localizedGestureDisplayName(gesture)
            )
        )
    }

    private func overlayHideDelay() -> TimeInterval {
        let milliseconds = appConfigurationProvider().feedback.overlayHideDelayMilliseconds
        return TimeInterval(milliseconds) / 1000
    }

    private func reportGestureFailure(
        overlayCompletion: GestureOverlayCompletion,
        trigger: GestureTrigger,
        signature: GestureSignature,
        message: String,
        at completionPoint: GesturePoint?
    ) {
        let signatureDescription = signature.tokens.map(\.rawValue).joined(separator: ",")
        print(
            "[GestureFlow] 分发失败 trigger=\(trigger.rawValue) signature=\(signatureDescription) detail=\(message)"
        )
        overlay.completeGesture(
            with: overlayCompletion,
            at: completionPoint,
            hideAfter: overlayHideDelay()
        )
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

    private func refreshLiveGestureFeedback(at point: GesturePoint) {
        guard let trigger = activeGestureTrigger else { return }

        let partialSignature = recognizer.recognize(points: activeGesturePoints)
        let resolvedTarget = pendingGestureTarget
        let liveResult = liveMatcher.evaluate(
            trigger: trigger,
            partialSignature: partialSignature,
            targetBundleIdentifier: resolvedTarget?.bundleIdentifier,
            in: gestureConfigurationProvider().gestures
        )
        let isHighlighted = liveResult.exactMatch != nil || liveResult.hasPrefixMatch
        let appearance = GestureTrailAppearance(
            feedback: appConfigurationProvider().feedback,
            isHighlighted: isHighlighted
        )
        let feedback: LiveGestureOverlayFeedback
        if let exactMatch = liveResult.exactMatch {
            feedback = LiveGestureOverlayFeedback(
                message: nil,
                matchedGestureID: exactMatch.id,
                matchedGestureStoredName: exactMatch.name,
                showsCard: true,
                usesTrailColor: true
            )
        } else if partialSignature != nil {
            feedback = LiveGestureOverlayFeedback(
                message: AppServices.localization.string(.overlayUnmatchedGesture),
                showsCard: true
            )
        } else {
            feedback = LiveGestureOverlayFeedback(message: nil, showsCard: false)
        }

        overlay.updateLiveGesture(
            at: displayPoint(for: point),
            appearance: appearance,
            feedback: feedback
        )
    }

    private func clearActiveGesture() {
        activeGesturePoints = []
        activeGestureTrigger = nil
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
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
