# Split Gesture Configuration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split gesture persistence into `gestures-builtin.yaml` and `gestures-custom.yaml`, merge at load with runtime `GestureSource`, route saves by source, and show merge ID conflicts in settings.

**Architecture:** `BuiltInGestureSeeds` seeds/restores builtin file only; `SplitGestureConfigurationLoader` merges with source tagging and conflict detection; `GestureConfigurationService` bootstraps two files and split saves; settings surfaces merge conflicts.

**Tech Stack:** Swift 5.9, Swift Package Manager, Yams YAML (`GestureFlowCore`), SwiftUI settings (`GestureFlowApp`).

**Spec:** `docs/superpowers/specs/2026-05-28-split-gesture-configuration-design.md`

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Configuration/ConfigurationFileNames.swift` | `gestures-builtin.yaml`, `gestures-custom.yaml`; remove `gestures.yaml` |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryResolver.swift` | Two gesture URLs; two store factories |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryValidator.swift` | Validate both gesture files |
| `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryRelocator.swift` | Copy/delete both gesture files |
| `Sources/GestureFlowCore/Models/GestureSource.swift` | Create — `builtin` / `custom` |
| `Sources/GestureFlowCore/Models/GestureDefinition.swift` | Add non-Codable `source`; remove `builtInCloseWindow` |
| `Sources/GestureFlowCore/Models/GestureConfiguration.swift` | Remove hardcoded builtin defaults; empty custom template helper |
| `Sources/GestureFlowCore/Configuration/BuiltInGestureSeeds.swift` | Create — `closeWindowID`, `factoryGestures()` |
| `Sources/GestureFlowCore/Configuration/SplitGestureConfigurationLoader.swift` | Create — bootstrap, merge, conflicts |
| `Sources/GestureFlowApp/Services/GestureConfigurationService.swift` | Dual-file load/save/restore |
| `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift` | Merge conflict message; restore defaults |
| `Sources/GestureFlowApp/Localization/LocalizationManager.swift` | Use `BuiltInGestureSeeds.closeWindowID` |
| Tests under `Tests/GestureFlowCoreTests/` | Loader, merge, relocator, validator |
| Tests under `Tests/GestureFlowAppTests/` | Service, settings; replace `gestures.yaml` paths |

---

## Chunk 1: Core types and seeds

### Task 1: `GestureSource` and `GestureDefinition.source`

**Files:**
- Create: `Sources/GestureFlowCore/Models/GestureSource.swift`
- Modify: `Sources/GestureFlowCore/Models/GestureDefinition.swift`
- Modify: `Tests/GestureFlowCoreTests/GestureConfigurationTests.swift`

- [ ] **Step 1: Write failing test** — decoded gesture defaults `source == .custom`; merged builtin gesture has `.builtin` (after Task 3).

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter GestureConfigurationTests`

- [ ] **Step 3: Add `GestureSource`; add `var source` excluded from `Codable`**

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit** — `feat(core): add runtime GestureSource on definitions`

---

### Task 2: `BuiltInGestureSeeds`

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/BuiltInGestureSeeds.swift`
- Modify: `Sources/GestureFlowCore/Models/GestureDefinition.swift` — delete `builtInCloseWindow`
- Modify: `Sources/GestureFlowCore/Models/GestureConfiguration.swift` — remove builtin from `defaultTemplate` / decoder fallback
- Create: `Tests/GestureFlowCoreTests/BuiltInGestureSeedsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testCloseWindowIDIsStable() {
    XCTAssertEqual(BuiltInGestureSeeds.closeWindowID.uuidString, "A7C4E1B2-...")
}
func testFactoryGesturesContainsCloseWindow() {
    XCTAssertTrue(BuiltInGestureSeeds.factoryGestures().contains { $0.id == BuiltInGestureSeeds.closeWindowID })
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement seeds (move fields from old `builtInCloseWindow`)**

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit** — `feat(core): add BuiltInGestureSeeds for builtin YAML bootstrap`

---

## Chunk 2: File names and directory plumbing

### Task 3: Configuration file names and resolver URLs

**Files:**
- Modify: `Sources/GestureFlowCore/Configuration/ConfigurationFileNames.swift`
- Modify: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryResolver.swift`
- Modify: `Tests/GestureFlowCoreTests/ConfigurationDirectoryRelocatorTests.swift`
- Modify: `Tests/GestureFlowCoreTests/ConfigurationDirectoryValidatorTests.swift`
- Modify: all tests referencing `ConfigurationFileNames.gestures` or `"gestures.yaml"`

- [ ] **Step 1: Update `ConfigurationFileNames` and resolver URL properties**

- [ ] **Step 2: Fix relocator/validator tests to write/read `gestures-builtin.yaml` + `gestures-custom.yaml`**

- [ ] **Step 3: Run** `swift test --filter ConfigurationDirectory`

- [ ] **Step 4: Commit** — `refactor(core): rename gesture config files to builtin and custom`

---

## Chunk 3: Merge loader

### Task 4: `SplitGestureConfigurationLoader`

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/SplitGestureConfigurationLoader.swift`
- Create: `Tests/GestureFlowCoreTests/SplitGestureConfigurationLoaderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testMergeTagsBuiltinAndCustomSources() { ... }
func testMergeDetectsDuplicateIDs() { ... }
func testEmptyCustomTemplate() { ... }
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement merge + `GestureConfigurationMergeResult`**

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit** — `feat(core): merge split gesture YAML with source tagging`

---

## Chunk 4: App service and settings

### Task 5: `GestureConfigurationService` dual-file lifecycle

**Files:**
- Modify: `Sources/GestureFlowApp/Services/GestureConfigurationService.swift`
- Modify: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryResolver.swift` — `makeGestureConfigurationService` if needed
- Create: `Tests/GestureFlowAppTests/GestureConfigurationServiceTests.swift` (extend)

- [ ] **Step 1: Write failing tests** — bootstrap creates two files; save builtin edit; save custom add; `restoreDefaults()` resets both

- [ ] **Step 2: Implement load bootstrap, split save by `source`, `mergeConflictIDs` property**

- [ ] **Step 3: Run** `swift test --filter GestureConfigurationService`

- [ ] **Step 4: Commit** — `feat(app): load and save split gesture configuration`

---

### Task 6: Settings merge conflict + restore

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
- Modify: `Sources/GestureFlowApp/Settings/Gestures/GestureSettingsView.swift` (if banner needed)
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift` — pass conflicts on load
- Modify: `Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift`

- [ ] **Step 1: Add `gestureMergeConflictMessage` (or extend existing error) when `mergeConflictIDs` non-empty**

- [ ] **Step 2: `restoreDefaultGestureConfiguration()` calls service restore (both files)**

- [ ] **Step 3: Test conflict message appears when loader reports duplicate IDs**

- [ ] **Step 4: Commit** — `feat(settings): surface gesture merge conflicts and split restore`

---

## Chunk 5: Localization and test sweep

### Task 7: Localization ID migration

**Files:**
- Modify: `Sources/GestureFlowApp/Localization/LocalizationManager.swift`
- Modify: all references to `GestureConfiguration.closeWindowGestureID` → `BuiltInGestureSeeds.closeWindowID`
- Modify: `Tests/GestureFlowAppTests/**` (overlay, engine, etc.)

- [ ] **Step 1: Replace close-window ID constant**

- [ ] **Step 2: Remove `GestureConfiguration.closeWindowGestureID` if unused**

- [ ] **Step 3: Run full** `swift test`

- [ ] **Step 4: Commit** — `refactor: use BuiltInGestureSeeds.closeWindowID for localization`

---

### Task 8: Full test suite and docs touch-up

- [ ] **Step 1: Grep for `gestures.yaml`, `defaultTemplate` builtin assumptions, `builtInCloseWindow`**

- [ ] **Step 2: Run** `swift test`

- [ ] **Step 3: Update `docs/superpowers/specs/2026-05-24-config-directory-design.md` references only if misleading (optional footnote)**

- [ ] **Step 4: Commit** — `test: update fixtures for split gesture configuration`

---

## Manual verification

1. Delete config directory gesture files; launch app → both YAML files created; close-window works.
2. Add custom gesture → only `gestures-custom.yaml` changes.
3. Edit close-window shortcut → `gestures-builtin.yaml` changes.
4. Duplicate same `id` in both files manually → settings shows merge conflict message.
5. Restore defaults → custom empty; builtin reset to factory.
