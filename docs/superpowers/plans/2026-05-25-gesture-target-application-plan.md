# Gesture Target Application Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add **手势目标应用** setting (default 鼠标下方应用) so gesture matching and keyboard shortcuts both use the foreground app or the app under the cursor at **gesture start**, with targeted `postToPid` delivery.

**Architecture:** Top-level `AppConfiguration.gestureTargetApplication` drives a new `GestureTargetApplicationResolver` (window hit test at stroke start). `GestureEngine` resolves once per gesture end; under-mouse miss → `actionFailed`. `ActionExecutor` posts keyboard events to the resolved PID.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, CoreGraphics, GestureFlowCore + GestureFlowApp (macOS 14+)

**Spec:** [2026-05-25-gesture-target-application-design.md](../specs/2026-05-25-gesture-target-application-design.md)

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Models/GestureTargetApplication.swift` | Enum + display labels |
| `Sources/GestureFlowCore/Models/AppConfiguration.swift` | `gestureTargetApplication` field + decode default |
| `Sources/GestureFlowCore/Target/GestureTargetApplicationResolver.swift` | Foreground / under-mouse resolution |
| `Sources/GestureFlowCore/Matching/ScopedGestureMatcher.swift` | Rename param to `targetBundleIdentifier` |
| `Sources/GestureFlowApp/Engine/GestureEngine.swift` | Resolve at start point; wire matcher + executor |
| `Sources/GestureFlowApp/Actions/ActionExecutor.swift` | `postToPid` keyboard path |
| `Sources/GestureFlowApp/Settings/Advanced/GestureTriggerSettingsView.swift` | Picker UI |
| `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift` | Update + persist `gestureTargetApplication` |
| `Tests/GestureFlowCoreTests/GestureTargetApplicationResolverTests.swift` | Hit test + foreground |
| `Tests/GestureFlowAppTests/GestureEngineTests.swift` | End-to-end policy behavior |
| `Tests/GestureFlowAppTests/ActionExecutorTests.swift` | PID posting |

---

### Task 1: Core enum and configuration

**Files:**
- Create: `Sources/GestureFlowCore/Models/GestureTargetApplication.swift`
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Modify: `Tests/GestureFlowCoreTests/ConfigurationStoreTests.swift`
- Modify: `Tests/GestureFlowCoreTests/PublicAPITests.swift` (if construction tests exist)

- [ ] **Step 1: Write failing test for default and backfill**

```swift
func testMissingGestureTargetApplicationBackfillsUnderMouse() throws {
    // decode config JSON without key → .underMouse
}
```

- [ ] **Step 2: Run test** — expect fail

Run: `swift test --filter ConfigurationStoreTests`

- [ ] **Step 3: Implement enum + `AppConfiguration.gestureTargetApplication`**

- `GestureTargetApplication`: `foreground`, `underMouse`
- `static var defaultValue: underMouse`
- `displayName` for picker: 当前前台应用 / 鼠标下方应用
- Add to `AppConfiguration` with decode backfill

- [ ] **Step 4: Run tests** — expect pass

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Models Tests/GestureFlowCoreTests
git commit -m "feat(core): add gesture target application configuration"
```

---

### Task 2: Target resolver (window hit test)

**Files:**
- Create: `Sources/GestureFlowCore/Target/GestureTargetApplicationResolver.swift`
- Create: `Tests/GestureFlowCoreTests/GestureTargetApplicationResolverTests.swift`

- [ ] **Step 1: Define result type and protocols**

```swift
public struct ResolvedGestureTarget: Equatable {
    public var bundleIdentifier: String?
    public var processIdentifier: Int32?
    public var isValid: Bool { bundleIdentifier != nil && processIdentifier != nil }
}
```

- Inject `WorkspaceQuerying` / `WindowListQuerying` for tests (avoid live window list in unit tests).

- [ ] **Step 2: Write failing tests**

- `testForegroundReturnsFrontmostApplication`
- `testUnderMouseReturnsTopmostEligibleWindowOwner`
- `testUnderMouseSkipsGestureFlowOwnWindows`
- `testUnderMouseReturnsInvalidWhenNoWindow`

- [ ] **Step 3: Implement resolver**

- Foreground: `NSWorkspace.frontmostApplication` → bundle ID + pid
- Under mouse: `CGWindowListCopyWindowInfo` filtered list, point-in-rect at **start** `GesturePoint`, first eligible window → pid → bundle ID
- Document exclusion rules in code comments (Dock, menubar, desktop, self)

- [ ] **Step 4: Run tests** — expect pass

- [ ] **Step 5: Commit**

---

### Task 3: Matcher parameter rename

**Files:**
- Modify: `Sources/GestureFlowCore/Matching/ScopedGestureMatcher.swift`
- Modify: `Tests/GestureFlowCoreTests/ScopedGestureMatcherTests.swift`

- [ ] **Step 1: Rename `foregroundBundleIdentifier` → `targetBundleIdentifier`**

- No algorithm change

- [ ] **Step 2: Run `swift test --filter ScopedGestureMatcherTests`**

- [ ] **Step 3: Commit**

---

### Task 4: ActionExecutor targeted posting

**Files:**
- Modify: `Sources/GestureFlowApp/Actions/ActionExecutor.swift`
- Modify: `Tests/GestureFlowAppTests/ActionExecutorTests.swift`

- [ ] **Step 1: Extend `KeyboardEventPosting` / executor API**

```swift
func execute(_ action: GestureAction, targetProcessIdentifier: pid_t? = nil) throws
```

- When `targetProcessIdentifier != nil`, use `CGEvent.postToPid`
- When nil, keep `cghidEventTap` for existing callers

- [ ] **Step 2: Write failing test `testKeyboardShortcutPostsToTargetPID`**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run tests**

- [ ] **Step 5: Commit**

---

### Task 5: GestureEngine integration

**Files:**
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- Modify: `Tests/GestureFlowAppTests/GestureEngineTests.swift`

- [ ] **Step 1: Write failing tests**

- `testUnderMousePolicyMatchesAppUnderStartPoint` — inject resolver returning Safari while foreground is Finder
- `testUnderMousePolicyActionFailedWhenNoTarget` — resolver invalid → `actionFailed`, executor not called
- `testForegroundPolicyUsesFrontmostBundleIdentifier`

- [ ] **Step 2: Run tests** — expect fail

- [ ] **Step 3: Wire engine**

- Inject `GestureTargetApplicationResolver` (default live)
- On gesture end: `startPoint = points.first`; read `gestureTargetApplication` from app config
- Resolve target; if `.underMouse` && !resolved.isValid → `actionFailed("未找到鼠标下方的应用")`
- Matcher uses `resolved.bundleIdentifier`
- Executor gets `resolved.processIdentifier`; if matched but PID nil → `actionFailed`

- [ ] **Step 4: Run `swift test --filter GestureEngineTests`**

- [ ] **Step 5: Commit**

---

### Task 6: Settings UI

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Advanced/GestureTriggerSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
- Modify: `Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift`

- [ ] **Step 1: Add `updateGestureTargetApplication` on view model**

- Persists via existing configuration store path

- [ ] **Step 2: Add picker row at top of 触发 card**

- Title: 手势目标应用
- Description: 决定按哪个应用匹配手势规则，以及手势快捷键发往哪个应用。
- Options from `GestureTargetApplication` cases

- [ ] **Step 3: Test view model persistence**

- [ ] **Step 4: Manual check:** open Settings → 高级 → 触发, toggle options, restart app, value retained

- [ ] **Step 5: Commit**

---

### Task 7: Full verification

- [ ] **Run full test suite:** `swift test`

- [ ] **Manual scenarios**

1. Register Chrome-specific gesture; focus Finder; draw gesture starting over Chrome → Chrome shortcut fires without focusing Chrome.
2. Draw gesture starting over desktop empty area → feedback shows failure, no shortcut.
3. Switch to 当前前台应用 → same gesture uses Finder rules when Finder focused.

- [ ] **Commit any fixes**

---

## Notes for implementers

- **Coordinate space:** Confirm `GesturePoint` used in engine matches `CGWindow` bounds (likely screen/quartz space — align with `MouseEventTap`); add one regression test if conversion helper exists.
- **Start point:** Use `points.first`, not `points.last`.
- **Do not** call `activate` on target app when posting shortcuts.
