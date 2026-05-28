# App Language Settings Design

**Goal**

Add an **应用语言** control in General settings so users can switch between **中文（简体）** and **English**. The choice is stored in `AppConfiguration`, applies to the **entire app** (settings UI, menu bar, overlay copy, fixed error strings), and takes effect **immediately without restart**.

**Out Of Scope**

- Follow-system language.
- Languages beyond `zh-Hans` and `en`.
- Translating user-defined content (gesture names, shortcut labels, app names, URLs, directory paths).
- Localizing third-party or OS error strings we do not own.
- Changing product branding strings (`GestureFlow`, status item `GF` abbreviations).

## Confirmed Requirements

| Topic | Decision |
| --- | --- |
| Coverage | Whole app (option A) |
| Effect timing | Full immediate refresh, no restart prompt (option A2) |
| UI placement | Same control card as launch-at-login / gesture recognition; **below gesture recognition**, above configuration directory |
| Row title | **应用语言** (localized via L10n key) |
| Row control | `Picker`: 中文（简体） / English (self-names, not translated) |
| Persistence | `AppConfiguration.general.language` (syncs with config directory) |
| Default | `zh-Hans` when missing or invalid |

## Architecture

### Configuration (`GestureFlowCore`)

```yaml
general:
  language: zh-Hans   # or en
isEnabled: false
feedback: ...
```

**`AppLanguage`** (or equivalent):

- `zhHans` → encodes as `zh-Hans`
- `en` → encodes as `en`

**`GeneralConfiguration`**

- `language: AppLanguage`
- Nested under `AppConfiguration` as `general: GeneralConfiguration`
- Decode: `decodeIfPresent` with default `.zhHans`; unknown raw value → `.zhHans`
- Encode: stable string tokens only

### Localization Runtime (`GestureFlowApp`)

Do **not** rely on `Bundle.main` default localization (follows system locale). Use a dedicated runtime layer:

**`LocalizationManager`** (`ObservableObject`)

- Holds `language: AppLanguage`
- `func string(_ key: L10nKey) -> String`
- On `setLanguage`: update state, publish change (`@Published` / `objectWillChange` + optional `Notification`)
- Initialized from loaded `AppConfiguration` at app launch

**`L10nKey`**

- Stable keys grouped by domain: `general.*`, `settings.*`, `statusBar.*`, `overlay.*`, `errors.*`, etc.
- All user-visible fixed copy references keys, not inline Chinese/English strings

**String tables**

- Recommended: Swift static dictionaries split by language (`L10nStrings+zh.swift`, `L10nStrings+en.swift`) for SPM simplicity and testability
- Alternative: `.strings` resources loaded from language-specific bundle paths at runtime

**Composition root**

- Single shared instance owned by `GestureFlowApplication`, injected into `SettingsViewModel`, `StatusBarController`, overlay pipeline, and SwiftUI root
- `SettingsWindowDependencies` / `makeSettingsViewModel` pass the same instance

### Language Change Flow

```
User changes Picker (General settings)
  → update viewModel.configuration.general.language
  → saveConfiguration (existing path)
  → on success: localizationManager.setLanguage(...)
  → broadcast refresh
      → SwiftUI: environment object triggers re-render
      → StatusBarController: rebuild menu titles / tooltip
      → Overlay: re-resolve visible feedback strings
      → Command menu: refresh "Settings…" label if applicable
```

If save fails: do **not** change `LocalizationManager`; show existing save error UX.

### UI: General Settings

Within existing control card, order:

1. Launch at login
2. Divider
3. Gesture recognition
4. Divider
5. **应用语言** + description + language `Picker`
6. Divider
7. Configuration directory (unchanged)

Picker labels (fixed, not localized):

- `中文（简体）`
- `English`

### SwiftUI Integration

- Inject `.environmentObject(localizationManager)` at `SettingsRootView`
- Replace hardcoded `Text("…")` and `SettingsSection.title` static strings with `l10n.string(.…)`
- `GestureFlowShellApp` `CommandGroup` settings button uses same manager (via shared dependency access)

### AppKit / Overlay Integration

**`StatusBarController`**

- Remove `StatusBarMenuCopy` hardcoded Chinese
- Localize menu item titles and tooltip via `LocalizationManager`
- Keep **tag-based** actions (`StatusBarMenuItemTag`); tests must not depend on localized titles for behavior

**Overlay**

- `GestureFeedbackCopy` and similar display strings resolved at render time from manager
- Engine keeps semantic completions (e.g. `.unmatched`); presentation layer maps to localized copy

**Errors**

- App-defined messages (`ConfigurationDirectoryRelocator`, `SettingsViewModel` validation, etc.) use L10n keys
- Unmapped system errors may pass through unchanged

### What Not To Translate

- User gesture names and custom signatures
- Shortcut display strings derived from user input
- Application names, URLs, file paths
- `GestureFlow` brand name and `GF` status item abbreviation (menu **actions** still localized)

## Error Handling

| Situation | Behavior |
| --- | --- |
| Save fails on language change | Keep prior language in UI and manager; surface existing save error |
| Invalid `language` in YAML | Decode as `zh-Hans`; optional log |
| Missing key in string table (dev) | Assert in DEBUG; RELEASE fallback to key raw value or English string |
| Language changes while menu open | Refresh titles on next `update` / notification; acceptable if open menu shows stale text until closed |
| Language changes while overlay card visible | Re-call overlay show path with same semantic state to refresh message text |

## Testing

**Core**

- `GeneralConfiguration` / `AppLanguage` round-trip encode-decode
- Default and unknown language fallback

**App**

- `LocalizationManager`: representative keys in both languages
- After `setLanguage(.en)`, spot-check settings sidebar title and status bar menu title change
- Status bar actions: use **tags**, not localized titles
- General settings: language binding writes `configuration.general.language`

## Implementation Phases

Single feature, but work is ordered to keep the app buildable:

1. **Foundation** — `AppLanguage`, `GeneralConfiguration`, YAML migration, tests
2. **LocalizationManager + string tables** — core keys for General + sidebar + status bar
3. **Wire composition root** — launch init, `SettingsViewModel` binding, General settings Picker
4. **SwiftUI sweep** — settings pages, commands, permission/about/advanced/gestures
5. **AppKit / overlay / engine-facing copy** — menu bar, overlay feedback, fixed errors
6. **Test pass + gap fill** — integration tests for language switch without restart

## Related Files (expected touch points)

- `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift`
- `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
- `Sources/GestureFlowApp/Settings/Shell/SettingsSidebarModels.swift`
- `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- `Sources/GestureFlowApp/Menu/StatusBarController.swift`
- `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`
- `Sources/GestureFlowApp/App/GestureFlowShellApp.swift`
- New: `LocalizationManager.swift`, `L10nKey.swift`, string table files
