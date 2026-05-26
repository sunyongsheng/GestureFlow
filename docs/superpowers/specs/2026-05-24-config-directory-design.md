# Configurable Configuration Directory Design

**Goal**

Allow users to choose where GestureFlow stores `config.yaml` and `gestures.yaml`, so configs can live in a synced folder (iCloud, Dropbox, etc.). The configuration directory path is stored in `UserDefaults` before any other configuration loads.

**Out Of Scope**

- Finder / `NSOpenPanel` directory picker (paths are typed or pasted only).
- Renaming `gestures.json` to `gesture.json`.
- Security-scoped bookmarks / sandbox bookmark persistence.
- Deleting corrupt backups or other files from the old directory (only the two JSON files).
- Automatic app restart after migration (in-process hot reload instead).

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Configuration directory path | `UserDefaults` key `configurationDirectory` |
| Default (no custom path) | Key absent; use default business directory |
| Default business directory | `~/Library/Application Support/GestureFlow` |
| Missing / invalid stored path | Fall back to default directory; log |
| Business files | `{configurationDirectory}/config.yaml`, `{configurationDirectory}/gestures.yaml` |
| Target dir has existing YAML | Reject migration (do not overwrite) |
| Old dir cleanup | Delete only `config.yaml` and `gestures.yaml` from previous directory |
| After migration | Hot reload stores + runtime in-process (no restart) |
| General settings UI | Column: title + subtitle; row: `TextField` + **确认** (no **更改** button) |
| Confirm button | Disabled until draft path ≠ persisted path |
| Path entry | Manual input / paste only |

## Architecture

### Two-Phase Configuration Loading

```
Phase 1 (UserDefaults)
  configurationDirectory key  →  configurationDirectory URL (or default)

Phase 2 (resolved directory)
  config.yaml             →  AppConfiguration
  gestures.yaml           →  GestureConfiguration
```

`configurationDirectory` must **not** be stored in `config.json` (chicken-and-egg).

### Core Components (`GestureFlowCore`)

**`ConfigurationDirectoryStore`**

- `UserDefaults` key: `configurationDirectory` (absolute path string)
- Custom path → set key; default path → remove key (no entry)
**`ConfigurationDirectoryResolver`**

- `static let bootstrapBaseURL` → `…/Application Support/GestureFlow`
- `bootstrap()` → resolves effective `configurationDirectoryURL`
- Validates directory (exists, is directory, writable); invalid → default directory + log
- `configFileURL`, `gesturesFileURL`
- Factory methods for `ConfigurationStore` / `GestureConfigurationStore` bound to resolved directory

**Existing stores**

- `ConfigurationStore` / `GestureConfigurationStore` keep `fileURL` injection; `defaultFileURL()` may delegate to resolver default for backward-compatible tests or be deprecated in favor of explicit resolver usage.

### App Layer

**Startup (`GestureFlowApplication`)**

1. `let resolver = ConfigurationDirectoryResolver.bootstrap()`
2. Build stores from resolver URLs
3. `loadRecovering()` + `gestureConfigurationService.load()`

**Relocate (`ConfigurationDirectoryRelocator` or method on application)**

Triggered by settings **确认** after validation.

**Hot reload**

1. `resolver.apply(configurationDirectory:)`
2. Replace `configurationStore` / gesture store on service
3. Reload configuration + gestures into `runtimeState`
4. Reconcile gesture engine running state
5. Update existing `SettingsViewModel` paths and models; sync `draft` = `persisted`

## General Settings UI

Placement in `GeneralSettingsView`: between **手势识别** and **辅助功能**.

```
配置目录
自定义配置目录以实现配置同步

[ TextField — draft path, max width ] [ 确认 — disabled until changed ]
```

- Display persisted path with `~` home shortening; draft uses same formatting rules.
- Path normalization before compare: expand `~`, absolute URL, standardized/symlink-resolved.
- Errors below the row: `configurationDirectoryErrorMessage`.
- While relocating: disable field and button; optional progress on confirm.

## Migration Flow (Confirm)

### Pre-migrate

1. `save` current `config.json` and `gestures.json` to **old** directory from memory.
2. If either save fails → abort with message.

### Validate draft directory

| Check | On failure |
| --- | --- |
| Non-empty, parseable path | Show validation error |
| Exists | Directory does not exist |
| Is directory | Not a folder path |
| Writable | Directory is not writable |
| No `config.json` in target | Target already has configuration files |
| No `gestures.json` in target | (same message as above) |
| ≠ current effective directory | No-op (confirm should be disabled) |

### Execute

1. Create target directory if needed.
2. Copy `config.json` / `gestures.json` from old directory if they exist.
3. Save new path to `UserDefaults` (`configurationDirectory` key).
4. Delete `config.yaml` and `gestures.yaml` from **old** directory only (not `.corrupt-*` backups).
5. Run hot reload (§4 in brainstorming).

### Failure semantics

| Failure point | Behavior |
| --- | --- |
| Validation | No disk changes |
| Copy | No UserDefaults update; no delete |
| UserDefaults write | No delete of old files; copies may remain in target |
| Delete old YAML | Log warning; continue hot reload if UserDefaults + copy succeeded |
| Hot reload load | Show error; do not auto-rewrite UserDefaults path |

## File Locations Reference

| File | Location |
| --- | --- |
| Configuration directory path | `UserDefaults` key `configurationDirectory` |
| `config.yaml` | `{configurationDirectory}/config.yaml` |
| `gestures.yaml` | `{configurationDirectory}/gestures.yaml` |

## Testing

### GestureFlowCore

- `ConfigurationDirectoryStore` read/write, default path clears key
- `ConfigurationDirectoryResolver.bootstrap` — missing key, valid custom path, invalid path falls back
- Path normalization equivalence (`~` vs absolute)
- Relocator validation — target with existing JSON rejected

### GestureFlowApp

- `SettingsViewModel` — confirm disabled/enabled from draft vs persisted
- Relocate + hot reload updates in-memory configuration and store URLs
- `GeneralSettingsView` / view model integration (optional snapshot or logic tests)

## Related Code

- `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift`
- `Sources/GestureFlowCore/Configuration/ConfigurationStore.swift`
- `Sources/GestureFlowCore/Configuration/GestureConfigurationStore.swift`
- `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
