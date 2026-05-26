# Configurable Configuration Directory Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users set a custom directory for `config.yaml` and `gestures.yaml` via `UserDefaults`, with General settings UI (TextField + 确认) and in-process hot reload after migration.

**Architecture:** Add `ConfigurationDirectoryStore` + `ConfigurationDirectoryResolver` in GestureFlowCore. App startup and settings confirmation use `ConfigurationDirectoryRelocator` to copy YAML, update UserDefaults, delete old business files, and rebuild stores without restart.

**Tech Stack:** Swift, SwiftUI, AppKit (`TextField` only — no `NSOpenPanel`), GestureFlowCore JSON stores, XCTest.

**Spec:** `docs/superpowers/specs/2026-05-24-config-directory-design.md`

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryStore.swift` | UserDefaults read/write for configuration directory path |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryResolver.swift` | Bootstrap, URLs, validation, store factories |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryRelocator.swift` | Validate, copy, update UserDefaults, delete old YAML |
| `Sources/GestureFlowCore/Configuration/ConfigurationPathFormatting.swift` | `~` shorten/expand + URL normalization |
| `Sources/GestureFlowCore/Configuration/ConfigurationStore.swift` | Delegate default directory to resolver (minimal change) |
| `Sources/GestureFlowCore/Configuration/GestureConfigurationStore.swift` | Same |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Bootstrap init, relocate + hot reload |
| `Sources/GestureFlowApp/Services/GestureConfigurationService.swift` | `reload(store:)` after directory change |
| `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift` | Draft/persisted path, confirm, errors |
| `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift` | Config directory UI block |
| `Tests/GestureFlowCoreTests/...` | Store, resolver, relocator, path formatting |
| `Tests/GestureFlowAppTests/Settings/...` | ViewModel confirm + relocate wiring |

---

### Task 1: Configuration directory UserDefaults store

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryStore.swift`
- Test: `Tests/GestureFlowCoreTests/ConfigurationDirectoryStoreTests.swift`

- [ ] **Step 1: Write failing tests** for load missing → nil, round-trip save/load, default path clears key.

- [ ] **Step 2: Run tests** — expect failure.

```bash
swift test --filter ConfigurationDirectoryStoreTests
```

- [ ] **Step 3: Implement** `ConfigurationDirectoryStore` with `UserDefaults` key `configurationDirectory`.

- [ ] **Step 4: Run tests** — expect pass.

---

### Task 2: Path formatting and directory resolver

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationPathFormatting.swift`
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryResolver.swift`
- Test: `Tests/GestureFlowCoreTests/ConfigurationDirectoryResolverTests.swift`
- Test: `Tests/GestureFlowCoreTests/ConfigurationPathFormattingTests.swift`

- [ ] **Step 1: Write failing tests** for `~` expand/shorten, URL normalization equality, `bootstrap()` with no standalone → default dir, with standalone → custom dir, invalid standalone path → default, corrupt standalone → backup + default.

- [ ] **Step 2: Run tests** — expect failure.

- [ ] **Step 3: Implement** resolver with `bootstrapBaseURL`, `configurationDirectoryURL`, `configFileURL`, `gesturesFileURL`, `makeConfigurationStore()`, `makeGestureConfigurationStore()`, directory validation (exists, directory, writable).

- [ ] **Step 4: Run tests** — expect pass.

---

### Task 3: Directory relocator

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryRelocator.swift`
- Test: `Tests/GestureFlowCoreTests/ConfigurationDirectoryRelocatorTests.swift`

- [ ] **Step 1: Write failing tests** using temp directories:
  - reject when target has `config.json` or `gestures.json`
  - reject non-writable / non-directory
  - success copies files, writes standalone, deletes only old `config.json` + `gestures.json`
  - no-op guard when source equals target

- [ ] **Step 2: Run tests** — expect failure.

- [ ] **Step 3: Implement** relocator taking old URL, new URL, file manager, standalone store; return typed errors for UI messages.

- [ ] **Step 4: Run tests** — expect pass.

---

### Task 4: Wire bootstrap into app startup

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowCore/Configuration/ConfigurationStore.swift`
- Modify: `Sources/GestureFlowCore/Configuration/GestureConfigurationStore.swift`
- Test: adjust `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift` if paths assumed

- [ ] **Step 1: Update init** to `ConfigurationDirectoryResolver.bootstrap()`, construct stores from resolver (inject into `GestureFlowApplication` for tests).

- [ ] **Step 2: Run** `swift test --filter GestureFlowApplicationTests` and fix breakages.

- [ ] **Step 3: Keep** `defaultFileURL()` aligned with resolver default for any remaining call sites.

---

### Task 5: Hot reload and relocate on application

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/Services/GestureConfigurationService.swift`
- Test: `Tests/GestureFlowAppTests/ConfigurationDirectoryRelocationTests.swift` (new)

- [ ] **Step 1: Add** `relocateConfigurationDirectory(to:)` on application:
  - pre-save both configs to current stores
  - call relocator
  - replace stores, reload, update `runtimeState`, reconcile engine, refresh `settingsViewModel`

- [ ] **Step 2: Add** `GestureConfigurationService.reload(store:)` or replace internal store reference.

- [ ] **Step 3: Write integration test** with temp dirs verifying in-memory config matches files in new directory after relocate.

- [ ] **Step 4: Run tests** — expect pass.

---

### Task 6: SettingsViewModel path state

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
- Test: `Tests/GestureFlowAppTests/Settings/General/ConfigurationDirectorySettingsTests.swift`

- [ ] **Step 1: Write failing tests** for:
  - `canConfirmConfigurationDirectoryChange` false when draft == persisted
  - true when normalized paths differ
  - `confirmConfigurationDirectoryChange` calls injected relocator closure
  - error message surfaced on failure

- [ ] **Step 2: Implement** `@Published draftConfigurationDirectoryPath`, `persistedConfigurationDirectoryPath`, `isRelocatingConfigurationDirectory`, `configurationDirectoryErrorMessage`, confirm method.

- [ ] **Step 3: Run tests** — expect pass.

---

### Task 7: General settings UI

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift`
- Test: `Tests/GestureFlowAppTests/Settings/General/GeneralSettingsViewConfigurationDirectoryTests.swift` (optional ViewInspector-style or VM-only)

- [ ] **Step 1: Insert** config directory block between gesture recognition and accessibility:
  - title `配置目录`, subtitle `自定义配置目录以实现配置同步`
  - `TextField` bound to draft + **确认** button bound to `canConfirm` / `confirm`

- [ ] **Step 2: Show** error text below row when present.

- [ ] **Step 3: Manual smoke** — launch app, paste temp path, confirm, verify files moved and settings still editable.

---

### Task 8: Full test pass

- [ ] Run `swift test` — all green.

- [ ] Update `docs/superpowers/specs/2026-05-23-gesture-scoped-settings-design.md` file locations note if it still says only default AS path (optional one-line cross-link to new spec).
