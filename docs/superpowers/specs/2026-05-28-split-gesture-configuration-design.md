# Split Gesture Configuration (Builtin + Custom) Design

**Goal**

Replace the single `gestures.yaml` with **`gestures-builtin.yaml`** and **`gestures-custom.yaml`**. Built-in gestures are seeded to disk on cold start (not hardcoded at runtime). The app loads both files, merges them for recognition/settings, routes edits by gesture **source**, and surfaces merge ID conflicts in the settings UI.

**Out Of Scope**

- Migrating or reading legacy `gestures.yaml` (no backward compatibility).
- Changing gesture matching semantics beyond merged gesture list input.
- Bundled read-only builtin file inside the app package (builtin is always user-writable YAML on disk).
- Persisting `source` to YAML.

## Confirmed Requirements

| Topic | Decision |
| --- | --- |
| Custom file | `gestures-custom.yaml` — full `GestureConfiguration` shape; `gestures` holds **user gestures only** |
| Builtin file | `gestures-builtin.yaml` — **only** built-in `gestures` list |
| Cold start | If builtin missing → create from `BuiltInGestureSeeds`; if custom missing → empty custom template |
| Load | Read both; merge into one in-memory `GestureConfiguration` for engine/settings |
| Merge conflict (duplicate gesture `id`) | **Do not fail silently** — expose error in **settings UI** (user-visible message) |
| Gesture `source` | Runtime-only: `builtin` \| `custom`; assigned at init/merge; **not encoded** to YAML |
| Edit/delete routing | Use `source` to choose builtin vs custom file on save |
| New gesture | Always `custom` → `gestures-custom.yaml` |
| Restore defaults | Reset custom to empty template **and** overwrite builtin with `BuiltInGestureSeeds` |
| Localization | `BuiltInGestureSeeds.closeWindowID` for built-in close-window display name (not `GestureConfiguration.closeWindowGestureID` long-term if renamed) |
| Hardcoded builtin | Remove `GestureDefinition.builtInCloseWindow` and builtin entries from `defaultTemplate` |

## File Layout

```
{configurationDirectory}/
  config.yaml
  gestures-builtin.yaml    # gestures: [ built-in only ]
  gestures-custom.yaml     # applicationBundleIdentifiers, gestures (user), customGestureSignatures
```

**`ConfigurationFileNames`**

- Remove `gestures.yaml`.
- Add `gesturesBuiltin = "gestures-builtin.yaml"`, `gesturesCustom = "gestures-custom.yaml"`.
- `configurationDirectoryFiles = [config, gesturesBuiltin, gesturesCustom]`.

## YAML Shapes

**`gestures-builtin.yaml`** (minimal on disk; decode via shared `GestureConfiguration` or a slim `BuiltinGesturesFile` with only `gestures`):

```yaml
gestures:
  - id: A7C4E1B2-3D5F-4A89-9C0E-1F2A3B4C5D6E
    name: 关闭窗口
    trigger: rightMouse
    signature: [down, right]
    shortcut: ...
```

**`gestures-custom.yaml`** (empty template):

```yaml
applicationBundleIdentifiers: []
gestures: []
customGestureSignatures: []
```

## Runtime Model

### `GestureSource` (new, `GestureFlowCore`)

```swift
public enum GestureSource: Equatable {
    case builtin
    case custom
}
```

### `GestureDefinition` extension

- Add `var source: GestureSource` — **not** in `CodingKeys`; default `.custom` for decode-only paths; overwritten when building merged configuration.
- `init(from:)` leaves `source = .custom` (disk never stores it).

### `BuiltInGestureSeeds` (new, `GestureFlowCore`)

- `static let closeWindowID: UUID` — stable UUID for localization and seed content.
- `static func factoryGestures() -> [GestureDefinition]` — returns built-in gestures for **file creation / restore only** (replaces `GestureDefinition.builtInCloseWindow`).
- Seed `name` may remain Chinese literal on disk; UI uses `closeWindowID` + L10n for display.

### Merge

```text
merged.applicationBundleIdentifiers = custom.applicationBundleIdentifiers
merged.customGestureSignatures     = custom.customGestureSignatures
merged.gestures                    = builtin.gestures (source=.builtin)
                                   + custom.gestures (source=.custom)
```

**Conflict detection**

- After tagging sources, if duplicate `id` appears in both lists → `GestureConfigurationMergeResult.conflicts: [UUID]` (or dedicated error type).
- Loader returns merged config **and** conflict set; service keeps conflicts for settings banner/error string.
- Engine may still run with last-wins or exclude duplicates — **prefer blocking save** until user resolves; show settings error like duplicate-gesture UX.

### Localization

- `LocalizationManager.localizedGestureDisplayName(id:storedName:)` compares `id == BuiltInGestureSeeds.closeWindowID` (migrate from `GestureConfiguration.closeWindowGestureID`).
- Deprecate/remove `GestureConfiguration.closeWindowGestureID` once call sites updated.

## Architecture

### Components (`GestureFlowCore`)

| Component | Responsibility |
| --- | --- |
| `ConfigurationFileNames` | Builtin/custom filenames; directory file list |
| `ConfigurationDirectoryResolver` | `gesturesBuiltinFileURL`, `gesturesCustomFileURL`; factory methods for two stores |
| `GestureConfigurationStore` | Unchanged `load`/`save` per `fileURL` |
| `BuiltInGestureSeeds` | Factory gestures + `closeWindowID` |
| `SplitGestureConfigurationLoader` | Bootstrap missing files; load both; merge; detect ID conflicts |
| `GestureConfigurationMergeResult` | `configuration: GestureConfiguration`, `conflictingGestureIDs: [UUID]` |

### App layer

| Component | Responsibility |
| --- | --- |
| `GestureConfigurationService` | Holds merged config + conflict IDs; `load()` bootstraps; split `save` by `source`; `restoreDefaults()` |
| `SettingsViewModel` | Surface merge conflicts (`gestureLoadErrorMessage` or reuse save error channel); restore defaults |
| `GestureSettingsView` | No UX change beyond error display if conflicts |

### Load / bootstrap flow

```
GestureConfigurationService.load()
  → if !exists(builtin): write BuiltInGestureSeeds.factoryGestures() to gestures-builtin.yaml
  → if !exists(custom): write empty custom template
  → builtin = store(builtinURL).load()
  → custom = store(customURL).load()
  → result = SplitGestureConfigurationLoader.merge(builtin, custom)
  → configuration = result.configuration
  → mergeConflictIDs = result.conflictingGestureIDs
```

### Save flow

```
User edits gesture G
  → switch G.source
       .builtin → read builtin file, mutate gestures[], save builtin file
       .custom  → read custom file, mutate gestures[], save custom file
  → reload merge into service.configuration
```

`applicationBundleIdentifiers` / `customGestureSignatures` changes → custom file only, then re-merge.

### Restore defaults

```
write empty custom template to gestures-custom.yaml
write BuiltInGestureSeeds.factoryGestures() to gestures-builtin.yaml
reload merge; clear conflict state if resolved
```

## Configuration Directory Integration

- **Validator**: validate builtin and custom files when present (same rules as today for gesture content).
- **Relocator / adoption**: copy/delete **both** gesture files; `targetHasConfigurationFiles` true if either gesture file or `config.yaml` exists.
- Tests: replace all `gestures.yaml` paths with builtin/custom fixtures.

## Testing

| Area | Cases |
| --- | --- |
| Merge | Builtin + custom → correct list and `source` tags |
| Conflict | Same `id` in both files → conflict IDs returned; settings model exposes message |
| Bootstrap | Missing both files → both created with expected content |
| Restore | Custom cleared; builtin reset to factory |
| Save routing | Edit builtin gesture → only builtin file changes on disk |
| Localization | `closeWindowID` still localizes built-in name |
| Directory | Relocator copies/deletes two gesture files |

## Migration Note

**No** automatic import from `gestures.yaml`. Fresh installs and dev environments use the new filenames only.
