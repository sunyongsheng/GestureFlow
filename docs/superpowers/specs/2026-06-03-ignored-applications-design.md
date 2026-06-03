# Ignored Applications Settings Design

**Goal**

Add **Settings → 高级 → 忽略应用** so users can maintain a list of applications where GestureFlow does not intercept mouse events or trigger gestures when that application is the **gesture target** (same semantics as **手势目标应用**).

**Approved decisions**

| Topic | Decision |
| --- | --- |
| Ignore criterion | **B** — match **手势目标应用** resolution (foreground vs under-mouse follows existing policy) |
| Ignored behavior | **A** — complete pass-through at mouse down (no suppress, no trail, no hold timeout, native right/middle click) |
| UI placement | **B** — independent card on Advanced page, between Trigger and Feedback cards |
| Add applications | **B** — file picker (`NSOpenPanel`) **and** submenu of currently running regular apps |
| GestureFlow self | **A** — cannot add self to list; filter self bundle ID on load |
| Config location | `AppConfiguration.ignoredApplicationBundleIdentifiers: [String]`, default `[]` |
| Relation to Gestures page app list | **Independent** — gesture-scoped apps vs global ignore list |
| Restore advanced defaults | Clears ignore list along with trigger/feedback/target settings |
| Implementation approach | `GestureActivationGate` + early check in `MouseEventTap` at right/middle mouse down |

**Out of scope**

- Per-gesture ignore overrides
- Ignore by window title or URL
- Syncing ignore list with gesture configuration app list
- Showing toast/status when an app is ignored

## UI Copy

| Element | Text (zh-Hans) |
| --- | --- |
| Card title | 忽略应用 |
| Card description | 列表中的应用作为手势目标时，GestureFlow 不会拦截鼠标事件或触发手势。 |
| Empty state | 暂无忽略应用 |
| Add button | 添加应用 |
| Menu: from file | 从文件选择… |
| Menu: from running | 从运行中的应用 |
| Running submenu empty | 无可用应用 |
| Remove help | 从忽略列表移除 |

Placement: new `IgnoredApplicationsSettingsView` in `AdvancedSettingsView`, after `GestureTriggerSettingsView`, before `FeedbackSettingsView`.

List rows reuse `ApplicationBundleIconView` + app display name + minus delete control (same visual language as Gestures page app list, but separate data).

## Configuration

```swift
// AppConfiguration
public var ignoredApplicationBundleIdentifiers: [String]  // default []
```

**Persistence**

- Stored in existing app config YAML via `AppConfigurationStore`
- Missing key → `[]`
- On decode/load: remove entries equal to GestureFlow's own bundle identifier (if known)
- Duplicate adds are ignored (set semantics on write)

**Restore defaults**

`SettingsViewModel.restoreDefaultAdvancedSettings()` also sets `ignoredApplicationBundleIdentifiers = []`.

## Runtime Architecture

### Components

1. **`GestureActivationGate`**
   - Input providers: `() -> AppConfiguration` (or ignored IDs + target policy), `GestureTargetResolving`
   - Method: `shouldActivateGesture(at startPoint: GesturePoint) -> Bool`
   - Algorithm:
     1. If ignore list empty → `true`
     2. Resolve target via `targetResolver.resolve(policy: config.gestureTargetApplication, at: startPoint)`
     3. If resolved target invalid (no bundle ID) → `true` (do not treat as ignored; existing under-mouse failure path unchanged)
     4. If bundle ID ∈ ignore list → `false`
     5. Else → `true`

2. **`MouseEventTap`** (modify)
   - New dependency: `gestureActivationGate: (GesturePoint) -> Bool` (default: always `true`)
   - In `beginPendingRightClick(at:)` and `begin(trigger:at:)` (middle mouse):
     - If gate returns `false` → return `.passEvent` immediately (no pending state, no hold timeout)
   - Must run **before** any `.suppressEvent` path

3. **`GestureFlowApplication`** (modify)
   - Construct shared `GestureTargetApplicationResolver` + `GestureActivationGate`
   - Pass gate closure into `MouseEventTap` alongside existing `triggerConfigurationProvider`

4. **`SettingsViewModel`** (modify)
   - `addIgnoredApplicationFromPanel()` — reuse `openApplicationPanel` + bundle ID extraction
   - `addIgnoredApplication(bundleIdentifier:)` — reject self, dedupe, persist
   - `removeIgnoredApplication(bundleIdentifier:)`
   - `runningApplicationsAvailableForIgnore` — `NSWorkspace.shared.runningApplications` filtered to:
     - `activationPolicy == .regular`
     - non-nil bundle ID
     - not GestureFlow bundle
     - not already in ignore list
     - sorted by localized name

### Data flow (ignored app)

```
Right/middle mouse down at point
    → gate.shouldActivateGesture(at: point)
    → resolve target (foreground | underMouse @ point)
    → bundle ID in ignore list?
         yes → passEvent (native click behavior)
         no  → existing suppress / pending / gesture flow
```

### Data flow (settings)

```
User adds app (file or running)
    → ViewModel validates bundle ID
    → append to configuration.ignoredApplicationBundleIdentifiers
    → persist AppConfiguration
    → runtime reads on next mouse down via provider (no restart required)
```

## Error Handling

| Case | Behavior |
| --- | --- |
| File picker: unreadable bundle ID | Show existing `errorBundleIdentifierUnreadable` message |
| Add GestureFlow self | Silent no-op |
| Duplicate bundle ID | Silent no-op |
| YAML contains self bundle ID | Stripped on load |
| Running apps menu empty | Disabled placeholder item |

## Testing

### Unit tests

- `GestureActivationGateTests` — ignored target, non-ignored, invalid target, empty list, self filtered
- `MouseEventTapTests` — ignored target → passEvent on down; non-ignored unchanged
- `AppConfigurationStoreTests` — missing key backfill; self bundle filtered
- `SettingsViewModelTests` — add/remove/dedupe/self rejection; restore defaults clears list

### Manual acceptance

- Ignored Chrome: right-click shows native menu; no GestureFlow trail
- Non-ignored app: gestures work normally
- Under-mouse mode: ignored foreground + non-ignored window under cursor still triggers
- Both add paths work; list persists across relaunch
- GestureFlow never appears as addable target

## Acceptance Criteria

- Users can add/remove ignored applications from Advanced settings via file picker and running-apps menu.
- When the gesture target app is in the ignore list, GestureFlow fully passes through right/middle mouse events.
- Ignore decision follows **手势目标应用** policy, not frontmost app alone when policy is under-mouse.
- Ignore list is independent from gesture rule app scopes.
- GestureFlow cannot be added to the ignore list.
- Restore advanced defaults clears the ignore list.
