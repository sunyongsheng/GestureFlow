# Gesture Signature Preview Design

**Goal**

Replace Chinese text labels in the gesture settings table signature picker with schematic path drawings derived from `GestureSignature`, shown both in the collapsed cell and in the dropdown menu. Chinese remains available only for accessibility and hover help.

**Out Of Scope**

- Real-time mouse trail rendering (overlay stays separate).
- Changing `GestureSignatureCatalog` generation rules (still 52 entries, length 1–3, no adjacent duplicate directions).
- Grid-based signature picker or gesture recording UI.
- Trackpad or non-mouse gesture types.

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Visible UI | `GestureSignaturePreview` (40×40 pt), no Chinese text in picker |
| Collapsed + menu | Both show preview (option B) |
| Accessibility | `accessibilityLabel` + `.help` use existing Chinese `displayName` (option B) |
| Column layout | Gesture column ~88–96 pt wide; preview frame 40×40 pt |
| Architecture | Core geometry + App SwiftUI view (recommended approach 1) |
| Arrow | Only at final segment endpoint, pointing along last direction |
| `displayName` in catalog | Retained for a11y/help only; `id` becomes stable token key (e.g. `D,R`) |

## Drawing Semantics

**Input:** `GestureSignature` with `tokens: [GestureDirection]` (1–3 segments).

**Path construction:**

1. Start at origin `(0, 0)` in gesture space.
2. Each token adds one segment of equal unit length (`1.0`):
   - `up` → `(0, -1)`
   - `down` → `(0, +1)`
   - `left` → `(-1, 0)`
   - `right` → `(+1, 0)`
3. Polyline vertices: `[start, after segment 1, after segment 2, …]`.
4. Example `[.down, .right]`: `(0,0) → (0,1) → (1,1)` — an L shape in screen coordinates (y increases downward).

**Fitting:**

- Compute axis-aligned bounding box of all vertices.
- Scale uniformly so the path fits inside a unit square with ~12% padding.
- Center within that square (output coordinates 0…1 for App layer to map into 40×40 pt).

**Arrow:**

- Draw only at the **last** vertex.
- Points in the direction of the **last** token.
- Filled triangle; size proportional to preview (≈6–8 pt at 40×40).

**Style (App):**

- Stroke: `Color.primary` (fallback `.secondary` if contrast issues in tests).
- Line width: 2 pt, round joins/caps.
- Arrow: same color as stroke, filled.

## Architecture

```
GestureFlowCore
  GestureSignaturePathGeometry.swift
    - polyline vertices + terminal direction
    - fit-to-unit-square transform (testable)

GestureFlowApp/Settings/Gestures/UI
  GestureSignaturePreview.swift
    - SwiftUI Shape / Canvas
    - fixed frame 40×40

GestureSettingsView.swift
  - signatureCell uses Picker label + menu items with preview
  - column width ~92 pt

GestureSignatureCatalog.swift
  - id: stable key from token raw values
  - displayName: unchanged (Chinese), a11y only
```

### `GestureSignaturePathGeometry` (Core)

Pure Foundation types (no SwiftUI):

```swift
public struct PathPoint: Equatable {
    public var x: Double
    public var y: Double
}

public enum GestureSignaturePathGeometry {
    public static func polyline(for signature: GestureSignature) -> [PathPoint]
    public static func fittedPolyline(
        for signature: GestureSignature,
        paddingRatio: Double = 0.12
    ) -> [PathPoint]  // 0…1 normalized, centered
    public static func terminalDirection(for signature: GestureSignature) -> GestureDirection?
}
```

### `GestureSignaturePreview` (App)

```swift
struct GestureSignaturePreview: View {
    let signature: GestureSignature
    // body: GestureSignatureGlyphShape + frame 40×40
}
```

### Picker integration

```swift
Picker("", selection: signatureBinding(for: gesture)) {
    ForEach(GestureSignatureCatalog.all) { option in
        GestureSignaturePreview(signature: option.signature)
            .accessibilityLabel(option.displayName)
            .help(option.displayName)
            .tag(option.signature)
    }
} label: {
    GestureSignaturePreview(signature: currentSignature)
        .accessibilityLabel(currentDisplayName)
        .help(currentDisplayName)
}
.labelsHidden()
```

`currentSignature` / `currentDisplayName` resolved from binding + `GestureSignature.chineseDisplayName`.

### Catalog ID change

Replace `id: displayName` with stable key:

```swift
public var id: String {
    signature.tokens.map(\.rawValue).joined(separator: ",")
}
```

Avoids coupling Identifiable to localized/display strings.

## Settings Layout

| Column | Width change |
| --- | --- |
| 手势 (header + cell) | `100` → `92` (acceptable range 88–96) |
| Preview | `40×40` frame inside cell |

Other columns unchanged.

## Testing

**Core — `GestureSignaturePathGeometryTests`:**

| Case | Assert |
| --- | --- |
| `[.down, .right]` | 3 vertices; terminal direction `.right`; fitted points within 0…1 |
| `[.left]` | 2 vertices; terminal `.left` |
| Three segments | 4 vertices; no crash |
| Empty tokens | Empty polyline / nil terminal (defensive; catalog never emits) |

**Core — update `GestureSignatureCatalogTests`:**

- Assert `id` for `[.down, .right]` is `"D,R"` (or matching rawValue join rule).
- Keep `displayName` Chinese test.

**App (optional smoke):**

- Compile-time only via existing settings tests, or skip dedicated snapshot in MVP.

## Migration / Compatibility

- No config file schema change.
- `chineseDisplayName` on `GestureSignature` / `GestureDirection` unchanged.
- Users see visuals instead of `下、右` in picker; behavior identical.

## References

- Current picker: `GestureSettingsView.signatureCell`
- Catalog: `GestureSignatureCatalog.swift`
- Prior spec (Chinese labels): `docs/superpowers/specs/2026-05-23-gesture-scoped-settings-design.md` — UI section superseded for signature column display only.
