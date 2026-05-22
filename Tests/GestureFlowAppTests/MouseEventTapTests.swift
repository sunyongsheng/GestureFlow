import CoreGraphics
import XCTest
@testable import GestureFlowApp
import GestureFlowCore

final class MouseEventTapTests: XCTestCase {
    func testNormalRightClickBelowGestureThresholdReplaysSyntheticContextClick() {
        var replayedClicks: [(GestureTrigger, GesturePoint)] = []
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(gestureThreshold: 24)

        XCTAssertEqual(
            tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))),
            .suppressEvent
        )
    }

    func testGestureDoesNotBeginUntilThresholdCrossing() {
        let tap = MouseEventTap(gestureThreshold: 24)
        var beganCount = 0
        tap.onGestureBegan = { _, _ in
            beganCount += 1
        }

        XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
        XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 20, y: 10))), .suppressEvent)

        XCTAssertEqual(beganCount, 0)
    }

    func testCrossingThresholdBeginsGestureAndFlushesBufferedPoints() {
        let tap = MouseEventTap(gestureThreshold: 24)
        var beganPoint: GesturePoint?
        var movedPoints: [GesturePoint] = []
        tap.onGestureBegan = { _, point in
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
            holdTimeoutMilliseconds: 250,
            syntheticClickPoster: { trigger, point in
                replayedClicks.append((trigger, point))
            },
            holdTimeoutScheduler: scheduler.schedule(after:action:)
        )
        tap.onGestureBegan = { _, _ in
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(
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
        let tap = MouseEventTap(gestureThreshold: 24)
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
        let tap = MouseEventTap(gestureThreshold: 24)
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
        let tap = MouseEventTap(gestureThreshold: 24)
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(gestureThreshold: 24)
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
            tap.handle(
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 1440, height: 900)] },
            desktopFrameProvider: { CGRect(x: 0, y: 0, width: 1440, height: 900) },
            syntheticClickPoster: { _, point in
                beganPoint = point
            }
        )

        XCTAssertEqual(
            tap.handle(
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
            tap.handle(
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
            tap.handle(
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
            tap.handle(
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
        let tap = MouseEventTap(gestureThreshold: 24)
        var beganCount = 0
        tap.onGestureBegan = { _, _ in
            beganCount += 1
        }

        let event = makeMouseEvent(
            type: .rightMouseDown,
            point: CGPoint(x: 50, y: 50),
            button: .right
        )
        event.setIntegerValueField(.eventSourceUserData, value: 0x47465731)

        XCTAssertEqual(
            tap.handle(type: .rightMouseDown, event: event),
            .passEvent
        )
        XCTAssertEqual(beganCount, 0)
    }

    func testStopIgnoresQueuedCGEventsAfterTeardown() {
        let tap = MouseEventTap(
            gestureThreshold: 24,
            screenFramesProvider: { [CGRect(x: 0, y: 0, width: 100, height: 100)] },
            desktopFrameProvider: { CGRect(x: 0, y: 0, width: 100, height: 100) }
        )
        var beganPoints: [GesturePoint] = []
        tap.onGestureBegan = { _, point in
            beganPoints.append(point)
        }

        XCTAssertEqual(
            tap.handle(
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
            tap.handle(
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
        let tap = MouseEventTap(
            gestureThreshold: 24,
            eventTapEnabler: { isEnabled = $0 }
        )

        XCTAssertEqual(tap.handle(.tapDisabledByTimeout), .passEvent)

        XCTAssertEqual(isEnabled, true)
    }

    func testDisabledByUserInputReEnablesEventTapAndCancelsActiveGesture() {
        var isEnabled: Bool?
        let tap = MouseEventTap(
            gestureThreshold: 24,
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
