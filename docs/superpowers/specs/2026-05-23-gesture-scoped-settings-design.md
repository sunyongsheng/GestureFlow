# Gesture-Scoped Settings and Matching Design

**Goal**

Redesign GestureFlow gesture product behavior and settings UI:

- Gestures are scoped per application (Bundle ID) or globally.
- Each gesture binds a keyboard shortcut (no other action types in MVP).
- Settings use a two-column layout: application list + gesture table.
- Runtime matching prefers app-specific gestures over global gestures for the frontmost app.
- Successful recognition feedback shows the matched gesture name.
- Gesture data lives in a dedicated `gestures.json` file, loaded once into memory at startup.

**Out Of Scope (this iteration)**

- Migrating or upgrading legacy combined configuration files.
- Multi-step shortcuts, shortcut-only-modifiers, open URL/app, or system commands on gestures.
- Trackpad gestures.

## Decisions Summary

| Topic | Decision |
| --- | --- |
| App scope identity | Bundle ID only (`String?`, `nil` = global) |
| App display name | Resolved at runtime via system APIs; not stored |
| Trigger | Per gesture: right mouse or middle mouse |
| Uniqueness | `(targetBundleIdentifier, signature, trigger)` |
| Signature catalog | Length 1–3, adjacent directions must differ (52 items); UI labels in Chinese (`下、右`) |
| Shortcut recording | Single key + modifiers (⌘⌥⌃⇧) |
| Config files | `config.json` (general) + `gestures.json` (gestures) |
| Memory model | Parse `gestures.json` once at launch; all runtime/settings use in-memory state |
| Default gestures | On first launch, create `gestures.json` with one built-in global gesture |
| App list | Explicit `+` via Finder; delete removes app entry and all its gestures |
| Matching priority | Frontmost app gestures > global gestures |
| Success feedback | Show gesture `name` |

## Architecture

### Configuration Split

**`config.json`** (existing `ConfigurationStore`):

- `isEnabled`, `feedback`, `trigger` (movement threshold, hold timeout, sample distance), etc.

**`gestures.json`** (new `GestureConfigurationStore`):

```json
{
  "applicationBundleIdentifiers": ["com.apple.Safari"],
  "gestures": [ /* GestureDefinition */ ]
}
```

### In-Memory Service

`GestureConfigurationService` (name may vary) owns the authoritative in-memory `GestureConfiguration`:

1. **Startup `load()`**
   - If `gestures.json` missing: write default file, then parse into memory.
   - If present: parse once into memory.
2. **Reads** (`GestureEngine`, settings UI): use memory only; never read disk per gesture.
3. **Writes** (settings edits): update memory, then persist to `gestures.json` via `save()`.
4. **Save failure**: keep in-memory edits, surface error to user; do not silently reload from disk.

`GestureFlowApplication` constructs the service at launch and injects it into `GestureEngine` and `SettingsViewModel`.

### Core Model Changes

**`GestureDefinition`**

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `UUID` | Generated internally; not shown in UI |
| `targetBundleIdentifier` | `String?` | `nil` = global |
| `name` | `String` | User-editable |
| `trigger` | `GestureTrigger` | `.rightMouse` / `.middleMouse` |
| `signature` | `GestureSignature` | Same as recognizer output |
| `shortcut` | `KeyboardShortcutAction` | Only action type for gestures |
| `isEnabled` | `Bool` | Default `true` |

Remove from gesture MVP surface: `GestureScope`, `openURL`, `openApplication`, `systemCommand` on gestures (may remove from `GestureAction` entirely or keep enum unused—implementation plan should pick one).

**`GestureConfiguration`**

- `applicationBundleIdentifiers: [String]` — ordered list of user-added apps (Finder `+`).
- `gestures: [GestureDefinition]`

**Built-in default (written when creating `gestures.json`)**

- Fixed constant UUID in code (for tests/docs).
- `targetBundleIdentifier`: `nil`
- `name`: `关闭窗口`
- `signature`: `[.down, .right]` (UI: `下、右`)
- `shortcut`: Command+W
- `trigger`: `.rightMouse`
- `isEnabled`: `true`

**`GestureSignatureCatalog`**

- Programmatically generates 52 signatures:
  - Length 1: 4
  - Length 2: 4×3 = 12 (second ≠ first)
  - Length 3: 4×3×3 = 36 (each segment ≠ previous)
- Each entry exposes `GestureSignature` + Chinese `displayName` via `GestureDirection` → `上/下/左/右`.

### Conflict Detection

`ConflictDetector` key becomes:

- `targetBundleIdentifier` (normalize `nil` consistently)
- `signature`
- `trigger`

Only enabled gestures need not be the conflict scope for saving—**all** gestures in file should enforce uniqueness on save (disabled duplicates still confuse users).

### Runtime Matching

**`ScopedGestureMatcher`**

Input:

- `trigger` from active gesture session
- `signature` from `GestureRecognizer`
- `foregroundBundleIdentifier` from `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`
- In-memory `gestures`

Algorithm:

1. Filter: `isEnabled`, matching `trigger`, matching `signature`.
2. If `foregroundBundleIdentifier` non-nil: return first gesture where `targetBundleIdentifier == foregroundBundleIdentifier`.
3. Else return first gesture where `targetBundleIdentifier == nil`.
4. Otherwise `nil` → unmatched.

Recognition pipeline (`MouseEventTap` → `GestureRecognizer`) unchanged.

### Action Execution

Matched gesture executes `shortcut` through existing `ActionExecutor` keyboard path.

### Feedback

| Outcome | Overlay message |
| --- | --- |
| Recognized + matched | Gesture `name` (e.g. `关闭窗口`) |
| Recognized + unmatched | `未找到匹配手势` |
| Rejected (nil signature) | `手势过短` |
| Action failure | `操作失败` (+ error detail if available) |

`GestureEngineFeedback.recognized` should carry `name` for logging/tests.

## Settings UI

Replace card-based `GestureListView` / `GestureEditorView` with **`GestureSettingsView`**.

### Layout

Two columns inside the Gestures settings section:

| Left (~220–240pt) | Right (flex) |
| --- | --- |
| **全局** (always first, not deletable) | Table of gestures for selected scope |
| Registered apps (`applicationBundleIdentifiers`) | Toolbar `+` / `-` for gestures |
| `+` opens Finder → select `.app` → add Bundle ID if new | |

- App names: runtime lookup from Bundle ID.
- Selecting **全局** filters `targetBundleIdentifier == nil`.
- Selecting an app filters `targetBundleIdentifier == that ID`.

### Left Column: Delete Application

- Each app row has delete affordance (minus button or context menu).
- **Rule A**: Deleting an app removes its Bundle ID from `applicationBundleIdentifiers` **and** deletes all gestures with that `targetBundleIdentifier`, then `save()`.
- **全局** cannot be deleted.
- If deletion leaves user on deleted app, selection falls back to **全局**.

### Right Table Columns

| Column | Behavior |
| --- | --- |
| 名称 | Inline edit; save on focus loss / Enter |
| 手势 | Picker from `GestureSignatureCatalog` (Chinese labels) |
| 触发 | Picker: 右键 / 中键 |
| 快捷键 | Click to record; single key + modifiers; Esc cancels |
| 启用 | Checkbox |

**Add gesture (`+`)** defaults:

- `name`: `新手势`
- `signature`: `[.down, .right]` (`下、右`)
- `trigger`: `.rightMouse`
- `shortcut`: empty or placeholder until user records (implementation must define UX for invalid empty shortcut—recommend require recording before enable or block save)
- `isEnabled`: `true`
- `targetBundleIdentifier`: current left selection (`nil` for 全局)

**Delete gesture (`-`)**: remove from memory + `save()`.

All edits update `GestureConfigurationService` memory then persist.

### Removed UI

- Browser back/forward / open URL / system command pickers on gestures.
- Per-gesture scope enum UI.

## File Locations

Default paths under Application Support (same directory as existing config):

- `.../GestureFlow/config.json`
- `.../GestureFlow/gestures.json`

Exact paths follow `ConfigurationStore.defaultFileURL()` directory convention.

## Error Handling

| Case | Behavior |
| --- | --- |
| `gestures.json` corrupt on load | Treat like missing: backup optional per existing store pattern, or fail with recovery banner—**no legacy gesture migration** |
| Save failure | Show settings error banner; retain memory state |
| Duplicate `(scope, signature, trigger)` on save | Reject save; show conflict message |
| Finder selection without Bundle ID | Show error; do not add |
| Duplicate app in list | Ignore or select existing |
| Frontmost app nil | Match global only |
| Empty shortcut on enabled gesture | Block save or disable row until recorded (pick in implementation) |

## Testing

### GestureFlowCore

- `GestureSignatureCatalog` count = 52; no adjacent duplicate tokens in catalog.
- `ConflictDetector` with new key including `targetBundleIdentifier` and `trigger`.
- `ScopedGestureMatcher` priority: app over global; disabled ignored; trigger filter.

### GestureFlowApp

- `GestureConfigurationStore` create-default-file when missing.
- `GestureConfigurationService` load once; mutations reflect without re-read.
- `GestureEngine` uses injected in-memory config; success feedback shows name.
- Settings: add/remove app (A delete rule), table CRUD, conflict banner.

## Implementation Notes

- `SettingsViewModel` holds reference to `GestureConfigurationService` for gesture section; general settings still use `ConfigurationStore`.
- `GestureFlowApplication.startGestureFlow()` passes memory gestures into engine via provider closure reading service.configuration.
- Foreground bundle ID provider injected for tests.
