import Foundation
import GestureFlowCore

enum GestureEngineFeedback: Equatable {
    case recognized(trigger: GestureTrigger, signature: GestureSignature)
    case unmatched(trigger: GestureTrigger, signature: GestureSignature)
    case rejected(trigger: GestureTrigger)
    case actionFailed(trigger: GestureTrigger, signature: GestureSignature, message: String)
}

final class GestureEngine {
    typealias ConfigurationProvider = () -> AppConfiguration
    typealias FeedbackHandler = (GestureEngineFeedback) -> Void

    private let configurationProvider: ConfigurationProvider
    private let permissionService: PermissionService
    private let eventTap: MouseEventTapControlling
    private let recognizer: GestureRecognizer
    private let matcher: GestureMatcher
    private let actionExecutor: ActionExecuting
    private let feedbackHandler: FeedbackHandler
    private let overlay: GestureOverlayDisplaying
    private var isTimeoutMarkerVisible = false

    private(set) var isRunning = false

    init(
        configurationProvider: @escaping ConfigurationProvider,
        permissionService: PermissionService = PermissionService(),
        eventTap: MouseEventTapControlling = MouseEventTap(),
        recognizer: GestureRecognizer = GestureRecognizer(),
        matcher: GestureMatcher = GestureMatcher(),
        overlay: GestureOverlayDisplaying = NoopGestureOverlay(),
        actionExecutor: ActionExecuting = ActionExecutor(),
        feedbackHandler: @escaping FeedbackHandler = { feedback in
            print("GestureFlow feedback: \(feedback)")
        }
    ) {
        self.configurationProvider = configurationProvider
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
        let appearance = GestureTrailAppearance(feedback: configurationProvider().feedback)
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

        let configuration = configurationProvider()
        guard let gesture = matcher.match(
            trigger: trigger,
            signature: signature,
            in: configuration.gestures
        ) else {
            overlay.completeGesture(with: .unmatched, at: completionPoint)
            feedbackHandler(.unmatched(trigger: trigger, signature: signature))
            return
        }

        do {
            try actionExecutor.execute(gesture.action)
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

        overlay.completeGesture(with: .recognized, at: completionPoint)
        feedbackHandler(.recognized(trigger: trigger, signature: signature))
    }

    private func displayPoint(for point: GesturePoint) -> GesturePoint {
        point
    }

    private func showTimeoutMarker(at point: GesturePoint) {
        let appearance = GestureTrailAppearance(feedback: configurationProvider().feedback)
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
