# Dynamic Activation Policy Settings Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make GestureFlow behave like a menu bar app that temporarily becomes a Dock-visible foreground app while settings are open, then returns to accessory mode after the last settings window closes without stopping gesture recognition.

**Architecture:** Add a dedicated `AppPresentationController` that is the only type allowed to call `NSApplication.setActivationPolicy(_:)`. Keep `GestureFlowApplication` as the business coordinator and keep the SwiftUI settings scene as the UI surface, but route all foreground/background presentation transitions through the new controller and scene lifecycle observation.

**Tech Stack:** Swift, AppKit, SwiftUI scenes, NotificationCenter, XCTest, Swift Package Manager

---

## File Map

- Create: `Sources/GestureFlowApp/App/AppPresentationController.swift`
  - Own app-shell presentation state, activation-policy changes, and next-turn fallback scheduling.
- Create: `Tests/GestureFlowAppTests/AppPresentationControllerTests.swift`
  - Cover state transitions and fallback cancellation behavior.
- Modify: `Sources/GestureFlowApp/App/AppDelegate.swift`
  - Create and wire shared presentation controller into default coordinator composition.
- Modify: `Sources/GestureFlowApp/App/GestureFlowShellApp.swift`
  - Attach settings scene lifecycle observation hooks.
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneServices.swift`
  - Store shared presentation controller.
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneRoot.swift`
  - Report scene/window visibility events upward.
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
  - Use a presentation-aware `showSettings` path and keep quit semantics unchanged.
- Modify: `Tests/GestureFlowAppTests/AppDelegateTests.swift`
  - Verify default wiring uses shared presentation controller.
- Modify: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`
  - Verify open-settings promotion and post-close gesture continuity.
- Modify: `docs/spikes/route-b-swiftui-settings-notes.md`
  - Record runtime verification outcomes.

## Chunk 1: Presentation State Machine

### Task 1: Add `AppPresentationController`

**Files:**
- Create: `Sources/GestureFlowApp/App/AppPresentationController.swift`
- Create: `Tests/GestureFlowAppTests/AppPresentationControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that describe the state machine:

```swift
func testPrepareToShowSettingsPromotesAccessoryAppToRegular()
func testClosingLastSettingsWindowSchedulesAccessoryFallbackOnNextMainTurn()
func testReopenBeforeFallbackCancelsAccessoryFallback()
func testDuplicateOpenRequestsDoNotRepeatPolicyChange()
```

Test with injected dependencies:
- fake `setActivationPolicy`
- fake `activateApp`
- captured scheduled main-queue work

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'GestureFlowAppTests.AppPresentationControllerTests'`

Expected:
- FAIL because `AppPresentationController` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `AppPresentationController.swift` with explicit state and injected effects:

```swift
import AppKit

final class AppPresentationController {
    enum State {
        case accessoryBackground
        case promotingToForeground
        case foregroundSettingsVisible
        case returningToAccessory
    }

    private let application: NSApplication
    private let setActivationPolicy: (NSApplication.ActivationPolicy) -> Bool
    private let activateApp: () -> Void
    private let scheduleOnMain: (@escaping () -> Void) -> Void

    private(set) var state: State = .accessoryBackground
    private var pendingAccessoryFallbackToken = UUID()

    ...
}
```

Required public surface:
- `prepareToShowSettings()`
- `handleSettingsDidAppear()`
- `handleLastSettingsWindowDidClose()`
- `cancelPendingAccessoryFallbackIfNeeded()`

Behavior:
- `.accessory -> .regular` only once per foreground cycle
- fallback to `.accessory` must be scheduled on next main turn
- reopening before fallback invalidates the pending token

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'GestureFlowAppTests.AppPresentationControllerTests'`

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/App/AppPresentationController.swift Tests/GestureFlowAppTests/AppPresentationControllerTests.swift
git commit -m "feat: add app presentation controller"
```

## Chunk 2: Wire Shared Presentation Services

### Task 2: Add presentation controller to shared services and delegate composition

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneServices.swift`
- Modify: `Sources/GestureFlowApp/App/AppDelegate.swift`
- Modify: `Tests/GestureFlowAppTests/AppDelegateTests.swift`

- [ ] **Step 1: Write the failing tests**

Extend `AppDelegateTests.swift`:

```swift
func testDefaultAppDelegateUsesSharedPresentationController()
func testCustomAppDelegateCanInjectPresentationController()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'GestureFlowAppTests.AppDelegateTests'`

Expected:
- FAIL because shared services do not expose presentation controller yet.

- [ ] **Step 3: Write minimal implementation**

Update `SettingsSceneServices.swift`:

```swift
final class SettingsSceneServices {
    static let shared = SettingsSceneServices()

    let bridge: SettingsSceneBridge
    let openDriver: SettingsSceneOpenDriver
    let presentationController: AppPresentationController
}
```

Update `AppDelegate.swift`:
- inject shared `presentationController`
- default `showSettings` composition becomes:
  1. `presentationController.cancelPendingAccessoryFallbackIfNeeded()`
  2. `presentationController.prepareToShowSettings()`
  3. `bridge.install(viewModel:)`
  4. `openDriver.openSettingsScene()`

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'GestureFlowAppTests.AppDelegateTests'`

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Settings/SettingsSceneServices.swift Sources/GestureFlowApp/App/AppDelegate.swift Tests/GestureFlowAppTests/AppDelegateTests.swift
git commit -m "feat: wire shared presentation controller"
```

## Chunk 3: Observe Settings Scene Lifecycle

### Task 3: Report settings open/close lifecycle to the presentation layer

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowShellApp.swift`
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneRoot.swift`
- Modify: `Sources/GestureFlowApp/Settings/SettingsSceneBridge.swift`

- [ ] **Step 1: Write the failing test**

Add a focused test in `AppPresentationControllerTests.swift` or a new scene-lifecycle test file:

```swift
func testSettingsAppearanceMarksForegroundVisible()
func testClosingLastSettingsWindowTriggersDeferredAccessoryFallback()
```

If direct SwiftUI scene testing is cumbersome, keep unit coverage in `AppPresentationControllerTests` and verify integration indirectly in `AppDelegateTests`.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'GestureFlowAppTests.(AppPresentationControllerTests|AppDelegateTests)'`

Expected:
- FAIL because settings lifecycle is not yet forwarded.

- [ ] **Step 3: Write minimal implementation**

Attach a small observer/bridge so the settings scene can notify the presentation layer:

Options allowed:
- observe `NSWindow.willCloseNotification` for the settings window
- use a tiny `NSViewRepresentable` / `NSHostingView` hook to capture the window and report lifecycle

Required behavior:
- opening settings cancels pending fallback and marks scene visible
- closing the last settings window calls `handleLastSettingsWindowDidClose()`
- do not call `setActivationPolicy(.accessory)` synchronously in the close callback itself

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'GestureFlowAppTests.(AppPresentationControllerTests|AppDelegateTests)'`

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/App/GestureFlowShellApp.swift Sources/GestureFlowApp/Settings/SettingsSceneRoot.swift Sources/GestureFlowApp/Settings/SettingsSceneBridge.swift
git commit -m "feat: observe settings scene lifecycle"
```

## Chunk 4: Update Coordinator Behavior

### Task 4: Keep gesture logic independent from foreground/background presentation

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`

- [ ] **Step 1: Write the failing tests**

Add or update tests:

```swift
func testPreferencesMenuPromotesAppThenOpensSettings()
func testClosingSettingsDoesNotStopGestureRecognition()
func testQuitStillStopsGestureRecognitionAndTerminates()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'GestureFlowAppTests.GestureFlowApplicationTests'`

Expected:
- FAIL on new promotion/close semantics.

- [ ] **Step 3: Write minimal implementation**

Keep `GestureFlowApplication` focused on:
- building/reusing `SettingsViewModel`
- invoking the injected `showSettings`
- not caring whether the app is currently `.regular` or `.accessory`

If needed, add a test-only spy callback order assertion:

```swift
["cancelFallback", "prepareToShowSettings", "installViewModel", "openScene"]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'GestureFlowAppTests.GestureFlowApplicationTests'`

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/App/GestureFlowApplication.swift Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift
git commit -m "test: preserve gesture behavior across settings presentation"
```

## Chunk 5: Full Regression and Runtime Notes

### Task 5: Verify the dynamic presentation path end-to-end

**Files:**
- Modify: `docs/spikes/route-b-swiftui-settings-notes.md`

- [ ] **Step 1: Run the focused test suite**

Run:

```bash
swift test --filter 'GestureFlowAppTests.(AppPresentationControllerTests|AppDelegateTests|GestureFlowApplicationTests|SettingsSceneBridgeTests|SettingsSceneOpenDriverTests)'
```

Expected:
- PASS

- [ ] **Step 2: Run the full test suite**

Run:

```bash
swift test
```

Expected:
- PASS

- [ ] **Step 3: Manually verify runtime behavior**

Verify in order:
1. Launch app and confirm settings appears as a Dock-visible foreground app.
2. Close the last settings window and confirm Dock presence disappears while the menu bar item remains.
3. Start gesture recognition, close settings, and confirm recognition continues.
4. Reopen Preferences from the menu bar and confirm Dock-visible foreground behavior returns.
5. Quit from the menu bar and confirm the entire process exits.

- [ ] **Step 4: Record results**

Write results to `docs/spikes/route-b-swiftui-settings-notes.md`:

```md
## Dynamic Activation Policy Verification
- Launch behavior:
- Close-to-accessory behavior:
- Gesture continuity after close:
- Reopen behavior:
- Quit behavior:
- Regressions:
```

- [ ] **Step 5: Commit**

```bash
git add docs/spikes/route-b-swiftui-settings-notes.md
git commit -m "test: verify dynamic activation policy settings flow"
```
