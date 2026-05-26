# Trail Stroke Settings Design

**Goal**

Add an optional outer stroke around the gesture trail in Advanced → Gesture Feedback settings. Users can enable a contrasting outline with independent color and width, or leave stroke disabled (current behavior).

**Out Of Scope**

- Stroke opacity separate from main trail opacity (stroke uses main `trailOpacity` for both layers).
- Relative stroke width as a ratio of main trail width.
- Finder-based color pickers beyond the existing `NSColorPanel` pattern.
- Changes to gesture recognition, matcher, or feedback card placement.

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Visual model | Outer stroke around existing filled/stroked trail (option A) |
| Stroke parameters | Color + independent width (option B) |
| Disable UX | Toggle「启用轨迹描边」; hide color/width when off (option A) |
| Default | Stroke disabled; no behavior change for existing users |
| Config fields | `trailStrokeEnabled`, `trailStrokeColorHex`, `trailStrokeWidth` on `FeedbackConfiguration` |
| Stroke width range | 0.5–8.0, step 0.5 |
| Default stroke color (when enabled) | `#FFFFFF` |
| Default stroke width (when enabled) | `1.5` |
| Drawing order | Wider stroke path first, then main trail on top |
| Effective outer width | `trailWidth + 2 × trailStrokeWidth` |

## Architecture

### Configuration (`GestureFlowCore`)

Extend `FeedbackConfiguration`:

```swift
public var trailStrokeEnabled: Bool      // default false
public var trailStrokeColorHex: String   // default "#FFFFFF"
public var trailStrokeWidth: Double      // default 1.5
```

`Codable` decoding uses `decodeIfPresent` with defaults so existing `config.json` files load without migration.

`FeedbackConfiguration.default` keeps stroke disabled; preset color/width apply only after the user enables the toggle.

### Runtime Appearance (`GestureFlowApp`)

Extend `GestureTrailAppearance` with:

- `strokeEnabled: Bool`
- `strokeColorHex: String`
- `strokeWidth: Double`

Map from `FeedbackConfiguration` in `init(feedback:)`. `GestureEngine` already passes `appConfigurationProvider().feedback` into the overlay; no engine logic change beyond appearance mapping.

### Overlay Drawing (`GestureOverlayView`)

`drawTrail()` when `strokeEnabled`:

1. Build the same path as today (polyline or single-point circle).
2. Stroke with stroke color at `lineWidth = trailWidth + 2 × strokeWidth`, opacity = `trailOpacity`.
3. Stroke/fill with main trail color at `lineWidth = trailWidth`, opacity = `trailOpacity`.

Single-point trail: draw outer circle (radius includes stroke), then inner circle (main trail).

When `strokeEnabled` is false, preserve current drawing exactly.

### Settings UI (`FeedbackSettingsView`)

Insert after「轨迹颜色」:

1. `SettingsValueRow` + Toggle —「启用轨迹描边」
2. When enabled:
   - `TrailColorPickerControl` —「描边颜色」
   - `SettingsSliderRow` —「描边粗细」, range 0.5–8.0

Use `viewModel.updateFeedback` for all mutations (same as existing feedback bindings).

### Preview (`GestureTrailPreview`)

Mirror overlay layering in SwiftUI:

- If `feedback.trailStrokeEnabled`, stroke preview curve with stroke color and `lineWidth = trailWidth + 2 × strokeWidth`.
- Stroke main curve with `trailColor` and `trailWidth` on top.
- Apply `trailOpacity` to the composed preview (same as today).

### Restore Defaults

`SettingsViewModel.restoreDefaultFeedbackConfiguration()` resets stroke fields via `FeedbackConfiguration.default`.

## Error Handling

- Invalid hex in saved config: reuse `ColorHexFormatting` fallbacks (system blue for main; reasonable fallback for stroke if decode succeeds but color parse fails at draw time).
- Toggle off: ignore stroke color/width in overlay; persisted values remain for next enable.

## Testing

| Area | Coverage |
| --- | --- |
| `FeedbackConfiguration` | Decode missing keys → defaults; encode round-trip with stroke enabled |
| `GestureTrailAppearance` | Maps stroke fields from feedback |
| `GestureEngineTests` | Optional: overlay receives appearance with stroke when enabled |
| Manual | Advanced settings preview + live gesture trail with stroke on/off |

## Non-Goals

- Per-gesture stroke overrides.
- Animated stroke styles.
- Separate stroke opacity slider.
