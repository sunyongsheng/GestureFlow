# Right Click Preemptive Interception Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent right-button gestures from leaking context-click events to the target app while preserving normal short right-click behavior, while also rejecting long presses that exceed a configurable hold timeout before movement threshold crossing and showing a persistent red timeout marker until release.

**Architecture:** Move `MouseEventTap` from an immediate-gesture model to a pending-right-click model. Suppress `rightMouseDown` up front, promote buffered input into a gesture only after crossing the configured movement threshold before the configurable hold timeout elapses, and replay a synthetic normal right click when the interaction ends below threshold or times out. When the pending interaction times out, emit a dedicated timeout feedback event and render a red marker through the existing overlay stack until `rightMouseUp`. Store both thresholds in `AppConfiguration.trigger` and expose them in the settings window.

**Tech Stack:** Swift, AppKit, CoreGraphics, XCTest

---

## Chunk 1: Configurable Trigger Model

### Task 1: Add trigger configuration and preserve backward compatibility

**Files:**
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Modify: `Sources/GestureFlowCore/Configuration/ConfigurationStore.swift`
- Modify: `Tests/GestureFlowCoreTests/ConfigurationStoreTests.swift`
- Modify: `Tests/GestureFlowCoreTests/PublicAPITests.swift`

- [ ] Add `GestureTriggerConfiguration` with:
  - `movementThreshold`
  - `holdTimeoutMilliseconds`
- [ ] Store it on `AppConfiguration` as `trigger`
- [ ] Keep legacy configuration decoding backward compatible by defaulting missing trigger fields
- [ ] Add tests covering public construction and legacy config loading

## Chunk 2: Pending Right Click State

### Task 1: Add failing tests for deferred gesture start

**Files:**
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`

- [ ] **Step 1: Write the failing test**

```swift
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
    tap.onGestureBegan = { _, _ in beganCount += 1 }

    XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
    XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 20, y: 10))), .suppressEvent)

    XCTAssertEqual(beganCount, 0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MouseEventTapTests`
Expected: FAIL because current implementation passes `rightMouseDown` through and starts the gesture immediately.

- [ ] **Step 3: Write minimal implementation**

```swift
private struct PendingRightClick {
    var trigger: GestureTrigger
    var startPoint: GesturePoint
    var bufferedPoints: [GesturePoint]
}
```

Track a pending right-click state and return `.suppressEvent` for `rightMouseDown`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MouseEventTapTests`
Expected: PASS for the new tests.

- [ ] **Step 5: Commit**

```bash
git add Tests/GestureFlowAppTests/MouseEventTapTests.swift Sources/GestureFlowApp/EventTap/MouseEventTap.swift
git commit -m "test: defer right gesture start until threshold"
```

### Task 2: Promote pending click into a real gesture

**Files:**
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testCrossingThresholdBeginsGestureAndFlushesBufferedPoints() {
    let tap = MouseEventTap(gestureThreshold: 24)
    var beganPoint: GesturePoint?
    var movedPoints: [GesturePoint] = []
    tap.onGestureBegan = { _, point in beganPoint = point }
    tap.onGestureMoved = { movedPoints.append($0) }

    XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
    XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 10, y: 0))), .suppressEvent)
    XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 0))), .suppressEvent)

    XCTAssertEqual(beganPoint, GesturePoint(x: 0, y: 0))
    XCTAssertEqual(movedPoints, [GesturePoint(x: 10, y: 0), GesturePoint(x: 30, y: 0)])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MouseEventTapTests/testCrossingThresholdBeginsGestureAndFlushesBufferedPoints`
Expected: FAIL until buffered points are replayed through the normal callbacks.

- [ ] **Step 3: Write minimal implementation**

Implement threshold-crossing promotion:

```swift
private func promotePendingClickToGesture(_ pending: PendingRightClick) {
    onGestureBegan?(pending.trigger, pending.startPoint)
    for point in pending.bufferedPoints.dropFirst() {
        onGestureMoved?(point)
    }
}
```

Wire this into `rightMouseDragged`.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MouseEventTapTests`
Expected: PASS for promotion tests and existing gesture tests.

- [ ] **Step 5: Commit**

```bash
git add Tests/GestureFlowAppTests/MouseEventTapTests.swift Sources/GestureFlowApp/EventTap/MouseEventTap.swift
git commit -m "feat: promote pending right click into gesture"
```

## Chunk 3: Timeout Downgrade and Replay Normal Right Click

### Task 3.5: Add failing tests for hold timeout downgrade

**Files:**
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`

- [ ] Add tests proving:
  - crossing the movement threshold after the hold timeout does not begin a gesture
  - crossing the movement threshold before timeout still begins a gesture
  - custom trigger configuration values change behavior without recreating the app
- [ ] Inject a lightweight time source into `MouseEventTap` to make timeout behavior deterministic in tests
- [ ] Implement timeout downgrade so that once a pending right click times out it can no longer promote into a gesture

### Task 3: Add failing tests for synthetic click replay

**Files:**
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testShortRightClickReplaysNormalContextClick() {
    var clicks: [[CGEventType]] = []
    let tap = MouseEventTap(
        gestureThreshold: 24,
        syntheticClickPoster: { sequence in clicks.append(sequence.map(\.type)) }
    )

    XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 10, y: 10))), .suppressEvent)
    XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 12, y: 10))), .passEvent)

    XCTAssertEqual(clicks, [[.rightMouseDown, .rightMouseUp]])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MouseEventTapTests/testShortRightClickReplaysNormalContextClick`
Expected: FAIL because no synthetic click replay exists yet.

- [ ] **Step 3: Write minimal implementation**

Add a replay helper that posts a down/up pair for short right clicks:

```swift
private func replayNormalRightClick(at point: GesturePoint) {
    syntheticClickPoster(makeSyntheticClickSequence(at: point))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MouseEventTapTests`
Expected: PASS for replay tests and existing context-click behavior tests.

- [ ] **Step 5: Commit**

```bash
git add Tests/GestureFlowAppTests/MouseEventTapTests.swift Sources/GestureFlowApp/EventTap/MouseEventTap.swift
git commit -m "feat: replay short right clicks after interception"
```

### Task 4: Keep consumed gesture recovery immediate and single-shot

**Files:**
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testConsumedGestureDoesNotReplayNormalClick() {
    var replayedClickCount = 0
    var releasedButtonCount = 0
    let tap = MouseEventTap(
        gestureThreshold: 24,
        syntheticClickPoster: { _ in replayedClickCount += 1 },
        mouseButtonResetter: { _, _ in releasedButtonCount += 1 }
    )

    XCTAssertEqual(tap.handle(.rightMouseDown(at: GesturePoint(x: 0, y: 0))), .suppressEvent)
    XCTAssertEqual(tap.handle(.rightMouseDragged(to: GesturePoint(x: 30, y: 0))), .suppressEvent)
    XCTAssertEqual(tap.handle(.rightMouseUp(at: GesturePoint(x: 40, y: 0))), .suppressEvent)

    XCTAssertEqual(replayedClickCount, 0)
    XCTAssertEqual(releasedButtonCount, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MouseEventTapTests/testConsumedGestureDoesNotReplayNormalClick`
Expected: FAIL if short-click replay leaks into the gesture path.

- [ ] **Step 3: Write minimal implementation**

Separate the short-click replay path from the consumed-gesture mouse-up recovery path. Ensure `stop()` does not replay or re-release after state is already cleared.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MouseEventTapTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Tests/GestureFlowAppTests/MouseEventTapTests.swift Sources/GestureFlowApp/EventTap/MouseEventTap.swift
git commit -m "fix: separate click replay from gesture release recovery"
```

## Chunk 4: Settings Integration

### Task 5: Expose trigger thresholds in settings

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`
- Add: `Sources/GestureFlowApp/Settings/GestureTriggerSettingsView.swift`
- Modify: `Tests/GestureFlowAppTests/SettingsViewModelTests.swift`
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`

- [ ] Add `updateTriggerConfiguration` to the settings view model
- [ ] Add a dedicated settings card for movement threshold and hold timeout
- [ ] Wire the live event tap to read `configuration.trigger` so user adjustments take effect without changing unrelated gesture logic
- [ ] Add focused persistence tests for the new settings flow

## Chunk 5: Timeout Marker Feedback

### Task 6: Show a persistent timeout marker through the overlay pipeline

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift`
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`
- Modify: `Tests/GestureFlowAppTests/GestureEngineTests.swift`
- Modify: `Tests/GestureFlowAppTests/GestureOverlayWindowTests.swift`

- [ ] Add failing tests proving timeout feedback appears once, stays visible until right-button release, and is cleared by `stop()` / cancellation
- [ ] Introduce a focused overlay marker model instead of reusing completion messaging
- [ ] Add `showMarker` / `clearMarker` to the overlay protocol and implement red-dot drawing in `GestureOverlayView`
- [ ] Emit a timeout callback from `MouseEventTap` when pending right click crosses the hold timeout
- [ ] Map the timeout callback to overlay marker display in `GestureEngine`
- [ ] Clear the marker on normal click replay, cancellation, stop, and promotion into a real gesture

## Chunk 6: Regression Validation

### Task 7: Verify integration behavior stays intact

**Files:**
- Modify: `Tests/GestureFlowAppTests/GestureEngineTests.swift` (only if callback timing changes break assumptions)
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`

- [ ] **Step 1: Add or adjust integration assertions only if needed**

```swift
func testGestureEngineStillReceivesBeganMovedEndedForRealGesture() {
    // Keep this only if MouseEventTap callback timing changes observable behavior.
}
```

- [ ] **Step 2: Run focused tests**

Run: `swift test --filter MouseEventTapTests`
Expected: PASS

- [ ] **Step 3: Run full regression suite**

Run: `swift test`
Expected: PASS all tests

- [ ] **Step 4: Manual verification**

Run the app and verify:

```bash
swift run GestureFlowApp
```

Expected:
- short right click opens app context menu,
- long press past timeout still opens app context menu and does not draw a gesture,
- long press past timeout shows a red origin marker until release,
- right-button gesture does not open app context menu,
- hot corners still work immediately after gesture completion.

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/EventTap/MouseEventTap.swift Tests/GestureFlowAppTests/MouseEventTapTests.swift
git commit -m "feat: preemptively intercept right clicks for gestures"
```
