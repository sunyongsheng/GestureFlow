# Gesture-Scoped Settings and Matching Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement per-app gesture configuration in a separate `gestures.json`, in-memory service at launch, scoped matching with app-over-global priority, and a two-column gesture settings UI with Chinese signature presets.

**Architecture:** Split persistence into `ConfigurationStore` (general) and `GestureConfigurationStore` (gestures). `GestureConfigurationService` loads once at app start. Core library gets catalog, scoped matcher, and updated conflict keys. App layer wires engine + settings to memory service.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, GestureFlowCore + GestureFlowApp (macOS 14+)

**Spec:** [2026-05-23-gesture-scoped-settings-design.md](../specs/2026-05-23-gesture-scoped-settings-design.md)

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Models/GestureConfiguration.swift` | `GestureConfiguration` container |
| `Sources/GestureFlowCore/Models/GestureDefinition.swift` | Slim gesture model + built-in default |
| `Sources/GestureFlowCore/Recognition/GestureSignatureCatalog.swift` | 52 Chinese-labeled signatures |
| `Sources/GestureFlowCore/Configuration/GestureConfigurationStore.swift` | `gestures.json` load/save |
| `Sources/GestureFlowCore/Matching/ScopedGestureMatcher.swift` | App > global matching |
| `Sources/GestureFlowCore/Validation/ConflictDetector.swift` | Update conflict key |
| `Sources/GestureFlowCore/Models/AppConfiguration.swift` | Remove `gestures` array |
| `Sources/GestureFlowApp/Services/GestureConfigurationService.swift` | In-memory authority |
| `Sources/GestureFlowApp/Engine/GestureEngine.swift` | Scoped match + name feedback |
| `Sources/GestureFlowApp/Settings/GestureSettingsView.swift` | Two-column UI |
| `Sources/GestureFlowApp/Settings/GestureShortcutRecorder.swift` | Key capture helper |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Wire service at launch |

---

### Task 1: Core models and configuration container

**Files:**
- Create: `Sources/GestureFlowCore/Models/GestureConfiguration.swift`
- Modify: `Sources/GestureFlowCore/Models/GestureDefinition.swift`
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Test: `Tests/GestureFlowCoreTests/GestureConfigurationTests.swift`

- [ ] **Step 1: Write failing test for built-in default gesture**

```swift
func testBuiltInDefaultCloseWindowGesture() {
    let config = GestureConfiguration.defaultTemplate
    XCTAssertEqual(config.gestures.count, 1)
    XCTAssertEqual(config.gestures[0].name, "关闭窗口")
    XCTAssertEqual(config.gestures[0].signature.tokens, [.down, .right])
    XCTAssertNil(config.gestures[0].targetBundleIdentifier)
}
```

- [ ] **Step 2: Run test** — expect fail (types missing)

Run: `swift test --filter GestureConfigurationTests`

- [ ] **Step 3: Implement `GestureConfiguration` and updated `GestureDefinition`**

- `GestureDefinition`: `id`, `targetBundleIdentifier`, `name`, `trigger`, `signature`, `shortcut`, `isEnabled`
- Remove `scope`, drop non-keyboard fields from gesture usage
- `GestureConfiguration`: `applicationBundleIdentifiers`, `gestures`
- `GestureConfiguration.defaultTemplate` with fixed UUID constant for close window
- Remove `gestures` from `AppConfiguration`

- [ ] **Step 4: Run tests** — expect pass

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Models Tests/GestureFlowCoreTests
git commit -m "feat(core): add GestureConfiguration and slim GestureDefinition"
```

---

### Task 2: Signature catalog (52 items)

**Files:**
- Create: `Sources/GestureFlowCore/Recognition/GestureSignatureCatalog.swift`
- Test: `Tests/GestureFlowCoreTests/GestureSignatureCatalogTests.swift`

- [ ] **Step 1: Write failing tests**

- `testCatalogCountIs52`
- `testNoAdjacentDuplicateTokensInAnyEntry`
- `testChineseDisplayNameForDownRight`

- [ ] **Step 2: Run tests** — expect fail

- [ ] **Step 3: Implement catalog generator**

- DFS or nested loops: lengths 1–3, each new direction ≠ previous
- `displayName(for:)` joins `上/下/左/右` with `、`

- [ ] **Step 4: Run tests** — expect pass

- [ ] **Step 5: Commit**

---

### Task 3: GestureConfigurationStore

**Files:**
- Create: `Sources/GestureFlowCore/Configuration/GestureConfigurationStore.swift`
- Test: `Tests/GestureFlowCoreTests/GestureConfigurationStoreTests.swift`

- [ ] **Step 1: Write failing tests**

- `testLoadReturnsDefaultTemplateWhenFileMissing` (use temp directory URL)
- `testSaveAndLoadRoundTrip`

- [ ] **Step 2: Run tests** — expect fail

- [ ] **Step 3: Implement store**

- `defaultFileURL()` sibling to `ConfigurationStore` directory → `gestures.json`
- `load()`: if missing, return `defaultTemplate` (caller may persist)
- `save(_:)`: atomic write, pretty JSON

- [ ] **Step 4: Run tests** — expect pass

- [ ] **Step 5: Commit**

---

### Task 4: ConflictDetector and ScopedGestureMatcher

**Files:**
- Modify: `Sources/GestureFlowCore/Validation/ConflictDetector.swift`
- Create: `Sources/GestureFlowCore/Matching/ScopedGestureMatcher.swift`
- Modify: `Tests/GestureFlowCoreTests/ConflictDetector` usage / tests
- Create: `Tests/GestureFlowCoreTests/ScopedGestureMatcherTests.swift`

- [ ] **Step 1: Write failing matcher tests**

- App-specific beats global for same signature+trigger
- Global used when no app gesture
- Disabled gestures not matched
- Different trigger does not match

- [ ] **Step 2: Write failing conflict test**

- Same bundle + signature + trigger → conflict

- [ ] **Step 3: Implement**

- Update `GestureConflictKey` to include `targetBundleIdentifier`
- `ScopedGestureMatcher.match(trigger:signature:foregroundBundleIdentifier:in:)`

- [ ] **Step 4: Run Core tests**

Run: `swift test --filter GestureFlowCoreTests`

- [ ] **Step 5: Commit**

---

### Task 5: GestureConfigurationService (in-memory)

**Files:**
- Create: `Sources/GestureFlowApp/Services/GestureConfigurationService.swift`
- Test: `Tests/GestureFlowAppTests/GestureConfigurationServiceTests.swift`

- [ ] **Step 1: Write failing tests**

- `testLoadCreatesFileWhenMissing`
- `testUpdateGesturesDoesNotReloadFromDisk`
- `testSaveWritesToDisk`

- [ ] **Step 2: Implement service**

- `private(set) var configuration: GestureConfiguration`
- `load()`: store.load(); if file was missing, save default template
- `update(_:)` / `mutate` helper for settings
- `save() throws`

- [ ] **Step 3: Run tests** — pass

- [ ] **Step 4: Commit**

---

### Task 6: GestureEngine runtime wiring

**Files:**
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift` (if message API needs name)
- Modify: `Tests/GestureFlowAppTests/GestureEngineTests.swift`

- [ ] **Step 1: Update failing engine tests**

- Provider returns in-memory `GestureConfiguration`
- Inject `foregroundBundleIdentifier: () -> String?`
- Success feedback / overlay uses gesture name `关闭窗口`

- [ ] **Step 2: Implement**

- Replace `GestureMatcher` with `ScopedGestureMatcher`
- `configurationProvider: () -> GestureConfiguration`
- Map overlay completion: recognized → `gesture.name`
- Chinese strings for unmatched/rejected per spec

- [ ] **Step 3: Run** `swift test --filter GestureEngineTests`

- [ ] **Step 4: Commit**

---

### Task 7: GestureFlowApplication integration

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- Modify: `Sources/GestureFlowApp/Settings/SettingsWindowDependencies.swift` (if needed)
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`

- [ ] **Step 1: Construct `GestureConfigurationService` at launch**

- Call `load()` before starting engine
- Pass service to `SettingsViewModel` and `GestureEngine`

- [ ] **Step 2: Remove gesture CRUD from `AppConfiguration` paths**

- Settings gesture edits go through service only

- [ ] **Step 3: Update application tests** for split config

- [ ] **Step 4: Commit**

---

### Task 8: Gesture settings UI (two columns)

**Files:**
- Create: `Sources/GestureFlowApp/Settings/GestureSettingsView.swift`
- Create: `Sources/GestureFlowApp/Settings/GestureShortcutRecorder.swift`
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`
- Delete or stop using: `GestureListView.swift`, `GestureEditorView.swift`
- Test: `Tests/GestureFlowAppTests/GestureSettingsViewTests.swift` (logic helpers)

- [ ] **Step 1: ViewModel helpers on `SettingsViewModel`**

- `gestureService` access
- `gestures(for bundleID: String?)`, `addApplication(from:)`, `removeApplication(bundleID:)`, `addGesture`, `deleteGesture`, `updateGesture`
- Conflict check before save

- [ ] **Step 2: Left column**

- 全局 + apps from `applicationBundleIdentifiers`
- `+` → `NSOpenPanel` for `.app` → bundle ID
- Delete app → rule A (remove ID + all gestures)

- [ ] **Step 3: Right `Table`**

- Columns: 名称, 手势, 触发, 快捷键, 启用
- Inline name save on focus loss
- Signature `Picker` from catalog
- Shortcut recorder view
- Toolbar +/-

- [ ] **Step 4: Wire `MainSettingsView` gestures section**

- [ ] **Step 5: Manual smoke test** in built app

- [ ] **Step 6: Commit**

---

### Task 9: Cleanup and regression

**Files:**
- Modify: `Tests/GestureFlowCoreTests/GestureRecognizerTests.swift` (remove default gestures from AppConfiguration assertion)
- Modify: `Tests/GestureFlowCoreTests/ConfigurationStoreTests.swift`
- Modify: `GestureFlow.xcodeproj/project.pbxproj` if new files not auto-included

- [ ] **Step 1: Fix all tests**

Run: `swift test`

- [ ] **Step 2: Remove dead code** (`GestureMatcher` if fully replaced, old preset enums)

- [ ] **Step 3: Final commit**

```bash
git commit -m "feat: gesture-scoped settings, matching, and gestures.json"
```

---

## Manual Test Plan

1. Delete `gestures.json`, launch app → file created with 关闭窗口.
2. Right-drag `下、右` on desktop → overlay shows `关闭窗口`, ⌘W fires.
3. Add Safari in left column, add same signature with different shortcut → only Safari frontmost uses Safari rule.
4. Delete Safari app entry → Safari gestures removed from file.
5. Edit name, blur → persists after relaunch without re-parse during session (change file on disk only after quit to verify load-once).
