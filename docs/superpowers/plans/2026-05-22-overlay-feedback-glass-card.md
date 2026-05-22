# Overlay Feedback Glass Card Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hand-drawn bottom feedback banner with a modern glassmorphism feedback card while preserving current gesture overlay timing and positioning behavior.

**Architecture:** Keep `GestureOverlayWindow` responsible for panel lifecycle and position calculation. Move feedback message presentation in `GestureOverlayView` from `drawMessage()` into a dedicated subview backed by `NSVisualEffectView`, while leaving trail and marker rendering in `draw(_:)`.

**Tech Stack:** Swift, AppKit, NSVisualEffectView, XCTest.

---

## File Map

- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
  - Introduce a dedicated feedback card subview and route message show/hide through it.
- Test: `Tests/GestureFlowAppTests/GestureOverlayWindowTests.swift`
  - Verify overlay completion drives visible feedback card state.

## Chunk 1: Add Feedback Card View

### Task 1: Cover feedback card visibility with a failing test

**Files:**
- Test: `Tests/GestureFlowAppTests/GestureOverlayWindowTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that completes a gesture and asserts the overlay view exposes a visible feedback card with the expected message.

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
swift test --filter GestureOverlayWindowTests
```

Expected: failure because the feedback card state is not exposed yet.

### Task 2: Implement the glass feedback card

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`

- [ ] **Step 1: Add a dedicated feedback subview**

Create a small AppKit view composed of:

- `NSVisualEffectView` background
- rounded corners
- subtle border and shadow
- `NSTextField(labelWithString:)` for message text

- [ ] **Step 2: Route completion message through the subview**

Replace `drawMessage()` usage with:

- `showFeedback(message:frame:)`
- `hideFeedback()`

Keep message anchor calculation unchanged.

- [ ] **Step 3: Preserve existing overlay behavior**

Do not change:

- trail drawing
- marker drawing
- panel hide scheduling
- feedback anchor geometry

- [ ] **Step 4: Run the focused test to verify it passes**

Run:

```bash
swift test --filter GestureOverlayWindowTests
```

Expected: PASS.

## Chunk 2: Final Verification

### Task 3: Run overlay regressions and diagnostics

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
- Test: `Tests/GestureFlowAppTests/GestureOverlayWindowTests.swift`

- [ ] **Step 1: Run overlay-related tests**

Run:

```bash
swift test --filter GestureOverlayWindowTests
swift test --filter GestureOverlayGeometryTests
```

Expected: PASS.

- [ ] **Step 2: Check diagnostics for edited files**

Expected: no new diagnostics.

- [ ] **Step 3: Skip commit because current task flow is still operating without git commits**
