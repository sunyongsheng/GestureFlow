# Right Click Preemptive Interception Design

## Context

GestureFlow currently lets the original `rightMouseDown` reach the app under the pointer, then suppresses `rightMouseUp` only after the gesture distance exceeds the recognition threshold. This causes two problems:

1. A right-button gesture can still trigger the target application's context-click behavior.
2. System features that depend on a consistent mouse button lifecycle, such as hot corners, can become desynchronized if the consumed mouse-up is not restored carefully.

## Goal

Preserve mouse-gesture behavior without leaking a right click to the target app. A short, low-movement right click must still behave like a normal context click.
The interception behavior must also reject long presses. If the right button is held longer than a configurable timeout before the movement threshold is crossed, the interaction must fall back to a normal context click and never promote into gesture recognition.

## Recommended Approach

Use preemptive interception driven by both movement and time thresholds.

1. Intercept `rightMouseDown` immediately instead of passing it through.
2. Enter a pending-right-click state that records the initial point and button lifecycle.
3. While movement stays below the configured gesture threshold, do not begin overlay drawing or gesture recognition.
4. If the hold duration exceeds the configured timeout before the movement threshold is crossed, downgrade the interaction to a normal context click candidate:
   - keep suppressing the original hardware events,
   - do not emit any gesture callbacks,
   - do not allow later movement to promote the interaction into a gesture,
   - show a persistent red origin marker at the initial right-button down point until `rightMouseUp`.
5. If accumulated movement crosses the threshold before the timeout, convert the pending interaction into a real gesture:
   - start overlay drawing,
   - feed the buffered points into the gesture pipeline,
   - continue suppressing subsequent right-button events,
   - on gesture completion, restore system button state immediately with a synthetic right mouse-up.
6. If `rightMouseUp` arrives before the threshold is crossed, or after the timeout downgrade path is active, treat it as a normal context click:
   - synthesize a full right click (`rightMouseDown` + `rightMouseUp`) back to the system,
   - do not emit gesture callbacks,
   - clear pending state.

## Component Changes

### `MouseEventTap`

- Replace the current "gesture starts on rightMouseDown" model with a two-stage model:
  - `pendingRightClick`
  - `activeGesture`
- Record the pending interaction start time through an injectable time source so tests can deterministically validate timeout behavior.
- Buffer low-movement points until the threshold is crossed.
- Make both thresholds configurable from the persisted app configuration:
  - `movementThreshold`
  - `holdTimeoutMilliseconds`
- Add a synthetic click poster for replaying normal right clicks.
- Keep the existing synthetic mouse-up recovery path for consumed gestures, but trigger it immediately when a consumed gesture finishes instead of waiting for `stop()`.

### `GestureEngine`

- No behavior change should be required if `MouseEventTap` only invokes:
  - `onGestureBegan` once threshold crossing is confirmed,
  - `onGestureMoved` for buffered and subsequent points,
  - `onGestureEnded` only for real gestures.
- Add a lightweight timeout feedback callback from `MouseEventTap` into `GestureEngine`, and let `GestureEngine` map that state into overlay marker commands. This keeps the input state machine separate from drawing details.

### Overlay Feedback

- Extend the overlay system with a lightweight marker model instead of overloading completion messaging:
  - `GestureOverlayMarker`
  - marker style `.timeoutOrigin`
- Add `showMarker` and `clearMarker` to `GestureOverlayDisplaying`.
- `GestureOverlayView` renders the timeout marker as a red filled dot using the existing coordinate conversion pipeline and keeps it visible until the right button is released or the gesture is cancelled.

### Configuration and Settings

- Add a `GestureTriggerConfiguration` model to `AppConfiguration`.
- Preserve backward compatibility when loading legacy `config.json` files that do not contain the new trigger section.
- Expose both trigger thresholds in the settings window under a dedicated input-behavior card instead of mixing them into feedback styling controls.

### Tests

Add or update focused tests for:

1. `rightMouseDown` is suppressed before threshold crossing.
2. Short, low-movement right click replays a normal context click.
3. Crossing the threshold before timeout starts a gesture and does not replay a normal click.
4. Crossing the movement threshold after timeout still falls back to a normal context click.
5. Consumed gesture completion still restores system button state immediately.
6. Legacy configuration files load with default trigger settings.
7. Timeout feedback marker appears exactly once and stays visible until `rightMouseUp`.
8. `stop()` clears any timeout marker and does not double-replay or double-release events.

## Risks

- Replaying a synthetic right click can accidentally duplicate events if pending state is not cleared precisely.
- Buffered-point promotion must preserve current gesture signatures; otherwise recognition can shift.
- Hot-corner recovery and context-menu replay both depend on correct synthetic event ordering.
- Adding new persisted fields without decode fallbacks would incorrectly classify old user configurations as corrupt.
- Timeout marker lifecycle must stay aligned with the pending right-click lifecycle; otherwise stale red dots can survive into later interactions.

## Validation

1. Manual:
   - Short right click opens the target app context menu.
   - Right-button gesture does not trigger the target app context menu.
   - Long press beyond timeout does not start gesture recognition and still resolves as a normal context click.
   - Long press beyond timeout shows a red origin dot and keeps it visible until button release.
   - Hot corners still work immediately after a gesture.
2. Automated:
   - `MouseEventTapTests`
   - `GestureEngineTests`
   - `GestureOverlayWindowTests`
   - `SettingsViewModelTests`
   - `ConfigurationStoreTests`
   - full `swift test`
