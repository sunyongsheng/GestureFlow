# Gesture Target Application Settings Design

**Goal**

Add a setting under **Settings → 界面 → 触发** titled **手势目标应用** that controls which application is used for **both** gesture rule matching and keyboard shortcut delivery. Default is **鼠标下方应用**.

**Approved decisions**

| Topic | Decision |
| --- | --- |
| Setting title | 手势目标应用 |
| Scope (B) | Same target for `ScopedGestureMatcher` and shortcut execution |
| Config location | `AppConfiguration.gestureTargetApplication` (top-level, not inside trigger sliders) |
| Default | `underMouse` |
| Sample point | **Gesture start point** (first point of stroke / mouse-down), not release |
| Under-mouse miss | `actionFailed` (do not silently fall back to global-only matching) |
| Implementation approach | Resolver + `CGWindowList` hit test + `CGEvent.postToPid` (no focus steal) |

**Out of scope**

- Per-gesture override of target application
- Trackpad gestures
- Changing the Gestures page app list semantics

## UI Copy

| Element | Text |
| --- | --- |
| Title | 手势目标应用 |
| Description | 决定按哪个应用匹配手势规则，以及手势快捷键发往哪个应用。 |
| Option | 当前前台应用 |
| Option (default) | 鼠标下方应用 |

Placement: top of the **触发** card in `GestureTriggerSettingsView`, above movement/hold/sample sliders. Control: `SettingsValueRow` + `Picker` (menu or segmented).

## Configuration

```swift
public enum GestureTargetApplication: String, Codable, CaseIterable, Sendable {
    case foreground   // 当前前台应用
    case underMouse   // 鼠标下方应用
}
```

**`AppConfiguration`**

- New field: `gestureTargetApplication: GestureTargetApplication`
- Default: `.underMouse`
- Decode: missing key → `.underMouse` (backfill on load)

Persisted in existing `config.json` via `ConfigurationStore`.

## Runtime Architecture

### Components

1. **`GestureTargetApplicationResolver`**
   - Input: `GestureTargetApplication` policy, `GesturePoint` start point (screen coordinates)
   - Output: `ResolvedGestureTarget` with `bundleIdentifier: String?`, `processIdentifier: pid_t?`
   - Foreground: `NSWorkspace.shared.frontmostApplication`
   - Under mouse: window hit test at start point (see below)

2. **`GestureEngine`** (modify)
   - On gesture end, read `appConfigurationProvider().gestureTargetApplication`
   - Resolve target from `points.first` (start point)
   - If policy is `.underMouse` and resolution is invalid → `actionFailed` immediately
   - Pass `bundleIdentifier` into `ScopedGestureMatcher` (rename parameter conceptually to `targetBundleIdentifier`)
   - Pass `processIdentifier` into `ActionExecutor` for keyboard shortcuts

3. **`ActionExecutor`** (modify)
   - `execute(_:targetProcessIdentifier:)` for keyboard shortcuts
   - When PID present: `CGEvent.postToPid`
   - When PID absent but shortcut requested: throw / fail (gesture path should not call without PID when target required)

### Data flow

```
Gesture ended (points)
    → startPoint = points.first
    → policy = config.gestureTargetApplication
    → resolver.resolve(policy, startPoint)
        → underMouse + invalid? → actionFailed
    → matcher.match(..., targetBundleIdentifier: bundleId)
        → nil? → unmatched
    → executor.execute(shortcut, targetPID: pid)
        → failure? → actionFailed
```

### Window hit test (under mouse, MVP)

At **start point** screen coordinates, top-down over `CGWindowListCopyWindowInfo`:

- Point inside window bounds
- Normal window layer (`kCGWindowLayer == 0`)
- Visible (`alpha > 0`, reasonable size)
- Exclude: desktop wallpaper layer, Dock, menu bar, GestureFlow own windows, non-interactive system chrome

First match → owner PID → `NSRunningApplication` → bundle ID.

### Matching (`ScopedGestureMatcher`)

Algorithm unchanged; only the bundle ID source changes:

1. Filter enabled + trigger + signature
2. App-specific gesture for resolved bundle ID
3. Else global (`targetBundleIdentifier == nil`)

Parameter rename in API/docs: `foregroundBundleIdentifier` → `targetBundleIdentifier` (behavior-neutral rename).

### Shortcut delivery

- Use `CGEvent.postToPid(_:event:)` when resolved PID is available
- Do **not** activate / focus target app
- Existing `CGEvent.post(tap: .cghidEventTap)` remains for non-targeted call sites (e.g. system commands that emulate shortcuts globally)

## Error and feedback

| Case | Outcome |
| --- | --- |
| Under mouse, no valid window/app at start | `actionFailed` — message e.g. `未找到鼠标下方的应用` |
| Matched gesture, PID missing | `actionFailed` — e.g. `无法发送到目标应用` |
| No matching gesture | `unmatched` (unchanged) |
| Success | `recognized` (unchanged) |

Foreground mode with no frontmost app: treat as unresolved target for matching (global only if bundle ID nil passed to matcher). If a global gesture matches but PID required and missing, `actionFailed`.

## Testing

- `GestureTargetApplicationResolverTests`: foreground mock, window list fixtures, exclusions
- `GestureEngineTests`: under-mouse vs foreground pick different scoped gestures; under-mouse miss → `actionFailed`
- `ActionExecutorTests`: keyboard shortcut uses `postToPid` when PID provided
- `ConfigurationStoreTests`: backfill default `underMouse`

## Related files (implementation hint)

- `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- `Sources/GestureFlowCore/Matching/ScopedGestureMatcher.swift`
- `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- `Sources/GestureFlowApp/Actions/ActionExecutor.swift`
- `Sources/GestureFlowApp/Settings/Appearance/GestureTriggerSettingsView.swift`
- `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
