# Settings WindowGroup Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's `Settings { ... }` scene with a dedicated `WindowGroup(id:)` while preserving the current settings UI, shared `SettingsViewModel`, and window lifecycle behavior.

**Architecture:** Keep the existing settings content stack (`SettingsSceneRoot` -> `MainSettingsView`) and bridge/lifecycle observer flow. Change the scene host from SwiftUI's special `Settings` scene to a dedicated `WindowGroup`, then update the open-driver path and tests to use ordinary window semantics.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest.

---

## Chunk 1: Scene Host Migration

### Task 1: Replace the Settings scene with a dedicated WindowGroup

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowShellApp.swift`
- Create: `Sources/GestureFlowApp/Settings/SettingsWindowSceneIDs.swift` (recommended)
- Test: `Tests/GestureFlowAppTests/AppDelegateTests.swift`

- [ ] **Step 1: Write the failing test**

Add or update a focused test asserting the app exposes a stable settings window scene identifier through a constant or service, and that the settings root can still be constructed without `Settings { ... }`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter AppDelegateTests`

Expected: FAIL because the code still assumes a `Settings` scene or lacks the new scene id definition.

- [ ] **Step 3: Introduce a dedicated scene id**

Create a small scene-id definition, for example:

```swift
enum SettingsWindowSceneIDs {
    static let settings = "settings"
}
```

Use this constant everywhere instead of scattering the `"settings"` string.

- [ ] **Step 4: Replace `Settings { ... }` with `WindowGroup(id:)`**

Change the app scene declaration so the settings UI is hosted by a dedicated `WindowGroup(id: SettingsWindowSceneIDs.settings)`.

Keep the scene content as:

```swift
SettingsSceneRoot(bridge: SettingsSceneServices.shared.bridge)
```

Keep the app delegate injection unchanged.

- [ ] **Step 5: Preserve window sizing expectations**

If needed, add scene-level defaults such as minimum/default window size so the new `WindowGroup` still opens like a settings window instead of a generic tiny window.

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter AppDelegateTests`

Expected: PASS with the new scene host in place.

## Chunk 2: Open Settings Flow

### Task 2: Rewire the open-driver path from Settings scene semantics to WindowGroup semantics

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneOpenDriver.swift`
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneServices.swift`
- Modify: `Sources/GestureFlowApp/App/AppDelegate.swift`
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`
- Test: `Tests/GestureFlowAppTests/SettingsSceneBridgeTests.swift`

- [ ] **Step 1: Write the failing test**

Add or update a test that proves the app's "open settings" path requests opening the dedicated settings window id instead of the old `Settings` scene behavior.

Focus on these cases:
- startup-triggered settings open
- menu-triggered settings open
- repeated open requests reuse the logical settings flow

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter GestureFlowApplicationTests`

Expected: FAIL because the open driver still targets settings-scene semantics.

- [ ] **Step 3: Redesign the driver surface**

Refactor `SettingsSceneOpenDriver` so its implementation wraps ordinary window opening.

Recommended direction:
- resolve or inject SwiftUI's `OpenWindowAction`
- expose a single method like `openSettingsWindow()`
- internally call `openWindow(id: SettingsWindowSceneIDs.settings)`

Keep the higher-level call sites unchanged if possible so the rest of the app still talks in terms of "open settings."

- [ ] **Step 4: Update service wiring**

Update `SettingsSceneServices` and `AppDelegate` so the shared driver is constructed with the new window-opening dependency instead of the old settings-scene-specific one.

- [ ] **Step 5: Keep `GestureFlowApplication` behavior stable**

Ensure the application coordinator still:
- opens settings on launch when expected
- routes Preferences/menu actions through the driver
- reuses the shared `SettingsViewModel`

Do not change the shared view-model semantics during this task.

- [ ] **Step 6: Run the targeted tests**

Run:
- `swift test --filter GestureFlowApplicationTests`
- `swift test --filter SettingsSceneBridgeTests`

Expected: PASS with the new open-driver path.

## Chunk 3: Lifecycle, Window Styling, and Safety Nets

### Task 3: Verify lifecycle attachment and window styling still hold under WindowGroup

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsWindowLifecycleObserver.swift` (only if needed)
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneRoot.swift` (only if needed)
- Test: `Tests/GestureFlowAppTests/SettingsWindowLifecycleObserverTests.swift`
- Test: `Tests/GestureFlowAppTests/MainSettingsViewTests.swift`

- [ ] **Step 1: Write the failing test**

If migration changes attach timing or window acquisition, add or tighten a test showing that the settings window is still attached to the bridge and configured with the expected appearance.

At minimum verify:
- settings window attach still occurs
- closing the observed window still triggers the bridge/lifecycle callback
- transparent titlebar/full-size content still remain enabled

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter SettingsWindowLifecycleObserverTests`

Expected: FAIL only if the `WindowGroup` migration changes attach timing or breaks appearance configuration.

- [ ] **Step 3: Make the minimal lifecycle adjustment**

Only if necessary:
- adjust `SettingsSceneRoot` so `SettingsWindowLifecycleObserver` still mounts early enough
- adjust `SettingsWindowLifecycleObserver` only to restore the prior attach/close behavior

Do not use this task to redesign appearance. Keep it focused on preserving behavior.

- [ ] **Step 4: Run the targeted lifecycle tests**

Run:
- `swift test --filter SettingsWindowLifecycleObserverTests`
- `swift test --filter MainSettingsViewTests`

Expected: PASS with no lifecycle regressions.

- [ ] **Step 5: Run the final regression sweep**

Run:
- `swift test --filter GestureFlowApplicationTests`
- `swift test --filter SettingsSceneBridgeTests`
- `swift test --filter SettingsWindowLifecycleObserverTests`
- `swift test --filter MainSettingsViewTests`

Expected: All pass.

- [ ] **Step 6: Commit in logical chunks**

Recommended commit order:

```bash
git add Sources/GestureFlowApp/App/GestureFlowShellApp.swift Sources/GestureFlowApp/Settings/SettingsWindowSceneIDs.swift
git commit -m "feat: host settings in a dedicated window group"

git add Sources/GestureFlowApp/Settings/SettingsSceneOpenDriver.swift Sources/GestureFlowApp/Settings/SettingsSceneServices.swift Sources/GestureFlowApp/App/AppDelegate.swift Sources/GestureFlowApp/App/GestureFlowApplication.swift Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift Tests/GestureFlowAppTests/SettingsSceneBridgeTests.swift
git commit -m "feat: route settings opening through window group"

git add Sources/GestureFlowApp/Settings/SettingsWindowLifecycleObserver.swift Sources/GestureFlowApp/Settings/SettingsSceneRoot.swift Tests/GestureFlowAppTests/SettingsWindowLifecycleObserverTests.swift Tests/GestureFlowAppTests/MainSettingsViewTests.swift
git commit -m "test: preserve settings window lifecycle under window group"
```

## Notes

- Keep `MainSettingsView` and the current `NavigationSplitView` layout unchanged during the scene-host migration. This plan is about window hosting, not redesigning the settings UI again.
- Keep `SettingsSceneBridge` as the shared owner of window/view-model state. The migration should change the window host, not the ownership model.
- If `WindowGroup` still does not provide enough window chrome control after this migration, that will be the point to evaluate a later move to a fully managed `NSWindow`.
