import AppKit
import CoreGraphics
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class MouseEventTapTests: XCTestCase {
    func testNormalRightClickBelowGestureThresholdReplaysSyntheticContextClick() {
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            }
        )
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        var cancelCount = 0
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }
        tap.onGestureCancelled = {
            cancelCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 16, y: 12))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 18, y: 12))), .suppressEvent)

        XCTAssertTrue(endedGestures.isEmpty)
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 18, y: 12))
    }

    func testRightMouseDownIsSuppressedBeforeThresholdCrossing() {
        let tap = makeMouseEventTap()

        XCTAssertEqual(
            tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))),
            .suppressEvent
        )
    }

    func testGestureDoesNotBeginUntilThresholdCrossing() {
        let tap = makeMouseEventTap()
        var beganCount = 0
        tap.onGestureBegan = { _, _, _ in
            beganCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 20, y: 10))), .suppressEvent)

        XCTAssertEqual(beganCount, 0)
    }

    func testCrossingThresholdBeginsGestureAndFlushesBufferedPoints() {
        let tap = makeMouseEventTap()
        var beganPoint: GesturePoint?
        var movedPoints: [GesturePoint] = []
        tap.onGestureBegan = { _, point, _ in
            beganPoint = point
        }
        tap.onGestureMoved = { movedPoints.append($0) }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 10, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 0))), .suppressEvent)

        XCTAssertEqual(beganPoint, GesturePoint(x: 0, y: 0))
        XCTAssertEqual(movedPoints, [GesturePoint(x: 10, y: 0), GesturePoint(x: 30, y: 0)])
    }

    func testRightGestureDoesNotBeginAfterHoldTimeoutEvenIfMovementCrossesThreshold() {
        let scheduler = TestHoldTimeoutScheduler()
        var beganCount = 0
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        var timeoutPoints: [GesturePoint] = []
        var clearedTimeoutCount = 0
        let tap = makeMouseEventTap(
            holdTimeoutMilliseconds: 250,
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onGestureBegan = { _, _, _ in
            beganCount += 1
        }
        tap.onRightClickTimeout = { timeoutPoints.append($0) }
        tap.onRightClickTimeoutCleared = {
            clearedTimeoutCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        scheduler.fireLast()
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 40, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 50, y: 0))), .suppressEvent)

        XCTAssertEqual(beganCount, 0)
        XCTAssertEqual(timeoutPoints, [GesturePoint(x: 0, y: 0)])
        XCTAssertEqual(clearedTimeoutCount, 1)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 40, y: 0))
    }

    func testRightGestureBeginsBeforeHoldTimeoutWhenMovementThresholdCrossesFirst() {
        let clock = TestClock()
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        let tap = makeMouseEventTap(
            holdTimeoutMilliseconds: 250,
            nowProvider: { clock.now }
        )
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        clock.now = 0.1
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 0))), .suppressEvent)
        clock.now = 0.2
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 40, y: 0))), .suppressEvent)

        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .rightMouse)
        XCTAssertEqual(endedGestures.first?.1, [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 30, y: 0),
            GesturePoint(x: 40, y: 0)
        ])
    }

    func testCustomTriggerConfigurationControlsMovementThresholdAndHoldTimeout() {
        let clock = TestClock()
        let scheduler = TestHoldTimeoutScheduler()
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        var configuration = GestureTriggerConfiguration(
            movementThreshold: 40,
            holdTimeoutMilliseconds: 250,
            maximumSampleDistance: 120
        )
        let tap = makeMouseEventTap(
            triggerConfigurationProvider: { configuration },
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            nowProvider: { clock.now },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        clock.now = 0.1
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 30, y: 0))), .suppressEvent)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertTrue(endedGestures.isEmpty)

        replayedClicks.removeAll()
        configuration.movementThreshold = 20
        configuration.holdTimeoutMilliseconds = 150
        scheduler.reset()

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        clock.now = 0.1
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 25, y: 0))), .suppressEvent)
        clock.now = 0.12
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 35, y: 0))), .suppressEvent)

        XCTAssertEqual(replayedClicks.count, 0)
        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .rightMouse)
    }

    func testPendingRightGestureIgnoresDraggedPointWhenSampleJumpExceedsThreshold() {
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        let tap = makeMouseEventTap(
            triggerConfigurationProvider: {
                GestureTriggerConfiguration(
                    movementThreshold: 20,
                    holdTimeoutMilliseconds: 250,
                    maximumSampleDistance: 40
                )
            }
        )
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 10, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 120, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 20, y: 0))), .suppressEvent)

        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .rightMouse)
        XCTAssertEqual(endedGestures.first?.1, [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 10, y: 0),
            GesturePoint(x: 20, y: 0)
        ])
    }

    func testActiveMiddleGestureIgnoresDraggedPointWhenSampleJumpExceedsThreshold() {
        var movedPoints: [GesturePoint] = []
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        let tap = makeMouseEventTap(
            triggerConfigurationProvider: {
                GestureTriggerConfiguration(
                    movementThreshold: 10,
                    holdTimeoutMilliseconds: 250,
                    maximumSampleDistance: 40
                )
            }
        )
        tap.onGestureMoved = { movedPoints.append($0) }
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.middleMouseDown(at: GesturePoint(x: 0, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseDragged(to: GesturePoint(x: 5, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseDragged(to: GesturePoint(x: 120, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseDragged(to: GesturePoint(x: 15, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseUp(at: GesturePoint(x: 20, y: 0))), .suppressEvent)

        XCTAssertEqual(movedPoints, [
            GesturePoint(x: 5, y: 0),
            GesturePoint(x: 15, y: 0)
        ])
        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .middleMouse)
        XCTAssertEqual(endedGestures.first?.1, [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 5, y: 0),
            GesturePoint(x: 15, y: 0),
            GesturePoint(x: 20, y: 0)
        ])
    }

    func testScheduledHoldTimeoutEmitsTimeoutMarkerWithoutAdditionalInput() {
        let scheduler = TestHoldTimeoutScheduler()
        var timeoutPoints: [GesturePoint] = []
        let tap = makeMouseEventTap(
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onRightClickTimeout = { timeoutPoints.append($0) }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 12, y: 18))), .suppressEvent)
        XCTAssertEqual(timeoutPoints, [])

        scheduler.fireLast()

        XCTAssertEqual(timeoutPoints, [GesturePoint(x: 12, y: 18)])
    }

    func testTimedOutRightMouseUpClearsMarkerAndReplaysClick() {
        let scheduler = TestHoldTimeoutScheduler()
        var timeoutPoints: [GesturePoint] = []
        var clearedTimeoutCount = 0
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onRightClickTimeout = { timeoutPoints.append($0) }
        tap.onRightClickTimeoutCleared = {
            clearedTimeoutCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 15, y: 20))), .suppressEvent)
        scheduler.fireLast()
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 16, y: 20))), .suppressEvent)

        XCTAssertEqual(timeoutPoints, [GesturePoint(x: 15, y: 20)])
        XCTAssertEqual(clearedTimeoutCount, 1)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 16, y: 20))
    }

    func testPromotingPendingRightGestureCancelsScheduledHoldTimeout() {
        let scheduler = TestHoldTimeoutScheduler()
        var timeoutPoints: [GesturePoint] = []
        let tap = makeMouseEventTap(
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onRightClickTimeout = { timeoutPoints.append($0) }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 0))), .suppressEvent)

        scheduler.fireLast()

        XCTAssertTrue(timeoutPoints.isEmpty)
    }

    func testTimeoutMoveReplaysClickImmediatelyAndSuppressesRemainingRightButtonSequence() {
        let scheduler = TestHoldTimeoutScheduler()
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        var clearedTimeoutCount = 0
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onRightClickTimeoutCleared = {
            clearedTimeoutCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 12))), .suppressEvent)
        scheduler.fireLast()

        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 24, y: 18))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 22))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 32, y: 24))), .suppressEvent)

        XCTAssertEqual(clearedTimeoutCount, 1)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 24, y: 18))
    }

    func testTimeoutMoveReleasesHeldRightButtonBeforeReplayingClick() {
        let scheduler = TestHoldTimeoutScheduler()
        var eventOrder: [String] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { _, point in
                eventOrder.append("click:\(point.x),\(point.y)")
            },
            mouseButtonResetter: { trigger, point in
                XCTAssertEqual(trigger, .rightMouse)
                eventOrder.append("reset:\(point.x),\(point.y)")
            },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 12))), .suppressEvent)
        scheduler.fireLast()
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 24, y: 18))), .suppressEvent)

        XCTAssertEqual(eventOrder, ["reset:24.0,18.0", "click:24.0,18.0"])
    }

    func testNewRightMouseDownClearsStaleSuppressedTailFromPreviousTimeoutReplay() {
        let scheduler = TestHoldTimeoutScheduler()
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 12))), .suppressEvent)
        scheduler.fireLast()
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 24, y: 18))), .suppressEvent)

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 50, y: 60))), .suppressEvent)
        scheduler.fireLast()
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 82, y: 60))), .suppressEvent)

        XCTAssertEqual(replayedClicks.count, 2)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 24, y: 18))
        XCTAssertEqual(replayedClicks.last?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.last?.1, GesturePoint(x: 82, y: 60))
    }

    func testRightButtonGestureSuppressesEventsAfterEnoughMovement() {
        let tap = makeMouseEventTap()
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 50, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 60, y: 10))), .suppressEvent)

        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .rightMouse)
        XCTAssertEqual(endedGestures.first?.1.last, GesturePoint(x: 60, y: 10))
    }

    func testRightButtonGestureCompletesWithoutMouseMovedInput() {
        let tap = makeMouseEventTap()
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 40, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 70, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 90, y: 10))), .suppressEvent)

        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .rightMouse)
        XCTAssertEqual(
            endedGestures.first?.1,
            [
                GesturePoint(x: 10, y: 10),
                GesturePoint(x: 40, y: 10),
                GesturePoint(x: 70, y: 10),
                GesturePoint(x: 90, y: 10)
            ]
        )
    }

    func testFailedRightButtonGestureStillSuppressesContextMenuAfterDrawingDistance() {
        let tap = makeMouseEventTap()
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 12, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 12, y: 12))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 0, y: 12))), .suppressEvent)

        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .rightMouse)
    }

    func testMiddleButtonGestureDoesNotSuppressLaterRightClick() {
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            }
        )

        XCTAssertEqual(tap.handle(.middleMouseDown(at: GesturePoint(x: 0, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseDragged(to: GesturePoint(x: 40, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseUp(at: GesturePoint(x: 50, y: 0))), .suppressEvent)

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 10, y: 10))
    }

    func testMiddleButtonGestureCompletesWithoutMouseMovedInput() {
        let tap = makeMouseEventTap()
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }

        XCTAssertEqual(tap.handle(.middleMouseDown(at: GesturePoint(x: 0, y: 0))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseDragged(to: GesturePoint(x: 0, y: 20))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseDragged(to: GesturePoint(x: 0, y: 45))), .passEvent)
        XCTAssertEqual(tap.handle(.middleMouseUp(at: GesturePoint(x: 0, y: 60))), .suppressEvent)

        XCTAssertEqual(endedGestures.count, 1)
        XCTAssertEqual(endedGestures.first?.0, .middleMouse)
        XCTAssertEqual(
            endedGestures.first?.1,
            [
                GesturePoint(x: 0, y: 0),
                GesturePoint(x: 0, y: 20),
                GesturePoint(x: 0, y: 45),
                GesturePoint(x: 0, y: 60)
            ]
        )
    }

    func testMouseMovedDoesNotAdvanceRightButtonGestureRecognition() {
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            }
        )
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        var cancelCount = 0
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }
        tap.onGestureCancelled = {
            cancelCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .mouseMoved,
                event: makeMouseEvent(
                    type: .mouseMoved,
                    point: CGPoint(x: 40, y: 0),
                    button: .left
                )
            ),
            .passEvent
        )
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 0, y: 0))), .suppressEvent)

        XCTAssertTrue(endedGestures.isEmpty)
        XCTAssertEqual(cancelCount, 0)
        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 0, y: 0))
    }

    func testHandleTypeConvertsQuartzEventLocationIntoAppKitScreenCoordinatesForSyntheticClickReplay() {
        var beganPoint: GesturePoint?
        let tap = makeMouseEventTap(
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 1440, height: 900)] },
            desktopFrameProvider: { CGRect(x: 0, y: 0, width: 1440, height: 900) },
            syntheticClickPoster: { _, point in
                beganPoint = point
            }
        )

        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .rightMouseDown,
                event: makeMouseEvent(
                    type: .rightMouseDown,
                    point: CGPoint(x: 100, y: 100),
                    button: .right
                )
            ),
            .suppressEvent
        )
        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .rightMouseUp,
                event: makeMouseEvent(
                    type: .rightMouseUp,
                    point: CGPoint(x: 100, y: 100),
                    button: .right
                )
            ),
            .suppressEvent
        )

        XCTAssertEqual(beganPoint, GesturePoint(x: 100, y: 800))
    }

    func testHandleTypeUsesContainingScreenInsteadOfDesktopUnionForYFlip() {
        var clickPoint: GesturePoint?
        let tap = makeMouseEventTap(
            screenFramesProvider: {
                [
                    CGRect(x: -1728, y: -37, width: 1728, height: 1117),
                    CGRect(x: 0, y: 0, width: 1920, height: 1080)
                ]
            },
            desktopFrameProvider: { CGRect(x: -1728, y: -37, width: 3648, height: 1117) },
            syntheticClickPoster: { _, point in
                clickPoint = point
            }
        )

        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .rightMouseDown,
                event: makeMouseEvent(
                    type: .rightMouseDown,
                    point: CGPoint(x: 935.8, y: 469.8),
                    button: .right
                )
            ),
            .suppressEvent
        )
        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .rightMouseUp,
                event: makeMouseEvent(
                    type: .rightMouseUp,
                    point: CGPoint(x: 935.8, y: 469.8),
                    button: .right
                )
            ),
            .suppressEvent
        )

        XCTAssertEqual(clickPoint, GesturePoint(x: 935.8, y: 610.2))
    }

    func testSyntheticEventsPostedByGestureFlowPassThroughTap() {
        let tap = makeMouseEventTap()
        var beganCount = 0
        tap.onGestureBegan = { _, _, _ in
            beganCount += 1
        }

        let event = makeMouseEvent(
            type: .rightMouseDown,
            point: CGPoint(x: 50, y: 50),
            button: .right
        )
        event.setIntegerValueField(.eventSourceUserData, value: 0x47465731)

        XCTAssertEqual(
            tap.handleIncomingCGEvent(type: .rightMouseDown, event: event),
            .passEvent
        )
        XCTAssertEqual(beganCount, 0)
    }

    func testStopIgnoresQueuedCGEventsAfterTeardown() {
        let tap = makeMouseEventTap(
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 100, height: 100)] },
            desktopFrameProvider: { CGRect(x: 0, y: 0, width: 100, height: 100) }
        )
        var beganPoints: [GesturePoint] = []
        tap.onGestureBegan = { _, point, _ in
            beganPoints.append(point)
        }

        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .rightMouseDown,
                event: makeMouseEvent(
                    type: .rightMouseDown,
                    point: CGPoint(x: 10, y: 20),
                    button: .right
                )
            ),
            .suppressEvent
        )
        XCTAssertTrue(beganPoints.isEmpty)

        tap.stop()

        XCTAssertEqual(
            tap.handleIncomingCGEvent(
                type: .rightMouseDown,
                event: makeMouseEvent(
                    type: .rightMouseDown,
                    point: CGPoint(x: 20, y: 30),
                    button: .right
                )
            ),
            .passEvent
        )
        XCTAssertTrue(beganPoints.isEmpty)
    }

    func testSuppressedRightGestureReleasesMouseButtonImmediatelyForSystemStateRecovery() {
        var resets: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            mouseButtonResetter: { trigger, point in
                resets.append((trigger, point))
            }
        )

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 50, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 60, y: 10))), .suppressEvent)

        XCTAssertEqual(resets.count, 1)
        XCTAssertEqual(resets.first?.0, .rightMouse)
        XCTAssertEqual(resets.first?.1, GesturePoint(x: 60, y: 10))
    }

    func testStopDoesNotDoubleReleaseMouseButtonAfterSuppressedGestureRecoveredImmediately() {
        var resets: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            mouseButtonResetter: { trigger, point in
                resets.append((trigger, point))
            }
        )

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 50, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 60, y: 10))), .suppressEvent)
        XCTAssertEqual(resets.count, 1)

        tap.stop()

        XCTAssertEqual(resets.count, 1)
    }

    func testStopDoesNotReleaseMouseButtonAfterNormalRightClick() {
        var resets: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            mouseButtonResetter: { trigger, point in
                resets.append((trigger, point))
            }
        )

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 16, y: 12))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 18, y: 12))), .suppressEvent)

        tap.stop()

        XCTAssertTrue(resets.isEmpty)
    }

    func testShortRightClickDoesNotReleaseMouseButtonOnlyReplayClick() {
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        var resets: [(GestureTrigger, GesturePoint)] = []
        let tap = makeMouseEventTap(
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            mouseButtonResetter: { trigger, point in
                resets.append((trigger, point))
            }
        )

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 3, y: 3))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 4, y: 3))), .suppressEvent)

        XCTAssertEqual(replayedClicks.count, 1)
        XCTAssertEqual(replayedClicks.first?.0, .rightMouse)
        XCTAssertEqual(replayedClicks.first?.1, GesturePoint(x: 4, y: 3))
        XCTAssertTrue(resets.isEmpty)
    }

    func testDisabledByTimeoutReEnablesEventTapAndPassesEvent() {
        var isEnabled: Bool?
        let tap = makeMouseEventTap(
            eventTapEnabler: { isEnabled = $0 }
        )

        XCTAssertEqual(tap.handle(.tapDisabledByTimeout), .passEvent)

        XCTAssertEqual(isEnabled, true)
    }

    func testDisabledByUserInputReEnablesEventTapAndCancelsActiveGesture() {
        var isEnabled: Bool?
        let tap = makeMouseEventTap(
            eventTapEnabler: { isEnabled = $0 }
        )
        var endedGestures: [(GestureTrigger, [GesturePoint])] = []
        var cancelCount = 0
        tap.onGestureEnded = { trigger, points in
            endedGestures.append((trigger, points))
        }
        tap.onGestureCancelled = {
            cancelCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 40, y: 0))), .suppressEvent)
        XCTAssertEqual(tap.handle(.tapDisabledByUserInput), .passEvent)
        XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 50, y: 0))), .passEvent)

        XCTAssertEqual(isEnabled, true)
        XCTAssertTrue(endedGestures.isEmpty)
        XCTAssertEqual(cancelCount, 1)
    }

    func testRightMouseDownPassesThroughWhenGateReturnsFalse() {
        var timeoutCount = 0
        let tap = makeMouseEventTap(
            gestureActivationGate: { _ in nil }
        )
        tap.onRightClickTimeout = { _ in
            timeoutCount += 1
        }

        XCTAssertEqual(
            tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))),
            .passEvent
        )
        XCTAssertEqual(timeoutCount, 0)
    }

    func testMiddleMouseDownPassesThroughWhenGateReturnsFalse() {
        var beganCount = 0
        let tap = makeMouseEventTap(
            gestureActivationGate: { _ in nil }
        )
        tap.onGestureBegan = { _, _, _ in
            beganCount += 1
        }

        XCTAssertEqual(
            tap.handle(.middleMouseDown(at: GesturePoint(x: 10, y: 10))),
            .passEvent
        )
        XCTAssertEqual(beganCount, 0)
    }

    func testRightMouseDownStillSuppressesWhenGateReturnsTrue() {
        let tap = makeMouseEventTap(
            gestureActivationGate: { _ in
                ResolvedGestureTarget(bundleIdentifier: nil, processIdentifier: nil)
            }
        )

        XCTAssertEqual(
            tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))),
            .suppressEvent
        )
    }
}

private func makeMouseEventTap(
    movementThreshold: Double = 24,
    holdTimeoutMilliseconds: Int = GestureTriggerConfiguration.default.holdTimeoutMilliseconds,
    maximumSampleDistance: Double = GestureTriggerConfiguration.default.maximumSampleDistance,
    triggerConfigurationProvider: (() -> GestureTriggerConfiguration)? = nil,
    gestureActivationGate: @escaping (GesturePoint) -> ResolvedGestureTarget? = { _ in
        ResolvedGestureTarget(bundleIdentifier: nil, processIdentifier: nil)
    },
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
) -> MouseEventTap {
    let resolvedTriggerConfigurationProvider: () -> GestureTriggerConfiguration
    if let triggerConfigurationProvider {
        resolvedTriggerConfigurationProvider = triggerConfigurationProvider
    } else {
        let configuration = GestureTriggerConfiguration(
            movementThreshold: movementThreshold,
            holdTimeoutMilliseconds: holdTimeoutMilliseconds,
            maximumSampleDistance: maximumSampleDistance
        )
        resolvedTriggerConfigurationProvider = { configuration }
    }
    return MouseEventTap(
        triggerConfigurationProvider: resolvedTriggerConfigurationProvider,
        gestureActivationGate: gestureActivationGate,
        eventTapEnabler: eventTapEnabler,
        screenFramesProvider: screenFramesProvider,
        desktopFrameProvider: desktopFrameProvider,
        syntheticClickPoster: syntheticClickPoster,
        mouseButtonResetter: mouseButtonResetter,
        nowProvider: nowProvider,
        holdTimeoutScheduler: holdTimeoutScheduler
    )
}

private func makeMouseEvent(
    type: CGEventType,
    point: CGPoint,
    button: CGMouseButton
) -> CGEvent {
    guard let event = CGEvent(
        mouseEventSource: nil,
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: button
    ) else {
        fatalError("Failed to create mouse event")
    }
    return event
}

private final class TestClock {
    var now: TimeInterval = 0
}

private final class TestHoldTimeoutScheduler {
    private var scheduled: [(workItem: DispatchWorkItem, action: () -> Void)] = []

    func schedule(after _: TimeInterval, action: @escaping () -> Void) -> DispatchWorkItem {
        let workItem = DispatchWorkItem(block: {})
        scheduled.append((workItem, action))
        return workItem
    }

    func fireLast() {
        guard let last = scheduled.last else { return }
        guard !last.workItem.isCancelled else { return }
        last.action()
    }

    func reset() {
        scheduled.removeAll()
    }
}
