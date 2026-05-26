# Configuration Directory Adoption Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When relocating to a directory that already has YAML config files, confirm with the user, strictly validate content on accept, then adopt target configs (merge missing from old) or keep today’s empty-target copy flow.

**Architecture:** `ConfigurationDirectoryRelocator` gains `targetHasConfigurationFiles`, `ConfigurationDirectoryRelocationMode`, and preflight validation. `SettingsViewModel` shows a SwiftUI alert; `GestureFlowApplication` passes mode and skips pre-save on adopt.

**Tech Stack:** Swift, SwiftUI, GestureFlowCore YAML stores, XCTest.

**Spec:** `docs/superpowers/specs/2026-05-26-configuration-directory-adoption-design.md`

---

## File Map

| File | Change |
| --- | --- |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryValidator.swift` | **Create** — strict preflight decode for adoption |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryRelocator.swift` | Modes, adopt/merge, remove reject-on-existing |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryRelocationError.swift` | **Optional split** or extend enum with `invalidConfigurationContent` |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | `relocateConfigurationDirectory(to:mode:)` |
| `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift` | Alert state + branch on detect |
| `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift` | `.alert` wiring |
| `Tests/GestureFlowCoreTests/ConfigurationDirectoryRelocatorTests.swift` | Adopt, merge, validate failures |
| `Tests/GestureFlowCoreTests/ConfigurationDirectoryValidatorTests.swift` | **Create** |
| `Tests/GestureFlowAppTests/Settings/General/ConfigurationDirectorySettingsTests.swift` | Alert cancel/confirm |
| `docs/superpowers/specs/2026-05-24-config-directory-design.md` | Update “target has YAML” row |

---

### Task 1: Validator + relocation error

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryValidator.swift`
- Modify: `ConfigurationDirectoryRelocator.swift` (error enum if colocated)
- Create: `Tests/GestureFlowCoreTests/ConfigurationDirectoryValidatorTests.swift`

- [ ] **Step 1:** Failing tests — valid target config, invalid YAML throws, valid old-only file for merge passes.
- [ ] **Step 2:** Implement validator using `ConfigurationStore.load()` / `GestureConfigurationStore.load()` per design table.
- [ ] **Step 3:** Add `invalidConfigurationContent` localized description.
- [ ] **Step 4:** `swift test --filter ConfigurationDirectoryValidatorTests`

---

### Task 2: Relocator modes

**Files:**
- Modify: `ConfigurationDirectoryRelocator.swift`
- Modify: `Tests/GestureFlowCoreTests/ConfigurationDirectoryRelocatorTests.swift`

- [ ] **Step 1:** Failing tests — `targetHasConfigurationFiles`, adopt with both files (no overwrite), adopt partial merge, empty target still copies.
- [ ] **Step 2:** Implement `ConfigurationDirectoryRelocationMode` and `relocate(from:to:mode:)`.
- [ ] **Step 3:** Remove / replace `targetContainsConfigurationFiles` rejection test with adopt success test.
- [ ] **Step 4:** Failing test — invalid target YAML throws before copy and before UserDefaults save (assert file unchanged).
- [ ] **Step 5:** `swift test --filter ConfigurationDirectoryRelocatorTests`

---

### Task 3: Application relocate API

**Files:**
- Modify: `GestureFlowApplication.swift`
- Modify: `Tests/GestureFlowAppTests/ConfigurationDirectoryRelocationIntegrationTests.swift`

- [ ] **Step 1:** Add `mode` parameter; skip `configurationStore.save` / gesture save before adopt mode.
- [ ] **Step 2:** Integration test for adopt reloads target configuration.
- [ ] **Step 3:** `swift test --filter ConfigurationDirectoryRelocationIntegrationTests`

---

### Task 4: Settings alert + ViewModel

**Files:**
- Modify: `SettingsViewModel.swift`
- Modify: `GeneralSettingsView.swift`
- Modify: `ConfigurationDirectorySettingsTests.swift`

- [ ] **Step 1:** Failing tests — detect existing files schedules alert; cancel does not relocate; confirm calls adopt mode.
- [ ] **Step 2:** Add `@Published` alert + pending path; wire `relocateConfigurationDirectory(to:mode:)` closure with mode.
- [ ] **Step 3:** SwiftUI alert — title `检测到目标目录已有配置文件，是否覆盖当前配置？`, 是/否.
- [ ] **Step 4:** Invalid config on 是 shows `configurationDirectoryErrorMessage`, persisted path unchanged.
- [ ] **Step 5:** `swift test --filter ConfigurationDirectorySettingsTests`

---

### Task 5: Docs + full test run

- [ ] Update `2026-05-24-config-directory-design.md` target-has-files behavior.
- [ ] `swift test`
- [ ] Commit: `feat: confirm and validate when adopting existing config directory`
