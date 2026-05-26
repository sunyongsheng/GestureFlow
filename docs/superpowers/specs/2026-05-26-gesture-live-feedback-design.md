# Gesture Live Feedback Design

**Goal**

Show gesture trail and feedback overlay together as soon as a gesture is considered valid (movement threshold exceeded, not timed out). While drawing, update the overlay in real time with recognition status, gesture name on exact match, and trail coloring based on prefix match vs no match.

**Out Of Scope**

- Prefix-based action dispatch on release (release still requires exact signature match).
- New user settings for gray trail color or live feedback copy.
- Changes to gesture recognition token extraction algorithm.
- Live feedback during right-click hold-timeout synthetic click path.

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Overlay start | Same as today: `onGestureBegan` after `movementThreshold`, not raw mouse down |
| Live updates | On every `onGestureMoved` after points accumulated in `GestureEngine` |
| Exact match (live) | Show configured gesture **name** immediately when partial signature equals a gesture |
| Prefix only (live) | Show **「未识别手势」**; trail uses normal configured colors |
| No prefix (live) | Show **「未识别手势」**; trail uses muted gray |
| `recognize == nil` after threshold | Trail only; hide live feedback card until a signature exists |
| Prefix rule | `gesture.signature.tokens.starts(with: partial.tokens)` with non-empty partial |
| Scope / trigger | Same filtering as `ScopedGestureMatcher` (enabled, trigger, app-specific then global) |
| Release behavior | Unchanged: exact match required to execute action; card completion messages as today unless copy unified |
| Gray trail | Fixed muted color `#8E8E93` (main trail + stroke when enabled) |
| Architecture | `GestureLiveMatcher` in core; `GestureEngine` owns point buffer and drives overlay |

## Architecture

### Core (`GestureFlowCore`)

**`GestureLiveMatchResult`**

```swift
struct GestureLiveMatchResult: Equatable {
    var partialSignature: GestureSignature?
    var exactMatch: GestureDefinition?
    var hasPrefixMatch: Bool
}
```

**`GestureLiveMatcher`**

```swift
func evaluate(
    trigger: GestureTrigger,
    partialSignature: GestureSignature?,
    targetBundleIdentifier: String?,
    in gestures: [GestureDefinition]
) -> GestureLiveMatchResult
```

Logic:

1. If `partialSignature` is nil or `tokens` empty → `exactMatch = nil`, `hasPrefixMatch = false`.
2. Filter gestures: `isEnabled`, `trigger` match, same candidate ordering as `ScopedGestureMatcher`.
3. `exactMatch`: first candidate with `gesture.signature == partialSignature`.
4. `hasPrefixMatch`: any candidate where `gesture.signature.tokens.starts(with: partialSignature.tokens)`.

### App (`GestureFlowApp`)

**`GestureEngine`**

- Maintain `activeGesturePoints: [GesturePoint]` from began → ended/cancelled.
- `handleGestureBegan`: capture target, begin overlay trail, run first live update.
- `onGestureMoved`: append point, `recognize(activeGesturePoints)`, `liveMatcher.evaluate`, build `GestureTrailAppearance` (highlighted vs muted), call overlay live update.
- `finishGestureEnded`: unchanged matching and action path; clear point buffer.

**`GestureTrailAppearance`**

Add `isHighlighted: Bool` (default `true`). When `false`, map feedback colors to gray (`#8E8E93`) for main trail and stroke in overlay drawing.

**`GestureOverlayDisplaying` / `GestureOverlayView`**

New live update API:

```swift
struct LiveGestureOverlayFeedback: Equatable {
    var message: String?
    var showsCard: Bool
}

func updateLiveGesture(
    at point: GesturePoint,
    appearance: GestureTrailAppearance,
    feedback: LiveGestureOverlayFeedback
)
```

- `showsCard == false` → hide feedback card (signature not yet available).
- `showsCard == true` → show card near pointer (`resolveFeedbackFrame`), message per live rules.
- `completeGesture` retains end-state behavior and hide delay.

### Live Message Rules

| Condition | Card | Message |
| --- | --- | --- |
| `partialSignature == nil` | Hidden | — |
| `exactMatch != nil` | Shown | `exactMatch.name` |
| Else | Shown | `未识别手势` |

### Trail Color Rules

| Condition | `isHighlighted` |
| --- | --- |
| `exactMatch != nil` | `true` |
| `hasPrefixMatch` | `true` |
| Otherwise | `false` |

Stroke follows same highlight flag (muted stroke colors when gray).

## Examples

Configuration: one gesture `[.down, .right]` named「关闭窗口」, right-mouse trigger.

| User draws | Live message | Trail |
| --- | --- | --- |
| Down → partial `[.down]` | 未识别手势 | Normal |
| Down-right → `[.down, .right]` | 关闭窗口 | Normal |
| Down-left → `[.down, .left]` | 未识别手势 | Gray |
| Release on `[.down]` only | End: unmatched, no action | — |

## Error Handling

- Gesture cancelled / ended: clear `activeGesturePoints`, hide overlay via existing paths.
- Configuration reload during active gesture: use latest `gestureConfigurationProvider()` on each move.
- Multiple exact-match duplicates (config error): `GestureLiveMatcher` returns first candidate consistent with `ScopedGestureMatcher`.

## Testing

| Layer | Cases |
| --- | --- |
| `GestureLiveMatcherTests` | prefix / exact / scope / trigger filtering |
| `GestureEngineTests` | live overlay updates on move; gray on prefix break; name on exact |
| `GestureTrailAppearanceTests` | muted maps to gray hex |

## Non-Goals

- Showing direction tokens (e.g.「下、右」) as live message.
- Delaying gesture name until mouse up when already an exact match.
- Configurable live-feedback strings in settings.
