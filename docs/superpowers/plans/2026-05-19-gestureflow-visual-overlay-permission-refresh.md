# GestureFlow Visual Overlay And Permission Refresh Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix launch UX, permission refresh, trail positioning, feedback placement, trail thickness, and Hot Corners compatibility without regressing existing gesture behavior.

**Architecture:** Keep the recognizer and matcher stable while reworking the event sampling and overlay geometry layers. Centralize runtime refresh in the application coordinator, add refresh hooks to the settings window, and isolate overlay geometry into testable helpers so visual fixes remain deterministic.

**Tech Stack:** Swift, AppKit, SwiftUI, CoreGraphics, XCTest, Swift Package Manager

---

## Chunk 1: Event Sampling And Overlay Geometry

### Task 1: Remove `mouseMoved` dependence from event capture

**Files:**
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
- Test: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`

- [ ] **Step 1: Write the failing tests**

Add or update tests that verify:
- drag-only right-button gestures still complete successfully
- drag-only middle-button gestures still complete successfully
- no standalone `mouseMoved` input path is required for recognition

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `swift test --filter MouseEventTapTests`
Expected: at least one test fails because current implementation still exposes or depends on `mouseMoved`

- [ ] **Step 3: Write the minimal implementation**

Modify `MouseEventTap.swift` to:
- remove `.mouseMoved` from the event tap mask
- remove `MouseEventTapInput.mouseMoved`
- remove `.mouseMoved` handling branches
- keep point collection only during active gesture drag events

- [ ] **Step 4: Run the focused tests to verify pass**

Run: `swift test --filter MouseEventTapTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/EventTap/MouseEventTap.swift Tests/GestureFlowAppTests/MouseEventTapTests.swift
git commit -m "fix: capture gestures without mouse moved events"
```

### Task 2: Add testable overlay geometry helpers

**Files:**
- Create: `Sources/GestureFlowApp/Overlay/GestureOverlayGeometry.swift`
- Create: `Tests/GestureFlowAppTests/GestureOverlayGeometryTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests for:
- hotspot offset moves points upward and slightly left
- screen resolution chooses the containing screen for a global point
- feedback anchor is near the lower center of the target screen
- fallback behavior uses main screen or provided fallback frame

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `swift test --filter GestureOverlayGeometryTests`
Expected: FAIL because helper types do not exist

- [ ] **Step 3: Write the minimal implementation**

Implement a focused helper file with:
- cursor hotspot offset calculation
- screen frame resolution abstraction
- feedback anchor rect calculation

- [ ] **Step 4: Run the focused tests to verify pass**

Run: `swift test --filter GestureOverlayGeometryTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Overlay/GestureOverlayGeometry.swift Tests/GestureFlowAppTests/GestureOverlayGeometryTests.swift
git commit -m "feat: add overlay geometry helpers"
```

### Task 3: Rework overlay positioning and thinner default visuals

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- Test: `Tests/GestureFlowAppTests/GestureEngineTests.swift`
- Test: `Tests/GestureFlowAppTests/GestureOverlayGeometryTests.swift`

- [ ] **Step 1: Write the failing tests**

Add or update tests that verify:
- overlay receives hotspot-adjusted points
- completion feedback uses the gesture completion point to choose a target screen
- default trail width is reduced to roughly two thirds of the current default

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `swift test --filter 'GestureEngineTests|GestureOverlayGeometryTests'`
Expected: FAIL because overlay APIs and geometry behavior have not been upgraded

- [ ] **Step 3: Write the minimal implementation**

Update overlay contracts and rendering to:
- apply hotspot offset consistently
- store feedback anchor derived from the completion point screen
- draw feedback near the lower center of that screen
- reduce default width and starting dot size accordingly

- [ ] **Step 4: Run the focused tests to verify pass**

Run: `swift test --filter 'GestureEngineTests|GestureOverlayGeometryTests'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift Sources/GestureFlowApp/Overlay/GestureOverlayView.swift Sources/GestureFlowApp/Engine/GestureEngine.swift Tests/GestureFlowAppTests/GestureEngineTests.swift Tests/GestureFlowAppTests/GestureOverlayGeometryTests.swift
git commit -m "fix: align overlay trail and feedback placement"
```

## Chunk 2: App Lifecycle, Permission Refresh, And Settings Sync

### Task 4: Auto-open settings and refresh permission state on launch/activation

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/Permissions/PermissionService.swift`
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests for:
- app launch opens settings every time
- app launch prompts for Accessibility permission when missing
- app activation refresh updates visible runtime state

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `swift test --filter GestureFlowApplicationTests`
Expected: FAIL because launch and activation refresh behavior is not implemented

- [ ] **Step 3: Write the minimal implementation**

Update the app coordinator to:
- always show settings on launch
- proactively prompt when permission is missing
- centralize state refresh
- refresh after prompt and when the app becomes active again

- [ ] **Step 4: Run the focused tests to verify pass**

Run: `swift test --filter GestureFlowApplicationTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/App/GestureFlowApplication.swift Sources/GestureFlowApp/Permissions/PermissionService.swift Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift
git commit -m "fix: refresh permission state on launch and activation"
```

### Task 5: Make settings runtime state refreshable

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsWindowController.swift`
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Test: `Tests/GestureFlowAppTests/SettingsViewModelTests.swift`
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests for:
- settings runtime state updates after permission changes
- settings runtime state updates after engine start/stop changes
- settings window lifecycle callback triggers app refresh

- [ ] **Step 2: Run the focused tests to verify failure**

Run: `swift test --filter 'SettingsViewModelTests|GestureFlowApplicationTests'`
Expected: FAIL because the settings model is still snapshot-based

- [ ] **Step 3: Write the minimal implementation**

Update settings components to:
- support runtime state update methods
- notify app coordinator on show / become-key transitions
- let the app coordinator push refreshed permission and running state into the visible settings model

- [ ] **Step 4: Run the focused tests to verify pass**

Run: `swift test --filter 'SettingsViewModelTests|GestureFlowApplicationTests'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Settings/SettingsWindowController.swift Sources/GestureFlowApp/Settings/SettingsViewModel.swift Sources/GestureFlowApp/App/GestureFlowApplication.swift Tests/GestureFlowAppTests/SettingsViewModelTests.swift Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift
git commit -m "fix: keep settings state in sync with runtime"
```

## Chunk 3: Full Validation

### Task 6: Run full regression and package validation

**Files:**
- Verify only: `Sources/GestureFlowApp/...`
- Verify only: `Tests/GestureFlowAppTests/...`
- Verify only: `Scripts/package_app.sh`

- [ ] **Step 1: Run full build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run full tests**

Run: `swift test`
Expected: all tests pass

- [ ] **Step 3: Run package validation**

Run: `Scripts/package_app.sh`
Expected: `build/GestureFlow.app` exists and `plutil` succeeds

- [ ] **Step 4: Run diagnostics**

Run VS Code diagnostics for recently edited files
Expected: no new diagnostics

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/App/GestureFlowApplication.swift Sources/GestureFlowApp/Permissions/PermissionService.swift Sources/GestureFlowApp/Settings/SettingsWindowController.swift Sources/GestureFlowApp/Settings/SettingsViewModel.swift Sources/GestureFlowApp/EventTap/MouseEventTap.swift Sources/GestureFlowApp/Engine/GestureEngine.swift Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift Sources/GestureFlowApp/Overlay/GestureOverlayView.swift Sources/GestureFlowApp/Overlay/GestureOverlayGeometry.swift Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift Tests/GestureFlowAppTests/SettingsViewModelTests.swift Tests/GestureFlowAppTests/MouseEventTapTests.swift Tests/GestureFlowAppTests/GestureEngineTests.swift Tests/GestureFlowAppTests/GestureOverlayGeometryTests.swift docs/superpowers/specs/2026-05-19-gestureflow-visual-overlay-permission-refresh-design.md docs/superpowers/plans/2026-05-19-gestureflow-visual-overlay-permission-refresh.md
git commit -m "fix: polish gesture overlay and permission refresh"
```
