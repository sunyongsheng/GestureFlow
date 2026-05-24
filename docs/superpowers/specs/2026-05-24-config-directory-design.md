# Configurable Configuration Directory Design

**Goal**

Allow users to choose where GestureFlow stores `config.json` and `gestures.json`, so configs can live in a synced folder (iCloud, Dropbox, etc.). Bootstrap path is always read from a fixed standalone file before any other configuration loads.

**Out Of Scope**

- Finder / `NSOpenPanel` directory picker (paths are typed or pasted only).
- Renaming `gestures.json` to `gesture.json`.
- Security-scoped bookmarks / sandbox bookmark persistence.
- Deleting corrupt backups or other files from the old directory (only the two JSON files).
- Automatic app restart after migration (in-process hot reload instead).

## Decisions Summary

| Topic | Decision |
| --- | --- |
| Bootstrap file | `~/Library/Application Support/GestureFlow/config_standalone.json` (never moves) |
| Bootstrap content | `{ "configurationDirectory": "<absolute path>" }` only |
| Default business directory | `~/Library/Application Support/GestureFlow` |
| Missing / corrupt standalone | Fall back to default directory; optional corrupt backup |
| Default path in standalone | Always written explicitly when user confirms (even if equal to default) |
| Business files | `{configurationDirectory}/config.json`, `{configurationDirectory}/gestures.json` |
| Target dir has existing JSON | Reject migration (do not overwrite) |
| Old dir cleanup | Delete only `config.json` and `gestures.json` from previous directory |
| After migration | Hot reload stores + runtime in-process (no restart) |
| General settings UI | Column: title + subtitle; row: `TextField` + **确认** (no **更改** button) |
| Confirm button | Disabled until draft path ≠ persisted path |
| Path entry | Manual input / paste only |

## Architecture

### Two-Phase Configuration Loading

```
Phase 1 (fixed location)
  config_standalone.json  →  configurationDirectory URL

Phase 2 (resolved directory)
  config.json             →  AppConfiguration
  gestures.json           →  GestureConfiguration
```

`configurationDirectory` must **not** be stored in `config.json` (chicken-and-egg).

### Core Components (`GestureFlowCore`)

**`StandaloneConfiguration`**

```json
{
  "configurationDirectory": "/Users/you/Library/Application Support/GestureFlow"
}
```

**`StandaloneConfigurationStore`**

- Fixed URL: `Application Support/GestureFlow/config_standalone.json`
- `load()` / `save(_:)` with corrupt-file backup pattern aligned with `ConfigurationStore`

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
3. Write `config_standalone.json` at bootstrap location with new absolute path.
4. Delete `config.json` and `gestures.json` from **old** directory only (not standalone, not `.corrupt-*`).
5. Run hot reload (§4 in brainstorming).

### Failure semantics

| Failure point | Behavior |
| --- | --- |
| Validation | No disk changes |
| Copy | No standalone update; no delete |
| Standalone write | No delete of old files; copies may remain in target |
| Delete old JSON | Log warning; continue hot reload if standalone + copy succeeded |
| Hot reload load | Show error; do not auto-rewrite standalone |

## File Locations Reference

| File | Location |
| --- | --- |
| `config_standalone.json` | `~/Library/Application Support/GestureFlow/` (always) |
| `config.json` | `{configurationDirectory}/config.json` |
| `gestures.json` | `{configurationDirectory}/gestures.json` |

## Testing

### GestureFlowCore

- `StandaloneConfigurationStore` read/write, missing file, corrupt backup
- `ConfigurationDirectoryResolver.bootstrap` — no standalone, valid standalone, corrupt standalone, invalid directory in standalone
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
