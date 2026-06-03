# Ignored Applications Settings Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users add/remove ignored applications in Advanced settings; when the resolved gesture target is ignored, GestureFlow passes through mouse events without capturing gestures.

**Architecture:** `AppConfiguration.ignoredApplicationBundleIdentifiers` persists the list. `GestureActivationGate` resolves the gesture target (same policy as **手势目标应用**) and returns false when ignored. `MouseEventTap` consults the gate at right/middle mouse down before suppressing events.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, GestureFlowCore + GestureFlowApp (macOS 14+)

**Spec:** [2026-06-03-ignored-applications-design.md](../specs/2026-06-03-ignored-applications-design.md)

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Models/AppConfiguration.swift` | `ignoredApplicationBundleIdentifiers` field + decode default + filter self on decode |
| `Sources/GestureFlowApp/Target/GestureActivationGate.swift` | Resolve target + check ignore list |
| `Sources/GestureFlowApp/EventTap/MouseEventTap.swift` | Gate check at mouse down → passEvent |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Wire gate into EventTap |
| `Sources/GestureFlowApp/Settings/SettingsViewModel.swift` | Add/remove ignored apps, running apps query |
| `Sources/GestureFlowApp/Settings/Advanced/IgnoredApplicationsSettingsView.swift` | New settings card UI |
| `Sources/GestureFlowApp/Settings/Advanced/AdvancedSettingsView.swift` | Insert new card |
| `Sources/GestureFlowApp/Localization/L10nKey.swift` + `Tables/*` | New strings |
| `Tests/GestureFlowAppTests/Target/GestureActivationGateTests.swift` | Gate logic |
| `Tests/GestureFlowAppTests/MouseEventTapTests.swift` | Pass-through behavior |
| `Tests/GestureFlowCoreTests/AppConfigurationStoreTests.swift` | Config backfill |
| `Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift` | ViewModel CRUD |

---

## Chunk 1: Core configuration

### Task 1: `ignoredApplicationBundleIdentifiers` on `AppConfiguration`

**Files:**
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Modify: `Tests/GestureFlowCoreTests/AppConfigurationStoreTests.swift`

- [ ] **Step 1: Write failing test for missing key backfill**

```swift
func testMissingIgnoredApplicationsBackfillsEmptyArray() throws {
    let yaml = """
    isEnabled: true
    """
    // write to temp config, load, assert ignoredApplicationBundleIdentifiers == []
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter AppConfigurationStoreTests.testMissingIgnoredApplicationsBackfillsEmptyArray`

- [ ] **Step 3: Add field to `AppConfiguration`**

- Property: `public var ignoredApplicationBundleIdentifiers: [String]`
- Init default: `[]`
- `CodingKeys` + decode: missing → `[]`
- Encode included in existing YAML coder path (automatic via `Codable`)

- [ ] **Step 4: Run tests — expect PASS**

Run: `swift test --filter AppConfigurationStoreTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Models/AppConfiguration.swift Tests/GestureFlowCoreTests/AppConfigurationStoreTests.swift
git commit -m "feat(core): add ignored application bundle identifiers config"
```

---

## Chunk 2: Runtime gate + EventTap

### Task 2: `GestureActivationGate`

**Files:**
- Create: `Sources/GestureFlowApp/Target/GestureActivationGate.swift`
- Create: `Tests/GestureFlowAppTests/Target/GestureActivationGateTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testEmptyIgnoreListAlwaysActivates() { /* gate returns true */ }
func testIgnoredTargetDoesNotActivate() { /* mock resolver returns com.example.app in list */ }
func testNonIgnoredTargetActivates() { /* ... */ }
func testInvalidTargetStillActivates() { /* resolved .invalid → true */ }
```

Use mock `GestureTargetResolving` (see `GestureEngineTests` / `GestureTargetApplicationResolverTests` patterns).

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --filter GestureActivationGateTests`

- [ ] **Step 3: Implement gate**

```swift
final class GestureActivationGate {
    typealias ConfigurationProvider = () -> AppConfiguration
    private let configurationProvider: ConfigurationProvider
    private let targetResolver: GestureTargetResolving

    func shouldActivateGesture(at startPoint: GesturePoint) -> Bool {
        let config = configurationProvider()
        guard !config.ignoredApplicationBundleIdentifiers.isEmpty else { return true }
        let target = targetResolver.resolve(
            policy: config.gestureTargetApplication,
            at: startPoint
        )
        guard let bundleID = target.bundleIdentifier else { return true }
        return !config.ignoredApplicationBundleIdentifiers.contains(bundleID)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Target/GestureActivationGate.swift Tests/GestureFlowAppTests/Target/GestureActivationGateTests.swift
git commit -m "feat: add gesture activation gate for ignored applications"
```

### Task 3: Wire gate into `MouseEventTap`

**Files:**
- Modify: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Tests/GestureFlowAppTests/MouseEventTapTests.swift`

- [ ] **Step 1: Write failing test**

```swift
func testRightMouseDownPassesThroughWhenGateReturnsFalse() {
    let tap = MouseEventTap(
        gestureThreshold: 24,
        gestureActivationGate: { _ in false }
    )
    let decision = tap.handle(.rightMouseDown(at: point))
    XCTAssertEqual(decision, .passEvent)
    // no hold timeout callback fired
}
```

Also test middle mouse down and that gate `true` preserves existing suppress behavior.

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter MouseEventTapTests.testRightMouseDownPassesThroughWhenGateReturnsFalse`

- [ ] **Step 3: Add `gestureActivationGate` parameter**

- Default: `{ _ in true }` to preserve existing test behavior
- At start of `beginPendingRightClick` and `begin(trigger:at:)`:
  ```swift
  guard gestureActivationGate(point) else { return .passEvent }
  ```

- [ ] **Step 4: Wire in `GestureFlowApplication`**

```swift
let targetResolver = GestureTargetApplicationResolver()
let activationGate = GestureActivationGate(
    configurationProvider: { runtimeState.appConfiguration },
    targetResolver: targetResolver
)
eventTap: MouseEventTap(
    triggerConfigurationProvider: { runtimeState.appConfiguration.trigger },
    gestureActivationGate: { activationGate.shouldActivateGesture(at: $0) }
)
```

- [ ] **Step 5: Run full test suite**

Run: `swift test`
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp/EventTap/MouseEventTap.swift Sources/GestureFlowApp/App/GestureFlowApplication.swift Tests/GestureFlowAppTests/MouseEventTapTests.swift
git commit -m "feat: pass through mouse down when gesture target is ignored"
```

---

## Chunk 3: Settings UI + ViewModel

### Task 4: ViewModel API

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- Modify: `Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testAddIgnoredApplicationPersists() throws { /* ... */ }
func testCannotAddOwnBundleIdentifier() { /* ... */ }
func testRemoveIgnoredApplication() { /* ... */ }
func testRestoreDefaultAdvancedSettingsClearsIgnoredApplications() { /* ... */ }
```

Inject known bundle ID for self via test helper or compare against `Bundle.main.bundleIdentifier`.

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement ViewModel methods**

- `var ignoredApplicationBundleIdentifiers: [String] { configuration.ignoredApplicationBundleIdentifiers }`
- `func addIgnoredApplicationFromPanel()` — mirror `addApplicationFromPanel()` but write to ignore list
- `func addIgnoredApplication(bundleIdentifier:)` — guard not self, not duplicate, persist
- `func removeIgnoredApplication(bundleIdentifier:)`
- `var runningApplicationsAvailableForIgnore: [(bundleIdentifier: String, name: String)]`
- Update `restoreDefaultAdvancedSettings()` to clear ignore list
- Optional: filter self from list in `init`/`loadResult` if corrupt YAML (or rely on Core decode filter from Task 1 extension)

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Settings/SettingsViewModel.swift Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift
git commit -m "feat: view model CRUD for ignored applications"
```

### Task 5: Settings UI + localization

**Files:**
- Create: `Sources/GestureFlowApp/Settings/Advanced/IgnoredApplicationsSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/Advanced/AdvancedSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Localization/L10nKey.swift`
- Modify: `Sources/GestureFlowApp/Localization/Tables/L10nStrings*.swift` (all locales)
- Modify: `GestureFlow.xcodeproj/project.pbxproj` (if not SPM-only for app target)

- [ ] **Step 1: Add L10n keys** (zh-Hans, zh-Hant, en minimum; mirror to other existing tables)

- [ ] **Step 2: Create `IgnoredApplicationsSettingsView`**

- `SettingsCard` with title/description
- List of ignored apps (icon + name + delete)
- Empty state text when list empty
- `Menu` add button:
  - "从文件选择…" → `viewModel.addIgnoredApplicationFromPanel()`
  - Submenu "从运行中的应用" → `ForEach(viewModel.runningApplicationsAvailableForIgnore)`

- [ ] **Step 3: Insert in `AdvancedSettingsView`** after trigger card

- [ ] **Step 4: Build + manual smoke test**

Run: `swift build` or Xcode build
Open Advanced → verify card renders

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Settings/Advanced/IgnoredApplicationsSettingsView.swift Sources/GestureFlowApp/Settings/Advanced/AdvancedSettingsView.swift Sources/GestureFlowApp/Localization/
git commit -m "feat: ignored applications settings UI"
```

---

## Chunk 4: Self-bundle filtering on load

### Task 6: Filter GestureFlow from persisted ignore list

**Files:**
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift` (decode) **or** `SettingsViewModel` init
- Modify: `Tests/GestureFlowCoreTests/AppConfigurationStoreTests.swift`

- [ ] **Step 1: Test YAML with own bundle in list loads filtered**

Note: Core may not know own bundle at decode time — prefer filtering in `AppConfiguration.init(from:)` using optional parameter, **or** filter in ViewModel on load / in gate (gate never treats self as ignored even if in list). Simplest robust approach:

- Gate: never return false for own bundle ID (hardcoded runtime check using `Bundle.main.bundleIdentifier`)
- ViewModel add: reject self
- ViewModel/UI: don't show self in running apps list

Add test that gate returns true even when self is in config list.

- [ ] **Step 2: Implement self exemption in gate + add paths**

- [ ] **Step 3: Run tests — expect PASS**

- [ ] **Step 4: Commit**

```bash
git commit -m "fix: prevent ignoring GestureFlow itself"
```

---

## Final verification

- [ ] Run full suite: `swift test`
- [ ] Manual checklist from spec (Chrome ignore, under-mouse cross-app, both add paths, persistence)

---

**Plan complete.** Ready to execute when you want implementation to begin.
