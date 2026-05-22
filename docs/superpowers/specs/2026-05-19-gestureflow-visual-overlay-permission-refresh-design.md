# GestureFlow Visual Overlay And Permission Refresh Design

## Context

During final MVP validation, the user reported six concrete regressions in the
current desktop interaction experience:

- The app should open the settings window on every launch.
- The app should actively request Accessibility permission when missing.
- Permission state should refresh after the user grants access.
- The gesture trail appears too low relative to the pointer hotspot.
- The default trail width is too thick.
- Recognition feedback appears in the wrong place.
- Enabling GestureFlow must not break macOS Hot Corners.

The current architecture is functional, but the overlay and event sampling
layers still rely on assumptions that are too coarse for polished desktop
behavior:

- Overlay drawing uses a global union-of-screens coordinate system.
- Feedback text is drawn relative to the global overlay view instead of the
  pointer's active screen.
- Gesture trail points use raw event locations without cursor hotspot
  compensation.
- `MouseEventTap` still listens to general movement events, which risks
  interfering with system corner detection.
- Permission refresh is mostly snapshot-based instead of application-lifecycle
  driven.

## Confirmed Direction

- Always open the settings panel on app launch.
- Prompt for Accessibility permission proactively when it is missing.
- Refresh permission and running state when the app or settings window becomes
  active again.
- Rework the visual layer rather than only applying isolated point offsets.
- Preserve the current recognition and action execution pipeline unless a change
  is required for the six reported issues.
- Preserve macOS Hot Corners even when GestureFlow is enabled.

## Goals

- Make launch and permission onboarding self-explanatory.
- Align the gesture trail visually with the macOS pointer arrow.
- Reduce the default trail width by roughly one third.
- Render feedback text at the lower center of the screen that currently owns
  the pointer release point.
- Remove the event sampling behavior that can disable or interfere with macOS
  Hot Corners.
- Keep the changes bounded and regression-testable.

## Non-Goals

- Introducing new gesture types.
- Adding new end-user settings for hotspot offset tuning.
- Rewriting the recognizer or matcher.
- Adding full live state synchronization across all windows through a global app
  store.
- Building a brand new overlay window topology per display unless the existing
  cross-screen panel proves insufficient.

## Architecture Changes

### App Layer

`GestureFlowApplication` remains the coordinator for launch, menu state, engine
start/stop, and settings wiring, but it now also owns runtime refresh behavior.

Responsibilities added:

- Automatically show the settings window on every launch.
- Prompt for Accessibility permission on launch if permission is missing.
- Refresh permission and engine-adjacent UI state on launch, after permission
  prompts, and when the app becomes active again.
- Push runtime state changes into the settings window model when the window is
  visible.

This keeps lifecycle-sensitive behavior in one place instead of scattering it
across AppKit and SwiftUI view code.

### Permission Layer

`PermissionService` remains a lightweight wrapper over
`AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions()`.

No complex subscription system is required. The app should treat permission
status as a value that is refreshed at specific lifecycle moments:

- app launch
- after prompting
- when the app becomes active
- when the settings window becomes key

This is enough to solve the stale-permission-state issue without adding a
notification bus.

### Settings Layer

`SettingsWindowController` and `SettingsViewModel` move from a launch-time
snapshot model toward a refreshable model.

Changes:

- `SettingsWindowController` gains lightweight callbacks for "window shown" and
  "window became key".
- `SettingsViewModel` gains explicit runtime update methods for:
  - Accessibility permission state
  - Running state
  - Configuration if needed after external changes

The settings UI remains SwiftUI-based, but it no longer assumes those values are
immutable for the lifetime of the window.

### Event Layer

`MouseEventTap` is reworked to stop depending on general mouse movement.

New rule:

- Gesture point collection only happens during an active button-drag lifecycle.

Captured events remain:

- right mouse down / dragged / up
- middle mouse down / dragged / up

Removed from the event mask:

- general `mouseMoved`

This preserves the intended gesture input flow while avoiding the event stream
most likely to interfere with macOS Hot Corners.

### Overlay Layer

The overlay becomes explicitly screen-aware and hotspot-aware.

It continues to use a transparent AppKit panel for cross-screen drawing, but the
rendering model is split into two concepts:

- **Trail placement**
  - Uses pointer events transformed by a cursor hotspot anchor.
- **Feedback placement**
  - Uses the screen that owns the gesture completion point.

Instead of drawing feedback by centering inside the union bounds of all screens,
the overlay computes a target rect from the active screen and draws the message
near the lower center of that screen.

## New Display Model

### Cursor Hotspot Anchor

Introduce a small internal model that converts raw event points into the visual
gesture trail anchor.

Responsibilities:

- Apply a consistent offset so the trail visually hugs the pointer tip.
- Reuse the same offset for begin and move points.
- Keep the offset logic outside `draw(_:)` so it is testable and deterministic.

For MVP, the hotspot anchor is a fixed offset tuned for the default macOS arrow
cursor. This is acceptable because the user asked for a visual correction, not a
fully dynamic cursor-style engine.

### Screen Context

Introduce a screen-resolution helper used by the overlay.

Responsibilities:

- Resolve which `NSScreen` contains a given global point.
- Fall back to `NSScreen.main` if no precise containing screen is found.
- Provide a consistent feedback anchor rect for the target screen.

This fixes the current bug where messages appear at the top-left of the global
overlay coordinate space.

## Data Flow

### Launch

1. `GestureFlowApplication` initializes services and windows.
2. It shows the settings window automatically.
3. It checks Accessibility permission.
4. If permission is missing, it prompts immediately.
5. It refreshes menu state and the settings view model.

### Permission Refresh

1. User grants or denies permission in System Settings.
2. App becomes active again, or settings window becomes key again.
3. Application refreshes `isAccessibilityTrusted`.
4. Menu and settings UI both update to reflect the new state.

### Gesture Trail

1. `MouseEventTap` receives right or middle mouse down.
2. It starts an active gesture and forwards the first point.
3. Drag events add raw points.
4. `GestureEngine` forwards display points to the overlay after hotspot offset
   conversion.
5. Overlay draws the trail at the visually corrected position.

### Feedback Message

1. A gesture completes.
2. Recognition produces a completion state.
3. The overlay resolves the release point's target screen.
4. It draws the message at the lower center of that screen.

## File-Level Changes

### `Sources/GestureFlowApp/App/GestureFlowApplication.swift`

- Open settings automatically during startup.
- Prompt for Accessibility permission on launch when missing.
- Add a centralized `refreshApplicationState()` flow.
- Refresh menu state and settings runtime state on:
  - launch
  - permission prompt path
  - app activation
  - settings window activation

### `Sources/GestureFlowApp/Permissions/PermissionService.swift`

- Keep trust check and prompt APIs.
- Support explicit re-read usage cleanly from the app layer.

### `Sources/GestureFlowApp/Settings/SettingsWindowController.swift`

- Add callbacks for show/key-window lifecycle events.
- Notify the application to refresh state when the user returns from System
  Settings.

### `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`

- Add runtime update methods for:
  - permission status
  - running state
- Preserve current persistence behavior for configuration edits.

### `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`

- Remove `mouseMoved` from the event mask.
- Remove general movement handling as a standalone event path.
- Continue collecting drag points only during an active gesture.
- Preserve right-click menu suppression behavior only for recognized gesture
  paths.

### `Sources/GestureFlowApp/Engine/GestureEngine.swift`

- Preserve recognition and action execution.
- Forward sufficient overlay display context for corrected trail and feedback
  positioning.

### `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`

- Extend overlay APIs or associated data types to carry:
  - display-adjusted gesture points
  - completion point or screen context for feedback placement

### `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift`

- Maintain the cross-screen transparent panel.
- Add screen-aware message placement.
- Apply hotspot-adjusted points consistently.

### `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`

- Separate trail geometry from message geometry.
- Reduce default line thickness visually.
- Draw the completion hint using a computed target rect rather than the global
  union bounds center.

### Tests

- `Tests/GestureFlowAppTests/GestureEngineTests.swift`
  - add launch/runtime refresh and overlay-completion-context coverage
- `Tests/GestureFlowAppTests/MouseEventTapTests.swift`
  - verify gestures work without `mouseMoved`
  - verify there is no listener dependence on ordinary movement
- add focused overlay geometry tests
  - hotspot offset
  - feedback anchor on target screen
  - thinner default appearance expectations where practical

## Error Handling

- If permission is missing at launch:
  - show settings
  - prompt immediately
  - keep engine stopped
  - refresh visible state
- If screen lookup fails for a feedback point:
  - fall back to `NSScreen.main`
- If settings is already open:
  - refresh the existing view model instead of creating stale duplicate state

## Implementation Order

1. Rework `MouseEventTap` to remove `mouseMoved` dependence and add regression
   tests for right/middle button gestures.
2. Extract overlay geometry helpers for:
   - hotspot offset
   - target screen resolution
   - feedback anchor calculation
3. Upgrade `GestureOverlayWindow` / `GestureOverlayView` to use the new geometry
   model and fix feedback placement.
4. Reduce the default trail width and verify appearance expectations through
   geometry-focused tests.
5. Add app lifecycle refresh behavior in `GestureFlowApplication`.
6. Upgrade `SettingsWindowController` and `SettingsViewModel` to support live
   runtime refresh.
7. Run full build, tests, packaging, and targeted manual smoke checks.

This order reduces risk by fixing the deepest input/overlay assumptions before
touching the app lifecycle wiring.

## Risk Control

### Hot Corners Regression

Primary mitigation:

- remove `mouseMoved` from the event tap mask entirely
- guard with regression tests that gestures still work using only drag events

### Overlay Position Regression

Primary mitigation:

- isolate hotspot and feedback placement into pure calculation helpers
- test those helpers independently from AppKit drawing

### Permission State Staleness

Primary mitigation:

- centralize refresh logic in `GestureFlowApplication`
- trigger refresh on launch and activation events instead of relying on one-time
  construction values

### Existing Gesture Behavior Regression

Primary mitigation:

- keep recognizer and matcher unchanged
- limit changes to event collection and visual placement
- re-run existing gesture engine and event tap suites after each batch

## Validation Plan

- `swift build`
- `swift test`
- targeted tests for:
  - event tap drag-only gesture capture
  - overlay hotspot offset
  - feedback placement on the active screen
  - app launch auto-open settings
  - permission prompt and refresh behavior
- package validation with `Scripts/package_app.sh`
- manual desktop smoke check for:
  - launch opens settings
  - permission prompt appears when needed
  - permission state refreshes after grant
  - Hot Corners still work
  - trail hugs the pointer tip
  - feedback text appears near the lower center of the active screen
