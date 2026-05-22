import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureEngineTests: XCTestCase {
    func testStartWithoutAccessibilityPermissionPromptsAndDoesNotStartTap() {
        var promptCount = 0
        let tap = SpyMouseEventTapController()
        let engine = GestureEngine(
            configurationProvider: { AppConfiguration() },
            permissionService: PermissionService(
                trustCheck: { false },
                permissionPrompt: { promptCount += 1 }
            ),
            eventTap: tap
        )

        engine.start()

        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(tap.startCount, 0)
        XCTAssertFalse(engine.isRunning)
    }

    func testStartWithAccessibilityPermissionStartsTapAndStopStopsTap() {
        let tap = SpyMouseEventTapController()
        let engine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap
        )

        engine.start()
        engine.stop()

        XCTAssertEqual(tap.startCount, 1)
        XCTAssertEqual(tap.stopCount, 1)
        XCTAssertFalse(engine.isRunning)
    }

    func testCompletedGestureRecognizesMatchesAndExecutesAction() {
        let expectedAction = GestureAction.keyboardShortcut(
            KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        )
        let configuration = AppConfiguration(
            isEnabled: true,
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    action: expectedAction
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let engine = GestureEngine(
            configurationProvider: { configuration },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            actionExecutor: actionExecutor,
            feedbackHandler: { feedback.append($0) }
        )

        engine.start()
        tap.onGestureEnded?(
            .rightMouse,
            [
                GesturePoint(x: 100, y: 0),
                GesturePoint(x: 60, y: 0),
                GesturePoint(x: 20, y: 0)
            ]
        )

        XCTAssertEqual(actionExecutor.executedActions, [expectedAction])
        XCTAssertEqual(feedback, [.recognized(trigger: .rightMouse, signature: GestureSignature(tokens: [.left]))])
    }

    func testCompletedGestureReportsUnmatchedSignatureWithoutExecutingAction() {
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let engine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true, gestures: []) },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            actionExecutor: actionExecutor,
            feedbackHandler: { feedback.append($0) }
        )

        engine.start()
        tap.onGestureEnded?(
            .rightMouse,
            [
                GesturePoint(x: 0, y: 0),
                GesturePoint(x: 50, y: 0)
            ]
        )

        XCTAssertTrue(actionExecutor.executedActions.isEmpty)
        XCTAssertEqual(feedback, [.unmatched(trigger: .rightMouse, signature: GestureSignature(tokens: [.right]))])
    }

    func testCompletedGestureReportsActionFailureWithoutRecognizedFeedback() {
        let expectedAction = GestureAction.openURL(
            OpenURLAction(url: URL(string: "https://example.com")!)
        )
        let configuration = AppConfiguration(
            isEnabled: true,
            gestures: [
                GestureDefinition(
                    name: "Docs",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.right]),
                    action: expectedAction
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor(
            error: ActionExecutionError.urlOpenFailed(URL(string: "https://example.com")!)
        )
        var feedback: [GestureEngineFeedback] = []
        let engine = GestureEngine(
            configurationProvider: { configuration },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            overlay: overlay,
            actionExecutor: actionExecutor,
            feedbackHandler: { feedback.append($0) }
        )

        engine.start()
        tap.onGestureEnded?(
            .rightMouse,
            [
                GesturePoint(x: 0, y: 0),
                GesturePoint(x: 50, y: 0)
            ]
        )

        XCTAssertEqual(actionExecutor.executedActions, [expectedAction])
        XCTAssertEqual(overlay.events, [.completed(.actionFailed, GesturePoint(x: 50, y: 0))])
        XCTAssertEqual(
            feedback,
            [
                .actionFailed(
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.right]),
                    message: "Failed to open URL: https://example.com"
                )
            ]
        )
    }

    func testGestureLifecycleUpdatesOverlayUsingFeedbackConfigurationAndRawPoints() {
        let feedbackConfiguration = FeedbackConfiguration(
            trailColorHex: "#FF00AA",
            trailWidth: 7,
            trailOpacity: 0.4
        )
        let configuration = AppConfiguration(
            isEnabled: true,
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    action: .systemCommand(.showDesktop)
                )
            ],
            feedback: feedbackConfiguration
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor()
        let engine = GestureEngine(
            configurationProvider: { configuration },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            overlay: overlay,
            actionExecutor: actionExecutor,
            feedbackHandler: { _ in }
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 100, y: 100))
        tap.onGestureMoved?(GesturePoint(x: 80, y: 100))
        tap.onGestureEnded?(
            .rightMouse,
            [
                GesturePoint(x: 100, y: 100),
                GesturePoint(x: 80, y: 100),
                GesturePoint(x: 20, y: 100)
            ]
        )

        XCTAssertEqual(
            overlay.events,
            [
                .began(
                    GesturePoint(x: 100, y: 100),
                    GestureTrailAppearance(feedback: feedbackConfiguration)
                ),
                .moved(GesturePoint(x: 80, y: 100)),
                .completed(.recognized, GesturePoint(x: 20, y: 100))
            ]
        )
        XCTAssertEqual(actionExecutor.executedActions, [.systemCommand(.showDesktop)])
    }

    func testCompletionFeedbackUsesRawReleasePointNearScreenBoundary() {
        let configuration = AppConfiguration(
            isEnabled: true,
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    action: .systemCommand(.showDesktop)
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor()
        let engine = GestureEngine(
            configurationProvider: { configuration },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            overlay: overlay,
            actionExecutor: actionExecutor,
            feedbackHandler: { _ in }
        )

        engine.start()
        tap.onGestureEnded?(
            .rightMouse,
            [
                GesturePoint(x: 1500, y: 80),
                GesturePoint(x: 1444, y: 80),
                GesturePoint(x: 1442, y: 80)
            ]
        )

        XCTAssertEqual(
            overlay.events,
            [
                .completed(.recognized, GesturePoint(x: 1442, y: 80))
            ]
        )
        XCTAssertEqual(actionExecutor.executedActions, [.systemCommand(.showDesktop)])
    }

    func testCancelledGestureHidesOverlayWithoutFeedback() {
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        var feedback: [GestureEngineFeedback] = []
        let engine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            overlay: overlay,
            feedbackHandler: { feedback.append($0) }
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 10, y: 10))
        tap.onGestureCancelled?()

        XCTAssertEqual(
            overlay.events,
            [
                .began(
                    GestureOverlayGeometry.applyHotspotOffset(to: GesturePoint(x: 10, y: 10)),
                    GestureTrailAppearance(feedback: .default)
                ),
                .cancelled
            ]
        )
        XCTAssertTrue(feedback.isEmpty)
    }

    func testRightClickTimeoutShowsAndClearsMarkerWithoutGestureCompletion() {
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let feedbackConfiguration = FeedbackConfiguration(
            trailColorHex: "#3366FF",
            trailWidth: 5,
            trailOpacity: 0.5
        )
        let engine = GestureEngine(
            configurationProvider: {
                AppConfiguration(isEnabled: true, feedback: feedbackConfiguration)
            },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            overlay: overlay,
            feedbackHandler: { _ in }
        )

        engine.start()
        tap.onRightClickTimeout?(GesturePoint(x: 40, y: 50))
        tap.onRightClickTimeoutCleared?()

        XCTAssertEqual(
            overlay.events,
            [
                .marker(
                    GestureOverlayMarker(point: GesturePoint(x: 40, y: 50), style: .timeoutOrigin),
                    GestureTrailAppearance(feedback: feedbackConfiguration)
                ),
                .markerCleared
            ]
        )
    }

    func testStopCancelsOverlayForActiveGesture() {
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let engine = GestureEngine(
            configurationProvider: { AppConfiguration(isEnabled: true) },
            permissionService: PermissionService(trustCheck: { true }, permissionPrompt: {}),
            eventTap: tap,
            overlay: overlay
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 20, y: 30))
        engine.stop()

        XCTAssertEqual(
            overlay.events,
            [
                .began(
                    GestureOverlayGeometry.applyHotspotOffset(to: GesturePoint(x: 20, y: 30)),
                    GestureTrailAppearance(feedback: .default)
                ),
                .cancelled
            ]
        )
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(tap.stopCount, 1)
    }
}

private final class SpyMouseEventTapController: MouseEventTapControlling {
    var onGestureBegan: ((GestureTrigger, GesturePoint) -> Void)?
    var onGestureMoved: ((GesturePoint) -> Void)?
    var onGestureEnded: ((GestureTrigger, [GesturePoint]) -> Void)?
    var onGestureCancelled: (() -> Void)?
    var onRightClickTimeout: ((GesturePoint) -> Void)?
    var onRightClickTimeoutCleared: (() -> Void)?

    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() -> Bool {
        startCount += 1
        return true
    }

    func stop() {
        stopCount += 1
    }
}

private final class SpyGestureOverlay: GestureOverlayDisplaying {
    enum Event: Equatable {
        case began(GesturePoint, GestureTrailAppearance)
        case moved(GesturePoint)
        case completed(GestureOverlayCompletion, GesturePoint?)
        case marker(GestureOverlayMarker, GestureTrailAppearance)
        case markerCleared
        case cancelled
    }

    private(set) var events: [Event] = []

    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance) {
        events.append(.began(point, appearance))
    }

    func appendGesturePoint(_ point: GesturePoint) {
        events.append(.moved(point))
    }

    func completeGesture(with completion: GestureOverlayCompletion, at point: GesturePoint?) {
        events.append(.completed(completion, point))
    }

    func showMarker(_ marker: GestureOverlayMarker, appearance: GestureTrailAppearance) {
        events.append(.marker(marker, appearance))
    }

    func clearMarker() {
        events.append(.markerCleared)
    }

    func cancelGesture() {
        events.append(.cancelled)
    }
}

private final class SpyActionExecutor: ActionExecuting {
    private let error: Error?
    private(set) var executedActions: [GestureAction] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func execute(_ action: GestureAction) throws {
        executedActions.append(action)
        if let error {
            throw error
        }
    }
}
