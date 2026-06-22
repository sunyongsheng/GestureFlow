import AppKit
import CoreGraphics
import Foundation
import GestureFlowCore

enum MouseEventTapDecision: Equatable {
    case passEvent
    case suppressEvent
}

enum MouseEventTapInput: Equatable {
    case rightMouseDown(at: GesturePoint)
    case rightMouseDragged(to: GesturePoint)
    case rightMouseUp(at: GesturePoint)
    case middleMouseDown(at: GesturePoint)
    case middleMouseDragged(to: GesturePoint)
    case middleMouseUp(at: GesturePoint)
    case tapDisabledByTimeout
    case tapDisabledByUserInput
}

protocol MouseEventTapControlling: AnyObject {
    var onGestureBegan: ((GestureTrigger, GesturePoint, ResolvedGestureTarget) -> Void)? { get set }
    var onGestureMoved: ((GesturePoint) -> Void)? { get set }
    var onGestureEnded: ((GestureTrigger, [GesturePoint]) -> Void)? { get set }
    var onGestureCancelled: (() -> Void)? { get set }
    var onRightClickTimeout: ((GesturePoint) -> Void)? { get set }
    var onRightClickTimeoutCleared: (() -> Void)? { get set }

    func start() -> Bool
    func stop()
}

final class MouseEventTap: MouseEventTapControlling {
    private static let syntheticEventSignature: Int64 = 0x47465731

    var onGestureBegan: ((GestureTrigger, GesturePoint, ResolvedGestureTarget) -> Void)?
    var onGestureMoved: ((GesturePoint) -> Void)?
    var onGestureEnded: ((GestureTrigger, [GesturePoint]) -> Void)?
    var onGestureCancelled: (() -> Void)?
    var onRightClickTimeout: ((GesturePoint) -> Void)?
    var onRightClickTimeoutCleared: (() -> Void)?

    private let triggerConfigurationProvider: () -> GestureTriggerConfiguration
    private let gestureActivationGate: (GesturePoint) -> ResolvedGestureTarget?
    private let eventTapEnabler: (Bool) -> Void
    private let screenFramesProvider: () -> [CGRect]
    private let desktopFrameProvider: () -> CGRect
    private let syntheticClickPoster: (GestureTrigger, GesturePoint) -> Void
    private let mouseButtonResetter: (GestureTrigger, GesturePoint) -> Void
    private let nowProvider: () -> TimeInterval
    private let holdTimeoutScheduler: (TimeInterval, @escaping () -> Void) -> DispatchWorkItem
    private var pendingRightClick: PendingRightClick?
    private var activeGesture: ActiveGesture?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var acceptsCGEvents = true
    private var pendingMouseButtonReset: PendingMouseButtonReset?
    private var pendingRightClickTimeoutWorkItem: DispatchWorkItem?
    private var suppressRightMouseSequenceUntilUp = false
    private var isRightClickTimeoutActive = false

    init(
        triggerConfigurationProvider: @escaping () -> GestureTriggerConfiguration,
        gestureActivationGate: @escaping (GesturePoint) -> ResolvedGestureTarget?,
        eventTapEnabler: @escaping (Bool) -> Void = { _ in },
        screenFramesProvider: @escaping () -> [CGRect] = {
            NSScreen.screens.map(\.frame)
        },
        desktopFrameProvider: @escaping () -> CGRect = {
            NSScreen.screens
                .map(\.frame)
                .reduce(NSScreen.main?.frame ?? .zero) { partial, frame in
                    partial.union(frame)
                }
        },
        syntheticClickPoster: ((GestureTrigger, GesturePoint) -> Void)? = nil,
        mouseButtonResetter: ((GestureTrigger, GesturePoint) -> Void)? = nil,
        nowProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        holdTimeoutScheduler: @escaping (TimeInterval, @escaping () -> Void) -> DispatchWorkItem = { delay, action in
            let workItem = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            return workItem
        }
    ) {
        let resolvedSyntheticClickPoster = syntheticClickPoster
            ?? MouseEventTap.makeSyntheticClickPoster(
                screenFramesProvider: screenFramesProvider,
                desktopFrameProvider: desktopFrameProvider
            )
        let resolvedMouseButtonResetter = mouseButtonResetter
            ?? MouseEventTap.makeMouseButtonResetter(
                screenFramesProvider: screenFramesProvider,
                desktopFrameProvider: desktopFrameProvider
            )
        self.syntheticClickPoster = resolvedSyntheticClickPoster
        self.mouseButtonResetter = resolvedMouseButtonResetter
        self.triggerConfigurationProvider = triggerConfigurationProvider
        self.gestureActivationGate = gestureActivationGate
        self.eventTapEnabler = eventTapEnabler
        self.screenFramesProvider = screenFramesProvider
        self.desktopFrameProvider = desktopFrameProvider
        self.nowProvider = nowProvider
        self.holdTimeoutScheduler = holdTimeoutScheduler
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = [
            CGEventType.rightMouseDown,
            .rightMouseDragged,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseDragged,
            .otherMouseUp
        ].reduce(CGEventMask(0)) { result, type in
            result | (CGEventMask(1) << type.rawValue)
        }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let tap = Unmanaged<MouseEventTap>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            let decision = tap.handleIncomingCGEvent(type: type, event: event)
            return decision == .suppressEvent ? nil : Unmanaged.passUnretained(event)
        }

        guard let createdTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0) else {
            CFMachPortInvalidate(createdTap)
            return false
        }

        eventTap = createdTap
        runLoopSource = source
        acceptsCGEvents = true
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        setEventTapEnabled(true)
        return true
    }

    func stop() {
        let buttonReset = pendingMouseButtonReset
            ?? activeGesture.flatMap { gesture in
                gesture.points.last.map {
                    PendingMouseButtonReset(trigger: gesture.trigger, point: $0)
                }
            }
            ?? pendingRightClick?.points.last.map {
                PendingMouseButtonReset(trigger: .rightMouse, point: $0)
            }
        acceptsCGEvents = false
        cancelPendingRightClickTimeout()

        if let eventTap {
            setEventTapEnabled(false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        pendingRightClick = nil
        activeGesture = nil
        pendingMouseButtonReset = nil
        suppressRightMouseSequenceUntilUp = false
        clearRightClickTimeoutIfNeeded()
        buttonReset.map(releaseMouseButtonIfNeeded)
    }

    func handle(_ input: MouseEventTapInput) -> MouseEventTapDecision {
        switch input {
        case let .rightMouseDown(point):
            return beginPendingRightClick(at: point)
        case let .rightMouseDragged(point):
            return moveRightGesture(to: point)
        case let .rightMouseUp(point):
            return endRightGesture(at: point)
        case let .middleMouseDown(point):
            return begin(trigger: .middleMouse, at: point)
        case let .middleMouseDragged(point):
            return move(to: point)
        case let .middleMouseUp(point):
            return end(trigger: .middleMouse, at: point)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            return recoverFromDisabledEvent()
        }
    }

    func handleIncomingCGEvent(type: CGEventType, event: CGEvent) -> MouseEventTapDecision {
        guard acceptsCGEvents else { return .passEvent }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventSignature {
            return .passEvent
        }
        guard let input = semanticInput(from: type, event: event) else {
            return .passEvent
        }
        return handle(input)
    }

    private func semanticInput(from type: CGEventType, event: CGEvent) -> MouseEventTapInput? {
        let point = appKitScreenPoint(from: event.location)

        switch type {
        case .rightMouseDown:
            return .rightMouseDown(at: point)
        case .rightMouseDragged:
            return .rightMouseDragged(to: point)
        case .rightMouseUp:
            return .rightMouseUp(at: point)
        case .otherMouseDown where event.mouseButtonNumber == 2:
            return .middleMouseDown(at: point)
        case .otherMouseDragged where activeGesture?.trigger == .middleMouse:
            return .middleMouseDragged(to: point)
        case .otherMouseUp where event.mouseButtonNumber == 2:
            return .middleMouseUp(at: point)
        case .tapDisabledByTimeout:
            return .tapDisabledByTimeout
        case .tapDisabledByUserInput:
            return .tapDisabledByUserInput
        default:
            return nil
        }
    }

    private func beginPendingRightClick(at point: GesturePoint) -> MouseEventTapDecision {
        guard let resolvedTarget = gestureActivationGate(point) else {
            return .passEvent
        }

        suppressRightMouseSequenceUntilUp = false
        clearRightClickTimeoutIfNeeded()
        pendingRightClick = PendingRightClick(
            origin: point,
            points: [point],
            beganAt: nowProvider(),
            exceededHoldTimeout: false,
            resolvedTarget: resolvedTarget
        )
        pendingMouseButtonReset = nil
        schedulePendingRightClickTimeout()
        return .suppressEvent
    }

    private func moveRightGesture(to point: GesturePoint) -> MouseEventTapDecision {
        if suppressRightMouseSequenceUntilUp {
            return .suppressEvent
        }

        if var gesture = activeGesture, gesture.trigger == .rightMouse {
            guard shouldAcceptSample(point, after: gesture.points) else {
                return .suppressEvent
            }
            gesture.points.append(point)
            activeGesture = gesture
            onGestureMoved?(point)
            return .suppressEvent
        }

        guard var pending = pendingRightClick else { return .passEvent }
        guard shouldAcceptSample(point, after: pending.points) else {
            return .suppressEvent
        }
        pending.points.append(point)

        if pendingHasExceededHoldTimeout(&pending) {
            cancelPendingRightClickTimeout()
            pendingRightClick = nil
            suppressRightMouseSequenceUntilUp = true
            clearRightClickTimeoutIfNeeded()
            replaySyntheticRightClickDuringHeldSequence(at: point)
            return .suppressEvent
        }

        pendingRightClick = pending

        guard pathLength(of: pending.points) >= currentTriggerConfiguration().movementThreshold else {
            return .suppressEvent
        }

        cancelPendingRightClickTimeout()
        pendingRightClick = nil
        promotePendingRightClickToGesture(pending)
        return .suppressEvent
    }

    private func endRightGesture(at point: GesturePoint) -> MouseEventTapDecision {
        if suppressRightMouseSequenceUntilUp {
            suppressRightMouseSequenceUntilUp = false
            return .suppressEvent
        }

        if var gesture = activeGesture, gesture.trigger == .rightMouse {
            if shouldAcceptSample(point, after: gesture.points) {
                gesture.points.append(point)
            }
            activeGesture = nil
            clearRightClickTimeoutIfNeeded()
            finishConsumedGesture(
                trigger: .rightMouse,
                points: gesture.points,
                releasePoint: gesture.points.last ?? point
            )
            return .suppressEvent
        }

        guard var pending = pendingRightClick else {
            if isRightClickTimeoutActive {
                clearRightClickTimeoutIfNeeded()
                syntheticClickPoster(.rightMouse, point)
                return .suppressEvent
            }
            return .passEvent
        }
        cancelPendingRightClickTimeout()
        if shouldAcceptSample(point, after: pending.points) {
            pending.points.append(point)
        }
        pendingRightClick = nil

        if pendingHasExceededHoldTimeout(&pending) {
            clearRightClickTimeoutIfNeeded()
            syntheticClickPoster(.rightMouse, pending.points.last ?? point)
            return .suppressEvent
        }

        if pathLength(of: pending.points) >= currentTriggerConfiguration().movementThreshold {
            onGestureBegan?(.rightMouse, pending.points[0], pending.resolvedTarget)
            if pending.points.count > 2 {
                for bufferedPoint in pending.points.dropFirst().dropLast() {
                    onGestureMoved?(bufferedPoint)
                }
            }
            finishConsumedGesture(trigger: .rightMouse, points: pending.points, releasePoint: point)
            return .suppressEvent
        }

        syntheticClickPoster(.rightMouse, pending.points.last ?? point)
        return .suppressEvent
    }

    private func promotePendingRightClickToGesture(_ pending: PendingRightClick) {
        activeGesture = ActiveGesture(
            trigger: .rightMouse,
            points: pending.points,
            resolvedTarget: pending.resolvedTarget
        )
        onGestureBegan?(.rightMouse, pending.points[0], pending.resolvedTarget)
        for bufferedPoint in pending.points.dropFirst() {
            onGestureMoved?(bufferedPoint)
        }
    }

    private func finishConsumedGesture(
        trigger: GestureTrigger,
        points: [GesturePoint],
        releasePoint: GesturePoint
    ) {
        let buttonReset = PendingMouseButtonReset(trigger: trigger, point: releasePoint)
        pendingMouseButtonReset = buttonReset
        onGestureEnded?(trigger, points)
        releaseMouseButtonIfNeeded(buttonReset)
        pendingMouseButtonReset = nil
    }

    private func begin(trigger: GestureTrigger, at point: GesturePoint) -> MouseEventTapDecision {
        guard let resolvedTarget = gestureActivationGate(point) else {
            return .passEvent
        }

        if pendingMouseButtonReset?.trigger == trigger {
            pendingMouseButtonReset = nil
        }
        activeGesture = ActiveGesture(trigger: trigger, points: [point], resolvedTarget: resolvedTarget)
        onGestureBegan?(trigger, point, resolvedTarget)
        return .passEvent
    }

    private func move(to point: GesturePoint) -> MouseEventTapDecision {
        guard var gesture = activeGesture else { return .passEvent }
        guard shouldAcceptSample(point, after: gesture.points) else {
            return .passEvent
        }
        gesture.points.append(point)
        activeGesture = gesture
        onGestureMoved?(point)
        return .passEvent
    }

    private func end(trigger: GestureTrigger, at point: GesturePoint) -> MouseEventTapDecision {
        guard var gesture = activeGesture, gesture.trigger == trigger else {
            if activeGesture != nil {
                activeGesture = nil
                onGestureCancelled?()
            }
            return .passEvent
        }

        if shouldAcceptSample(point, after: gesture.points) {
            gesture.points.append(point)
        }
        activeGesture = nil

        guard pathLength(of: gesture.points) >= currentTriggerConfiguration().movementThreshold else {
            onGestureCancelled?()
            return .passEvent
        }

        let buttonReset = PendingMouseButtonReset(trigger: trigger, point: gesture.points.last ?? point)
        pendingMouseButtonReset = buttonReset
        onGestureEnded?(trigger, gesture.points)
        releaseMouseButtonIfNeeded(buttonReset)
        pendingMouseButtonReset = nil
        return .suppressEvent
    }

    private func pathLength(of points: [GesturePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }

    private func shouldAcceptSample(_ point: GesturePoint, after acceptedPoints: [GesturePoint]) -> Bool {
        guard let lastPoint = acceptedPoints.last else { return true }
        let maximumDistance = currentTriggerConfiguration().maximumSampleDistance
        guard maximumDistance > 0 else { return true }
        return hypot(point.x - lastPoint.x, point.y - lastPoint.y) <= maximumDistance
    }

    private func recoverFromDisabledEvent() -> MouseEventTapDecision {
        if activeGesture != nil || pendingRightClick != nil {
            onGestureCancelled?()
        }
        cancelPendingRightClickTimeout()
        pendingRightClick = nil
        activeGesture = nil
        suppressRightMouseSequenceUntilUp = false
        clearRightClickTimeoutIfNeeded()
        setEventTapEnabled(true)
        return .passEvent
    }

    private func setEventTapEnabled(_ isEnabled: Bool) {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: isEnabled)
        }
        eventTapEnabler(isEnabled)
    }

    private func releaseMouseButtonIfNeeded(_ reset: PendingMouseButtonReset) {
        mouseButtonResetter(reset.trigger, reset.point)
    }

    private func replaySyntheticRightClickDuringHeldSequence(at point: GesturePoint) {
        let reset = PendingMouseButtonReset(trigger: .rightMouse, point: point)
        releaseMouseButtonIfNeeded(reset)
        syntheticClickPoster(.rightMouse, point)
    }

    private func currentTriggerConfiguration() -> GestureTriggerConfiguration {
        triggerConfigurationProvider()
    }

    private func pendingHasExceededHoldTimeout(_ pending: inout PendingRightClick) -> Bool {
        guard !pending.exceededHoldTimeout else { return true }

        let elapsedMilliseconds = (nowProvider() - pending.beganAt) * 1000
        let hasExceededTimeout = elapsedMilliseconds > Double(currentTriggerConfiguration().holdTimeoutMilliseconds)
        if hasExceededTimeout {
            pending.exceededHoldTimeout = true
        }
        return hasExceededTimeout
    }

    private func schedulePendingRightClickTimeout() {
        cancelPendingRightClickTimeout()
        let delay = Double(currentTriggerConfiguration().holdTimeoutMilliseconds) / 1000
        pendingRightClickTimeoutWorkItem = holdTimeoutScheduler(delay) { [weak self] in
            self?.handlePendingRightClickTimeout()
        }
    }

    private func cancelPendingRightClickTimeout() {
        pendingRightClickTimeoutWorkItem?.cancel()
        pendingRightClickTimeoutWorkItem = nil
    }

    private func handlePendingRightClickTimeout() {
        guard var pending = pendingRightClick else { return }
        guard !pending.exceededHoldTimeout else { return }

        pending.exceededHoldTimeout = true
        pendingRightClick = pending
        isRightClickTimeoutActive = true
        onRightClickTimeout?(pending.origin)
    }

    private func clearRightClickTimeoutIfNeeded() {
        guard isRightClickTimeoutActive else { return }
        isRightClickTimeoutActive = false
        onRightClickTimeoutCleared?()
    }

    private func appKitScreenPoint(from quartzPoint: CGPoint) -> GesturePoint {
        let mainScreenHeight = Self.mainScreenHeight(from: screenFramesProvider())
        let appKitY = mainScreenHeight - quartzPoint.y
        return GesturePoint(x: quartzPoint.x, y: appKitY)
    }

    private static func mainScreenHeight(from screenFrames: [CGRect]) -> CGFloat {
        screenFrames.first(where: { $0.origin == .zero })?.height
            ?? screenFrames.first?.height
            ?? 0
    }

    private static func makeMouseButtonResetter(
        screenFramesProvider: @escaping () -> [CGRect],
        desktopFrameProvider: @escaping () -> CGRect
    ) -> (GestureTrigger, GesturePoint) -> Void {
        { trigger, point in
            let mainScreenHeight = mainScreenHeight(from: screenFramesProvider())
            let quartzPoint = CGPoint(
                x: point.x,
                y: mainScreenHeight - point.y
            )

            let mouseType: CGEventType
            let mouseButton: CGMouseButton
            switch trigger {
            case .rightMouse:
                mouseType = .rightMouseUp
                mouseButton = .right
            case .middleMouse:
                mouseType = .otherMouseUp
                mouseButton = .center
            }

            guard let event = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseType,
                mouseCursorPosition: quartzPoint,
                mouseButton: mouseButton
            ) else {
                return
            }

            event.setIntegerValueField(.eventSourceUserData, value: syntheticEventSignature)
            event.post(tap: .cghidEventTap)
        }
    }

    private static func makeSyntheticClickPoster(
        screenFramesProvider: @escaping () -> [CGRect],
        desktopFrameProvider: @escaping () -> CGRect
    ) -> (GestureTrigger, GesturePoint) -> Void {
        { trigger, point in
            guard trigger == .rightMouse else { return }

            let mainScreenHeight = mainScreenHeight(from: screenFramesProvider())
            let quartzPoint = CGPoint(
                x: point.x,
                y: mainScreenHeight - point.y
            )

            let eventTypes: [CGEventType] = [.rightMouseDown, .rightMouseUp]
            for eventType in eventTypes {
                guard let event = CGEvent(
                    mouseEventSource: nil,
                    mouseType: eventType,
                    mouseCursorPosition: quartzPoint,
                    mouseButton: .right
                ) else {
                    continue
                }

                event.setIntegerValueField(.eventSourceUserData, value: syntheticEventSignature)
                event.post(tap: .cghidEventTap)
            }
        }
    }
}

private struct ActiveGesture {
    var trigger: GestureTrigger
    var points: [GesturePoint]
    var resolvedTarget: ResolvedGestureTarget
}

private struct PendingRightClick {
    var origin: GesturePoint
    var points: [GesturePoint]
    var beganAt: TimeInterval
    var exceededHoldTimeout: Bool
    var resolvedTarget: ResolvedGestureTarget
}

private struct PendingMouseButtonReset {
    var trigger: GestureTrigger
    var point: GesturePoint
}

private extension CGEvent {
    var mouseButtonNumber: Int64 {
        getIntegerValueField(.mouseEventButtonNumber)
    }
}
