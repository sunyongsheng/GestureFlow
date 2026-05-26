# Configuration Directory Adoption Design

**Goal**

When the user changes the configuration directory to a path that already contains `config.yaml` and/or `gestures.yaml`, show a confirmation dialog instead of rejecting the change. If the user confirms, validate configuration content, adopt the target directory (merge missing files from the old directory), switch `UserDefaults`, delete business YAML from the old directory, and hot-reload in-process.

**Out Of Scope**

- Listing detected filenames in the dialog.
- Finder / `NSOpenPanel` directory picker.
- Overwriting files that already exist in the target directory.
- JSON or legacy format support.
- Automatic corrupt-file recovery during relocation (strict validation only; normal startup recovery unchanged).

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Approach | **Scheme 1**: Core detection + execution modes; dialog in App (`SettingsViewModel` + SwiftUI alert). |
| Target has no YAML | Existing flow: copy current directory files to target, save path, delete old YAML, hot reload. |
| Target has any YAML | Show confirmation dialog before disk changes. |
| Dialog title | `检测到目标目录已有配置文件，是否覆盖当前配置？` |
| Dialog body | Short summary only (no per-file list). |
| **是** | Validate → merge → save path → delete old YAML → hot reload. |
| **否** | Cancel: no path change, no disk changes, no error banner (user may keep editing). |
| Partial target files | Dialog still shown; after **是**, keep existing target files, copy only missing files from old directory. |
| Old directory cleanup (after **是**) | Delete `config.yaml` and `gestures.yaml` from previous directory (same as empty-target success). |
| Validation timing | After **是**, **before** any merge copy, UserDefaults write, or old-file deletion. |
| Validation strictness | Use strict `load()` (YAML decode), not `loadRecovering()`. |
| Validation scope | Every file that will be used after adoption: exists at target → decode target; missing at target but exists at old → decode old; missing at both → skip (runtime defaults). |
| Validation failure | Abort entire operation; show localized error in settings; persisted path and in-memory config unchanged. |
| Adopt mode pre-save | Do **not** persist in-memory config to the old directory before switching (differs from empty-target relocate). |

## User Flow

```
Confirm path change
  → normalize & validate path (writable, ≠ current)
  → targetHasConfigurationFiles?
       no  → relocate(mode: copyCurrentToEmptyTarget)
       yes → show alert
              否 → return (silent cancel)
              是 → preflight validate
                     fail → configurationDirectoryErrorMessage, return
                     ok   → relocate(mode: adoptTargetAndMergeMissing)
                            → hot reload
```

## Core (`GestureFlowCore`)

### `ConfigurationDirectoryRelocationMode`

- `copyCurrentToEmptyTarget` — current behavior when target has no business YAML.
- `adoptTargetAndMergeMissing` — user confirmed adoption.

### `ConfigurationDirectoryRelocator`

- `targetHasConfigurationFiles(at path: String) -> Bool` — `true` if either `config.yaml` or `gestures.yaml` exists at the normalized target URL.
- `relocate(from:to:mode:)` — `mode` selects copy vs adopt/merge behavior.
- Remove throwing `targetContainsConfigurationFiles` for non-empty targets (replaced by App dialog + adopt mode).

**`copyCurrentToEmptyTarget`**

Unchanged from today: create target if needed, copy existing files from old directory, save `UserDefaults`, delete old business YAML.

**`adoptTargetAndMergeMissing`**

1. Create target directory if missing; validate writable directory.
2. Run `validateConfigurationForAdoption(target:old:)` (see below). On failure, throw new error e.g. `invalidConfigurationContent` with user-facing description.
3. For each file in `ConfigurationFileNames.configurationDirectoryFiles`:
   - Target exists → leave unchanged.
   - Target missing, old exists → copy old → target.
4. Save configuration directory to `UserDefaults`.
5. Delete business YAML from old directory.
6. Return new directory URL.

### `ConfigurationDirectoryValidator` (new, or methods on relocator)

`validateConfigurationForAdoption(targetDirectory:oldDirectory:)` throws:

| File | Rule |
| --- | --- |
| `config.yaml` at target | `ConfigurationStore(fileURL:).load()` |
| `config.yaml` only at old | `ConfigurationStore(fileURL:).load()` on old path |
| Neither | no-op |
| `gestures.yaml` at target | `GestureConfigurationStore(fileURL:).load()` |
| `gestures.yaml` only at old | `GestureConfigurationStore(fileURL:).load()` on old path |
| Neither | no-op |

Any decode error propagates as `invalidConfigurationContent` (localized: e.g. `目标目录中的配置文件无效，请检查后重试。`).

## App Layer

### `SettingsViewModel`

- State: `showConfigurationDirectoryAdoptionAlert`, `pendingConfigurationDirectoryPath` (optional).
- `confirmConfigurationDirectoryChange()`:
  - If `targetHasConfigurationFiles` → set pending path, show alert.
  - Else → `relocateConfigurationDirectory(path, mode: .copyCurrentToEmptyTarget)`.
- Alert **否** → clear pending, no error.
- Alert **是** → `relocateConfigurationDirectory(path, mode: .adoptTargetAndMergeMissing)`; on success update `persistedConfigurationDirectoryPath`; on failure set `configurationDirectoryErrorMessage`.

### `GestureFlowApplication.relocateConfigurationDirectory(to:mode:)`

- `copyCurrentToEmptyTarget`: keep saving in-memory config to current store before relocate (today’s behavior).
- `adoptTargetAndMergeMissing`: **skip** pre-relocate save to old directory; after relocator returns, rebind stores and `load()` / `gestureConfigurationService.load()` (may use `loadRecovering()` only for normal post-reload if desired — preflight already strict).

### UI

- SwiftUI `.alert` bound to ViewModel state on General settings (or shared settings shell).
- Title: fixed string above.
- Message: short explanatory text (one or two sentences).

## Error Handling

| Failure | Behavior |
| --- | --- |
| User **否** | No-op |
| Preflight invalid YAML | Error message; no copy, no UserDefaults, no delete |
| Copy merge failure | `copyFailed`; no UserDefaults, no delete |
| UserDefaults write failure | `configurationDirectoryWriteFailed`; copies may remain on disk — document as best-effort (same class as today) |

## Testing

### Core

- `targetHasConfigurationFiles` true/false.
- Empty target: copy mode unchanged.
- Adopt: target has both files — no overwrite; old YAML removed after success.
- Adopt: target has only `config.yaml` — copies `gestures.yaml` from old when valid.
- Adopt: invalid YAML at target — throws before any copy/UserDefaults/delete.
- Adopt: valid target, invalid gestures at old (to be merged) — throws before mutation.

### App

- Alert cancel does not call relocator adopt.
- Alert confirm calls adopt mode and updates persisted path on success.
- Invalid target shows error, persisted unchanged.

## Related Specs

- `docs/superpowers/specs/2026-05-24-config-directory-design.md` — base directory mechanics (update target-has-files row when implementing).
