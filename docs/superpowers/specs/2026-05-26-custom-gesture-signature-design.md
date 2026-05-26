# Custom Gesture Signature Design

**Goal**

Let users draw custom gesture signatures from the gesture Picker, persist them in `gestures.yaml`, and reuse them like built-in patterns—with duplicate detection that selects an existing entry instead of creating a copy.

**Out Of Scope**

- Renaming or deleting individual custom signatures from a management UI
- Per-gesture custom libraries (custom signatures are global)
- Recording outside a fixed in-sheet canvas
- Changing built-in `GestureSignatureCatalog` generation

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Storage | New field `customGestureSignatures: [GestureSignature]` on `GestureConfiguration` (same `gestures.yaml` file) |
| Built-in catalog | Unchanged static `GestureSignatureCatalog` |
| Segment rules | At least 1 token; no maximum length; same recognizer rules (no adjacent duplicate directions) |
| Drawing surface | Fixed canvas inside sheet (~240×240); samples only inside canvas |
| Confirm enabled | Only when recognizer returns a non-empty signature |
| Cancel | Close sheet; no persistence |
| Duplicate on confirm | Match built-in + custom by `GestureSignature` equality; select existing, do not append |
| Duplicate UX | Close sheet; keep Picker popover open; scroll to and select matching cell |
| New signature UX | Append to `customGestureSignatures`, persist, select, scroll into view |
| Runtime during sheet | Stop `GestureEngine`; restart if it was running before |
| Restore defaults | Clear `customGestureSignatures` with default gesture template |
| Picker layout | Built-in grid → divider → custom grid (4 columns) →「+」row |

## Data Model

```yaml
applicationBundleIdentifiers: []
customGestureSignatures:
  - tokens: [D, R]
  - tokens: [U, L, R]
gestures:
  - id: ...
    name: ...
    signature:
      tokens: [D, R]
```

- `GestureSignature` remains `{ tokens: [GestureDirection] }` (YAML via existing coder).
- Deduplication key: full token sequence equality.
- Custom signatures are **not** `GestureDefinition` rows; they are shared patterns the Picker can assign to any gesture row.

## Picker UI

```
┌ Built-in signatures (4-column grid, catalog order) ┐
├──────────────── Divider ─────────────────────────┤
├ Custom signatures (4-column grid, append order) ─┤
└ [ + ] centered button ───────────────────────────┘
```

- Custom cells use the same glyph cell as built-in options.
- Help / accessibility: `signature.chineseDisplayName`.
- Stable scroll IDs: built-in uses catalog option `id`; custom uses same string format (`"D,R"` from tokens).

## Drawing Sheet

- Presented from「+」as a sheet (or modal attached to settings window).
- Title: e.g.「绘制自定义手势」.
- Fixed drawing canvas; `DragGesture` collects `GesturePoint`s in view coordinates.
- Live feedback: glyph preview + direction text (e.g.「下、右」) or placeholder when empty.
- Buttons: **取消** (dismiss), **确认** (enabled only when `recognize` returns non-nil).

### Coordinate system

`GestureRecognizer` today assumes AppKit screen coordinates (Y up). Canvas uses SwiftUI coordinates (Y down). Add a recording path—e.g. `GestureRecognizer.recognize(points:coordinateSystem:)` or a small `GestureSignatureRecordingRecognizer`—so directions match runtime behavior.

## Confirm Flow

```
Confirm tapped
  → signature = recognize(canvasPoints)
  → guard non-empty
  → if exists in catalog.all OR customGestureSignatures:
        selection = existing
        close sheet
        keep picker open
        scrollTo(existing id)
     else:
        append to customGestureSignatures
        persist gestures.yaml
        selection = new
        close sheet
        scrollTo(new id)
  → resume gesture engine if needed
```

## Engine Pause

- On sheet appear: if `gestureEngine.isRunning`, call `stop()` and remember prior state.
- On sheet dismiss (confirm or cancel): if was running, call `start()` again.
- Expose via `GestureFlowApplication` or a narrow `GestureRecognitionPausing` protocol for tests.

## Components

| Unit | Responsibility |
| --- | --- |
| `GestureConfiguration` | Hold `customGestureSignatures` |
| `GestureConfigurationStore` | Load/save YAML (automatic via Codable) |
| `GestureSignatureCatalog` | Built-in options only |
| `CustomGestureSignatureLibrary` (optional) | Lookup / append / contains helpers |
| `GestureSignatureRecordingView` | Canvas UI + live preview |
| `GestureSignatureRecordingSheet` | Sheet chrome, confirm/cancel |
| `GestureSignaturePicker` | Divider, custom grid, +, sheet, scroll-to-selection |
| `SettingsViewModel` | Mutate `gestureConfiguration.customGestureSignatures`, persist |
| `GestureFlowApplication` | Pause/resume engine around sheet |

## Error Handling

| Case | Behavior |
| --- | --- |
| No valid stroke | Confirm disabled |
| Duplicate | Select existing; no duplicate append |
| Save failure | Show error on settings row; keep sheet closed |
| Engine stop/start failure | Log; do not block sheet |

## Testing

### GestureFlowCore

- `GestureConfiguration` encodes/decodes `customGestureSignatures`
- Recording coordinate system: vertical drag → `down`, horizontal → `left`/`right` as expected

### GestureFlowApp

- Confirm appends custom signature and persists
- Confirm duplicate selects built-in or prior custom without growing list
- Cancel does not mutate configuration
- Sheet sets `gestureEngine.isRunning` false while presented (mock engine)

## Related Specs

- `docs/superpowers/specs/2026-05-24-gesture-signature-preview-design.md` — glyph rendering (reuse)
