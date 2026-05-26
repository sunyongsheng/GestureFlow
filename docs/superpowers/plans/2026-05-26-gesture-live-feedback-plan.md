# Gesture Live Feedback Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show live gesture recognition feedback and prefix-aware trail coloring while drawing, starting when movement threshold is exceeded.

**Architecture:** Add `GestureLiveMatcher` in core for prefix/exact evaluation; `GestureEngine` accumulates points and updates overlay on each move; extend `GestureTrailAppearance` and overlay API for highlighted vs muted trails and a persistent live feedback card.

**Tech Stack:** Swift 5.9, GestureFlowCore, AppKit overlay, existing `GestureRecognizer` + `ScopedGestureMatcher` patterns.

**Spec:** `docs/superpowers/specs/2026-05-26-gesture-live-feedback-design.md`

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Matching/GestureLiveMatcher.swift` | Prefix + exact live match |
| `Sources/GestureFlowCore/Matching/GestureLiveMatchResult.swift` | Result type (or same file) |
| `Tests/GestureFlowCoreTests/GestureLiveMatcherTests.swift` | Core matching tests |
| `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift` | `LiveGestureOverlayFeedback`, `isHighlighted` |
| `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift` | Live card + muted drawing |
| `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift` | Wire `updateLiveGesture` |
| `Sources/GestureFlowApp/Engine/GestureEngine.swift` | Point buffer + live updates |
| `Tests/GestureFlowAppTests/GestureEngineTests.swift` | Integration tests |

---

## Chunk 1: Core live matcher

### Task 1: GestureLiveMatcher

**Files:**
- Create: `Sources/GestureFlowCore/Matching/GestureLiveMatcher.swift`
- Create: `Tests/GestureFlowCoreTests/GestureLiveMatcherTests.swift`

- [ ] **Step 1: Write failing tests**

Cases:
- Only `[.down, .right]` configured; partial `[.down]` → `hasPrefixMatch == true`, `exactMatch == nil`
- Partial `[.down, .right]` → `exactMatch` set
- Partial `[.down, .left]` → `hasPrefixMatch == false`
- `partialSignature == nil` → both false
- App-specific scope precedence mirrors `ScopedGestureMatcherTests`

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --filter GestureLiveMatcherTests`

- [ ] **Step 3: Implement `GestureLiveMatcher`**

Reuse candidate filtering pattern from `ScopedGestureMatcher` (extract package-private helper if duplication is large).

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Matching/GestureLiveMatcher.swift Tests/GestureFlowCoreTests/GestureLiveMatcherTests.swift
git commit -m "feat(core): add live gesture prefix and exact matching"
```

---

## Chunk 2: Trail appearance and overlay API

### Task 2: Highlighted vs muted appearance

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
- Create: `Tests/GestureFlowAppTests/Overlay/GestureTrailAppearanceHighlightTests.swift`

- [ ] **Step 1: Add `isHighlighted` to `GestureTrailAppearance`**

Factory or init helper: `init(feedback:isHighlighted:)` mapping muted to `#8E8E93`.

- [ ] **Step 2: Update `GestureOverlayView.drawTrail`**

When `!isHighlighted`, use gray for main + stroke colors.

- [ ] **Step 3: Test appearance mapping**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: support muted trail appearance for non-matching gestures"
```

### Task 3: Live overlay feedback API

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift`

- [ ] **Step 1: Add `LiveGestureOverlayFeedback` and `updateLiveGesture(at:appearance:feedback:)`**

`GestureOverlayView`:
- `updateLiveFeedback(message:showsCard:frame:)` — show/hide card without completing gesture
- Keep trail points separate from completion lifecycle

`GestureOverlayWindow`:
- Convert screen point → local, resolve feedback frame, forward to view
- Ensure panel ordered front on live updates

`NoopGestureOverlay`: no-op stub

- [ ] **Step 2: Manual smoke**

Run app, verify card can show/hide during gesture without ending gesture.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: add live gesture overlay feedback API"
```

---

## Chunk 3: GestureEngine integration

### Task 4: Engine point buffer and live updates

**Files:**
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- Modify: `Tests/GestureFlowAppTests/GestureEngineTests.swift`

- [ ] **Step 1: Add state**

```swift
private var activeGesturePoints: [GesturePoint] = []
private let liveMatcher = GestureLiveMatcher()
```

- [ ] **Step 2: `handleGestureBegan`**

Initialize `activeGesturePoints`, `beginGesture`, call `refreshLiveGestureFeedback(at:trigger:)`.

- [ ] **Step 3: `onGestureMoved`**

Append to buffer, `refreshLiveGestureFeedback`.

- [ ] **Step 4: `refreshLiveGestureFeedback` helper**

```swift
let signature = recognizer.recognize(points: activeGesturePoints)
let live = liveMatcher.evaluate(trigger:partialSignature:targetBundleIdentifier:in:)
let highlighted = live.exactMatch != nil || live.hasPrefixMatch
let appearance = GestureTrailAppearance(feedback:isHighlighted: highlighted)
let message = live.exactMatch?.name ?? (signature == nil ? nil : "未识别手势")
overlay.updateLiveGesture(at:appearance:feedback:)
```

Also `overlay.appendGesturePoint` from move handler (order: append then refresh, or refresh with latest point).

- [ ] **Step 5: Clear buffer on end/cancel**

- [ ] **Step 6: Write engine tests with spy overlay**

Spy records `updateLiveGesture` calls:
- After move with down-only + only `[.down,.right]` → message 未识别手势, highlighted true
- After move left → highlighted false
- After full L-shape down-right → message gesture name

- [ ] **Step 7: Run `swift test`**

- [ ] **Step 8: Commit**

```bash
git commit -m "feat: show live gesture recognition feedback while drawing"
```

---

## Chunk 4: Test spy updates

### Task 5: Update overlay test doubles

**Files:**
- Modify: `Tests/GestureFlowAppTests/GestureEngineTests.swift` (spy overlay type)

- [ ] **Step 1: Extend test overlay spy with `liveUpdates` array**

- [ ] **Step 2: Fix any compile errors in overlay window tests**

- [ ] **Step 3: Full test suite green**

Run: `swift test`

- [ ] **Step 4: Commit if needed**

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-26-gesture-live-feedback-plan.md`.

Ready to execute when you want implementation started.
