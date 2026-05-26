import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class GestureEngineTests: XCTestCase {
    func testStartWithoutAccessibilityPermissionPromptsAndDoesNotStartTap() {
        var promptCount = 0
        let tap = SpyMouseEventTapController()
        let engine = makeEngine(
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
        let engine = makeEngine(eventTap: tap)

        engine.start()
        engine.stop()

        XCTAssertEqual(tap.startCount, 1)
        XCTAssertEqual(tap.stopCount, 1)
        XCTAssertFalse(engine.isRunning)
    }

    func testCompletedGestureRecognizesMatchesAndExecutesAction() {
        let expectedShortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: expectedShortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let engine = makeEngine(
            gestureConfiguration: gestureConfiguration,
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

        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(expectedShortcut),
                    targetProcessIdentifier: 1
                )
            ]
        )
        XCTAssertEqual(feedback, [.recognized(trigger: .rightMouse, name: "Back")])
    }

    func testAppSpecificGestureBeatsGlobalGesture() {
        let globalShortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let safariShortcut = KeyboardShortcutAction(keyCode: 124, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Global",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: globalShortcut
                ),
                GestureDefinition(
                    targetBundleIdentifier: "com.apple.Safari",
                    name: "Safari Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: safariShortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let targetResolver = SpyGestureTargetResolver(
            resolvedTarget: ResolvedGestureTarget(
                bundleIdentifier: "com.apple.Safari",
                processIdentifier: 42
            )
        )
        let engine = makeEngine(
            gestureConfiguration: gestureConfiguration,
            targetResolver: targetResolver,
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

        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(safariShortcut),
                    targetProcessIdentifier: 42
                )
            ]
        )
        XCTAssertEqual(feedback, [.recognized(trigger: .rightMouse, name: "Safari Back")])
    }

    func testUnderMousePolicyActionFailedWhenNoTarget() {
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let engine = makeEngine(
            appConfiguration: AppConfiguration(
                isEnabled: true,
                gestureTargetApplication: .underMouse
            ),
            gestureConfiguration: gestureConfiguration,
            targetResolver: SpyGestureTargetResolver(resolvedTarget: .invalid),
            eventTap: tap,
            overlay: overlay,
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

        XCTAssertTrue(actionExecutor.executedActions.isEmpty)
        XCTAssertEqual(
            overlay.events,
            [.completed(.actionFailed(displayName: "Back"), GesturePoint(x: 20, y: 0))]
        )
        XCTAssertEqual(
            feedback,
            [
                .actionFailed(
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    message: "未找到鼠标下方的应用"
                )
            ]
        )
    }

    func testUnderMousePolicyUsesTargetResolvedAtGestureStartNotGestureEnd() {
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Global",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        let targetResolver = SpyGestureTargetResolver(
            targetsByCallIndex: [
                ResolvedGestureTarget(
                    bundleIdentifier: "com.gestureflow.app",
                    processIdentifier: 999
                ),
                ResolvedGestureTarget(
                    bundleIdentifier: "com.apple.Safari",
                    processIdentifier: 42
                )
            ]
        )
        let engine = makeEngine(
            appConfiguration: AppConfiguration(
                isEnabled: true,
                gestureTargetApplication: .underMouse
            ),
            gestureConfiguration: gestureConfiguration,
            targetResolver: targetResolver,
            eventTap: tap,
            actionExecutor: actionExecutor
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 100, y: 100))
        tap.onGestureEnded?(
            .rightMouse,
            [
                GesturePoint(x: 100, y: 100),
                GesturePoint(x: 60, y: 100),
                GesturePoint(x: 20, y: 100)
            ]
        )

        XCTAssertEqual(targetResolver.resolveCallCount, 1)
        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(shortcut),
                    targetProcessIdentifier: 999
                )
            ]
        )
    }

    func testUnderMousePolicyMatchesAppUnderStartPoint() {
        let globalShortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let safariShortcut = KeyboardShortcutAction(keyCode: 124, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Global",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: globalShortcut
                ),
                GestureDefinition(
                    targetBundleIdentifier: "com.apple.Safari",
                    name: "Safari Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: safariShortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let engine = makeEngine(
            appConfiguration: AppConfiguration(
                isEnabled: true,
                gestureTargetApplication: .underMouse
            ),
            gestureConfiguration: gestureConfiguration,
            targetResolver: SpyGestureTargetResolver(
                resolvedTarget: ResolvedGestureTarget(
                    bundleIdentifier: "com.apple.Safari",
                    processIdentifier: 77
                )
            ),
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

        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(safariShortcut),
                    targetProcessIdentifier: 77
                )
            ]
        )
        XCTAssertEqual(feedback, [.recognized(trigger: .rightMouse, name: "Safari Back")])
    }

    func testCompletedGestureReportsUnmatchedSignatureWithoutExecutingAction() {
        let tap = SpyMouseEventTapController()
        let actionExecutor = SpyActionExecutor()
        var feedback: [GestureEngineFeedback] = []
        let engine = makeEngine(
            gestureConfiguration: GestureConfiguration(gestures: []),
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
        let shortcut = KeyboardShortcutAction(keyCode: 13, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Close",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.right]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor(
            error: ActionExecutionError.keyboardEventCreationFailed(keyCode: 13, isKeyDown: true)
        )
        var feedback: [GestureEngineFeedback] = []
        let engine = makeEngine(
            gestureConfiguration: gestureConfiguration,
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

        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(shortcut),
                    targetProcessIdentifier: 1
                )
            ]
        )
        XCTAssertEqual(
            overlay.events,
            [.completed(.actionFailed(displayName: "Close"), GesturePoint(x: 50, y: 0))]
        )
        XCTAssertEqual(
            feedback,
            [
                .actionFailed(
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.right]),
                    message: "Failed to create key down event for key code 13"
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
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor()
        let engine = makeEngine(
            appConfiguration: AppConfiguration(
                isEnabled: true,
                feedback: feedbackConfiguration,
                gestureTargetApplication: .foreground
            ),
            gestureConfiguration: gestureConfiguration,
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
                initialLiveFeedback(
                    at: GesturePoint(x: 100, y: 100),
                    feedback: feedbackConfiguration
                ),
                .moved(GesturePoint(x: 80, y: 100)),
                initialLiveFeedback(
                    at: GesturePoint(x: 80, y: 100),
                    feedback: feedbackConfiguration
                ),
                .completed(.recognized(name: "Back"), GesturePoint(x: 20, y: 100))
            ]
        )
        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(shortcut),
                    targetProcessIdentifier: 1
                )
            ]
        )
    }

    func testCompletionFeedbackUsesRawReleasePointNearScreenBoundary() {
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Back",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.left]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let actionExecutor = SpyActionExecutor()
        let engine = makeEngine(
            gestureConfiguration: gestureConfiguration,
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
                .completed(.recognized(name: "Back"), GesturePoint(x: 1442, y: 80))
            ]
        )
        XCTAssertEqual(
            actionExecutor.executedActions,
            [
                ExecutedActionCall(
                    action: .keyboardShortcut(shortcut),
                    targetProcessIdentifier: 1
                )
            ]
        )
    }

    func testCancelledGestureHidesOverlayWithoutFeedback() {
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        var feedback: [GestureEngineFeedback] = []
        let engine = makeEngine(
            eventTap: tap,
            overlay: overlay,
            feedbackHandler: { feedback.append($0) }
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 10, y: 10))
        tap.onGestureCancelled?()

        let beganPoint = GestureOverlayGeometry.applyHotspotOffset(to: GesturePoint(x: 10, y: 10))
        XCTAssertEqual(
            overlay.events,
            [
                .began(beganPoint, GestureTrailAppearance(feedback: .default)),
                initialLiveFeedback(at: beganPoint),
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
        let engine = makeEngine(
            appConfiguration: AppConfiguration(
                isEnabled: true,
                feedback: feedbackConfiguration,
                gestureTargetApplication: .foreground
            ),
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

    func testLiveFeedbackShowsUnrecognizedWithHighlightedTrailForPrefixMatch() {
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Close Window",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.down, .right]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let engine = makeEngine(
            gestureConfiguration: gestureConfiguration,
            eventTap: tap,
            overlay: overlay,
            feedbackHandler: { _ in }
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 100, y: 100))
        tap.onGestureMoved?(GesturePoint(x: 100, y: 50))
        tap.onGestureMoved?(GesturePoint(x: 100, y: 10))

        let lastLive = overlay.liveUpdates.last
        XCTAssertEqual(lastLive?.feedback.message, GestureFeedbackCopy.unmatchedGesture)
        XCTAssertTrue(lastLive?.feedback.showsCard ?? false)
        XCTAssertTrue(lastLive?.appearance.isHighlighted ?? false)

        tap.onGestureMoved?(GesturePoint(x: 40, y: 10))

        let brokenLive = overlay.liveUpdates.last
        XCTAssertEqual(brokenLive?.feedback.message, GestureFeedbackCopy.unmatchedGesture)
        XCTAssertFalse(brokenLive?.appearance.isHighlighted ?? true)
    }

    func testLiveFeedbackShowsGestureNameOnExactMatchBeforeRelease() {
        let shortcut = KeyboardShortcutAction(keyCode: 123, modifiers: [.command])
        let gestureConfiguration = GestureConfiguration(
            gestures: [
                GestureDefinition(
                    name: "Close Window",
                    trigger: .rightMouse,
                    signature: GestureSignature(tokens: [.down, .right]),
                    shortcut: shortcut
                )
            ]
        )
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let engine = makeEngine(
            gestureConfiguration: gestureConfiguration,
            eventTap: tap,
            overlay: overlay,
            feedbackHandler: { _ in }
        )

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 0, y: 60))
        tap.onGestureMoved?(GesturePoint(x: 0, y: 0))
        tap.onGestureMoved?(GesturePoint(x: 70, y: 0))

        let lastLive = overlay.liveUpdates.last
        XCTAssertEqual(lastLive?.feedback.message, "Close Window")
        XCTAssertTrue(lastLive?.appearance.isHighlighted ?? false)
    }

    func testStopCancelsOverlayForActiveGesture() {
        let tap = SpyMouseEventTapController()
        let overlay = SpyGestureOverlay()
        let engine = makeEngine(eventTap: tap, overlay: overlay)

        engine.start()
        tap.onGestureBegan?(.rightMouse, GesturePoint(x: 20, y: 30))
        engine.stop()

        let beganPoint = GestureOverlayGeometry.applyHotspotOffset(to: GesturePoint(x: 20, y: 30))
        XCTAssertEqual(
            overlay.events,
            [
                .began(beganPoint, GestureTrailAppearance(feedback: .default)),
                initialLiveFeedback(at: beganPoint),
                .cancelled
            ]
        )
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(tap.stopCount, 1)
    }

    private func initialLiveFeedback(
        at point: GesturePoint,
        feedback: FeedbackConfiguration = .default
    ) -> SpyGestureOverlay.Event {
        .live(
            point,
            GestureTrailAppearance(feedback: feedback, isHighlighted: false),
            LiveGestureOverlayFeedback(message: nil, showsCard: false)
        )
    }

    private func makeEngine(
        appConfiguration: AppConfiguration = AppConfiguration(
            isEnabled: true,
            gestureTargetApplication: .foreground
        ),
        gestureConfiguration: GestureConfiguration = GestureConfiguration.defaultTemplate,
        targetResolver: GestureTargetResolving = SpyGestureTargetResolver(),
        permissionService: PermissionService = PermissionService(trustCheck: { true }, permissionPrompt: {}),
        eventTap: SpyMouseEventTapController = SpyMouseEventTapController(),
        overlay: GestureOverlayDisplaying = NoopGestureOverlay(),
        actionExecutor: ActionExecuting = SpyActionExecutor(),
        feedbackHandler: @escaping (GestureEngineFeedback) -> Void = { _ in }
    ) -> GestureEngine {
        GestureEngine(
            appConfigurationProvider: { appConfiguration },
            gestureConfigurationProvider: { gestureConfiguration },
            targetResolver: targetResolver,
            permissionService: permissionService,
            eventTap: eventTap,
            overlay: overlay,
            actionExecutor: actionExecutor,
            feedbackHandler: feedbackHandler
        )
    }
}

private struct ExecutedActionCall: Equatable {
    var action: GestureAction
    var targetProcessIdentifier: pid_t?
}

private final class SpyGestureTargetResolver: GestureTargetResolving {
    private(set) var resolveCallCount = 0
    private let targetsByCallIndex: [ResolvedGestureTarget]
    private let fallbackTarget: ResolvedGestureTarget

    init(
        resolvedTarget: ResolvedGestureTarget = ResolvedGestureTarget(
            bundleIdentifier: nil,
            processIdentifier: 1
        )
    ) {
        self.targetsByCallIndex = []
        self.fallbackTarget = resolvedTarget
    }

    init(targetsByCallIndex: [ResolvedGestureTarget]) {
        self.targetsByCallIndex = targetsByCallIndex
        self.fallbackTarget = targetsByCallIndex.last
            ?? ResolvedGestureTarget(bundleIdentifier: nil, processIdentifier: 1)
    }

    func resolve(
        policy: GestureTargetApplication,
        at startPoint: GesturePoint
    ) -> ResolvedGestureTarget {
        resolveCallCount += 1
        let index = resolveCallCount - 1
        if index < targetsByCallIndex.count {
            return targetsByCallIndex[index]
        }
        return fallbackTarget
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
    struct LiveUpdate: Equatable {
        var point: GesturePoint
        var appearance: GestureTrailAppearance
        var feedback: LiveGestureOverlayFeedback
    }

    enum Event: Equatable {
        case began(GesturePoint, GestureTrailAppearance)
        case moved(GesturePoint)
        case live(GesturePoint, GestureTrailAppearance, LiveGestureOverlayFeedback)
        case completed(GestureOverlayCompletion, GesturePoint?)
        case marker(GestureOverlayMarker, GestureTrailAppearance)
        case markerCleared
        case cancelled
    }

    private(set) var events: [Event] = []

    var liveUpdates: [LiveUpdate] {
        events.compactMap { event in
            guard case let .live(point, appearance, feedback) = event else { return nil }
            return LiveUpdate(point: point, appearance: appearance, feedback: feedback)
        }
    }

    func beginGesture(at point: GesturePoint, appearance: GestureTrailAppearance) {
        events.append(.began(point, appearance))
    }

    func appendGesturePoint(_ point: GesturePoint) {
        events.append(.moved(point))
    }

    func updateLiveGesture(
        at point: GesturePoint,
        appearance: GestureTrailAppearance,
        feedback: LiveGestureOverlayFeedback
    ) {
        events.append(.live(point, appearance, feedback))
    }

    func completeGesture(
        with completion: GestureOverlayCompletion,
        at point: GesturePoint?,
        hideAfter: TimeInterval
    ) {
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
    private(set) var executedActions: [ExecutedActionCall] = []

    init(error: Error? = nil) {
        self.error = error
    }

    func execute(_ action: GestureAction, targetProcessIdentifier: pid_t?) throws {
        executedActions.append(
            ExecutedActionCall(
                action: action,
                targetProcessIdentifier: targetProcessIdentifier
            )
        )
        if let error {
            throw error
        }
    }
}
