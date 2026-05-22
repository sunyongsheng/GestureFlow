# Settings Sidebar Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the GestureFlow settings content as a macOS-style sidebar layout with app controls in General, polished Trigger and Feedback cards in Appearance, existing gesture management in Gestures, and bundle version details in About.

**Architecture:** Keep the existing SwiftUI `Settings` scene, bridge, and lifecycle coordination unchanged. Extend `SettingsViewModel` with injected app-shell actions, then replace the single-page `MainSettingsView` with a local sidebar-driven layout that composes focused section views.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager.

---

## File Map

- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
  - Inject start, stop, quit, and placeholder actions into `SettingsViewModel`.
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
  - Add action closures and view-model methods for app controls and About metadata.
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`
  - Replace the single-page panel with a sidebar + detail-pane layout and shared styling helpers.
- Modify: `Sources/GestureFlowApp/Settings/GestureTriggerSettingsView.swift`
  - Restyle Trigger controls to match the new card-based settings UI.
- Modify: `Sources/GestureFlowApp/Settings/FeedbackSettingsView.swift`
  - Restyle Feedback controls to match the new card-based settings UI.
- Create: `Sources/GestureFlowApp/Settings/SettingsSidebarModels.swift`
  - Define the section enum and sidebar item metadata.
- Create: `Sources/GestureFlowApp/Settings/GeneralSettingsView.swift`
  - Render General controls and bind to view-model actions.
- Create: `Sources/GestureFlowApp/Settings/AppearanceSettingsView.swift`
  - Compose the Trigger and Feedback cards into a dedicated page.
- Create: `Sources/GestureFlowApp/Settings/AboutSettingsView.swift`
  - Show app name, version, and build information.
- Test: `Tests/GestureFlowAppTests/SettingsViewModelTests.swift`
  - Cover new app-shell action methods.
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`
  - Cover new settings view-model action injection paths.

## Chunk 1: Add App-Shell Actions To The View Model

### Task 1: Extend `SettingsViewModel` with injected control actions

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- Test: `Tests/GestureFlowAppTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write failing tests for new actions**

Add focused tests that prove the view model delegates through injected closures:

```swift
func testSetGestureRecognitionEnabledTrueInvokesStartAction() {
    var startCount = 0
    var stopCount = 0
    let viewModel = SettingsViewModel(
        loadResult: ConfigurationLoadResult(configuration: AppConfiguration(), didRecoverFromCorruption: false, backupURL: nil),
        isRunning: false,
        isAccessibilityTrusted: true,
        saveConfiguration: { _ in },
        requestAccessibilityPermission: {},
        startGestureFlow: { startCount += 1 },
        stopGestureFlow: { stopCount += 1 },
        quitApplication: {},
        showLaunchAtLoginPlaceholder: {}
    )

    viewModel.setGestureRecognitionEnabled(true)

    XCTAssertEqual(startCount, 1)
    XCTAssertEqual(stopCount, 0)
}
```

Add matching tests for:

- `setGestureRecognitionEnabled(false)` -> stop action
- `quitApplication()` -> quit action
- `showLaunchAtLoginPlaceholder()` -> placeholder action

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
swift test --filter SettingsViewModelTests
```

Expected: compile or runtime failure because the initializer and methods do not exist yet.

- [ ] **Step 3: Implement the minimal view-model changes**

Add stored closures and methods:

```swift
private let startGestureFlowAction: () -> Void
private let stopGestureFlowAction: () -> Void
private let quitApplicationAction: () -> Void
private let launchAtLoginPlaceholderAction: () -> Void

func setGestureRecognitionEnabled(_ isEnabled: Bool) {
    isEnabled ? startGestureFlowAction() : stopGestureFlowAction()
}

func quitApplication() {
    quitApplicationAction()
}

func showLaunchAtLoginPlaceholder() {
    launchAtLoginPlaceholderAction()
}
```

Keep defaults as no-op closures so existing call sites remain simple while code is migrated.

- [ ] **Step 4: Rerun the focused tests**

Run:

```bash
swift test --filter SettingsViewModelTests
```

Expected: PASS for the new action delegation tests and existing persistence tests.

### Task 2: Inject the new actions from `GestureFlowApplication`

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`

- [ ] **Step 1: Write failing integration tests for injected settings actions**

Add focused tests that capture the installed view model and drive its new methods:

```swift
func testSettingsViewModelCanStartGestureFlowThroughInjectedAction() throws {
    let fileURL = try makeTemporaryConfigURL()
    let store = ConfigurationStore(fileURL: fileURL)
    let permissionService = PermissionService(trustCheck: { true }, permissionPrompt: {})
    let eventTap = ApplicationSpyMouseEventTapController()
    let gestureEngine = GestureEngine(
        configurationProvider: { AppConfiguration() },
        permissionService: permissionService,
        eventTap: eventTap
    )
    var capturedSettingsViewModel: SettingsViewModel?
    let application = GestureFlowApplication(
        configurationStore: store,
        permissionService: permissionService,
        gestureEngine: gestureEngine,
        showSettings: { capturedSettingsViewModel = $0; _ = $1 }
    )

    application.launch()
    capturedSettingsViewModel?.setGestureRecognitionEnabled(true)

    XCTAssertTrue(gestureEngine.isRunning)
}
```

Add matching tests for:

- Stopping through `setGestureRecognitionEnabled(false)`
- Quitting through `quitApplication()`

- [ ] **Step 2: Run the focused application tests to verify they fail**

Run:

```bash
swift test --filter GestureFlowApplicationTests
```

Expected: failure because the settings view model does not yet receive the new injected actions.

- [ ] **Step 3: Implement action injection in `makeSettingsViewModel()`**

Inject closures that call existing coordinator methods:

```swift
startGestureFlow: { [weak self] in self?.startGestureFlow() },
stopGestureFlow: { [weak self] in self?.stopGestureFlow() },
quitApplication: { [weak self] in self?.quitApplication() },
showLaunchAtLoginPlaceholder: { [weak self] in
    self?.showPlaceholder(title: "Open at Login")
}
```

- [ ] **Step 4: Rerun the application tests**

Run:

```bash
swift test --filter GestureFlowApplicationTests
```

Expected: PASS for the new settings action tests and all existing app-shell tests.

## Chunk 2: Build The Sidebar Settings Shell

### Task 3: Add local sidebar navigation models

**Files:**
- Create: `Sources/GestureFlowApp/Settings/SettingsSidebarModels.swift`
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`

- [ ] **Step 1: Create a section enum and presentation metadata**

Add a focused model file like:

```swift
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case gestures
    case about

    var id: String { rawValue }
    var title: String { ... }
    var symbolName: String { ... }
}
```

- [ ] **Step 2: Replace the top-level layout in `MainSettingsView`**

Create a split layout with:

- fixed-width navigation rail on the left
- flexible detail area on the right
- local `@State` selection defaulting to `.general`
- continued display of recovery and save error banners in the detail area

- [ ] **Step 3: Add a section switcher in the detail pane**

Render the currently selected page via a `switch selectedSection`.

- [ ] **Step 4: Build and compile the shell**

Run:

```bash
swift test --filter SettingsViewModelTests
```

Expected: compile success even before page-specific views are finalized.

### Task 4: Add the General page

**Files:**
- Create: `Sources/GestureFlowApp/Settings/GeneralSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`

- [ ] **Step 1: Implement the General page structure**

Create rows for:

- `登录时打开` toggle row
- `手势识别` live toggle row
- `Accessibility` full-width button row
- `退出应用` button row

- [ ] **Step 2: Bind controls to the view model**

Use explicit bindings and button actions:

```swift
Toggle("手势识别", isOn: Binding(
    get: { viewModel.isRunning },
    set: { viewModel.setGestureRecognitionEnabled($0) }
))
```

`登录时打开` should call `showLaunchAtLoginPlaceholder()` when toggled.

- [ ] **Step 3: Apply macOS-style row visuals**

Use grouped card backgrounds, secondary descriptions, inline status text, and a green success color for the satisfied Accessibility state.

- [ ] **Step 4: Compile the General page**

Run:

```bash
swift test --filter SettingsViewModelTests
```

Expected: compile success and no action-regression failures.

### Task 5: Add the Appearance and About pages

**Files:**
- Create: `Sources/GestureFlowApp/Settings/AppearanceSettingsView.swift`
- Create: `Sources/GestureFlowApp/Settings/AboutSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`

- [ ] **Step 1: Compose the Appearance page**

Build a page that stacks:

```swift
GestureTriggerSettingsView(viewModel: viewModel)
FeedbackSettingsView(viewModel: viewModel)
```

with page title and spacing that match the new detail layout.

- [ ] **Step 2: Add bundle-backed About content**

Read version info from `Bundle.main`:

```swift
let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
```

Display whichever values are available.

- [ ] **Step 3: Hook both pages into the section switch**

Map:

- `.appearance` -> `AppearanceSettingsView`
- `.about` -> `AboutSettingsView`

- [ ] **Step 4: Compile the new pages**

Run:

```bash
swift test --filter SettingsViewModelTests
```

Expected: compile success.

## Chunk 3: Polish Existing Pages Inside The New Layout

### Task 6: Restyle Trigger and Feedback cards

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/GestureTriggerSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/FeedbackSettingsView.swift`

- [ ] **Step 1: Replace plain panels with richer settings cards**

For both views:

- add section subtitle text
- show current values inline with labels
- increase vertical spacing
- use a shared rounded card appearance

- [ ] **Step 2: Keep existing bindings unchanged**

Do not alter the underlying config update logic. Only improve presentation structure and labeling.

- [ ] **Step 3: Compile the restyled cards**

Run:

```bash
swift test --filter SettingsViewModelTests
```

Expected: compile success with no persistence regressions.

### Task 7: Mount the existing Gestures view in the new detail pane

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`

- [ ] **Step 1: Render the current gestures experience for the Gestures page**

Use:

```swift
GestureListView(viewModel: viewModel)
```

inside the detail layout for `.gestures`.

- [ ] **Step 2: Preserve enough width for the existing editor**

Ensure the detail pane gives the gesture list/editor a wide layout so current functionality remains usable.

- [ ] **Step 3: Compile the full settings window**

Run:

```bash
swift test --filter GestureFlowApplicationTests
```

Expected: compile success and no regression in settings window setup.

## Chunk 4: Verify Behavior And Diagnostics

### Task 8: Run targeted tests

**Files:**
- Test: `Tests/GestureFlowAppTests/SettingsViewModelTests.swift`
- Test: `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`

- [ ] **Step 1: Run settings tests**

Run:

```bash
swift test --filter SettingsViewModelTests
swift test --filter GestureFlowApplicationTests
```

Expected: PASS.

- [ ] **Step 2: If failures appear, fix only the failing scope**

Keep fixes limited to:

- injected action wiring
- settings UI compilation issues
- bundle version display logic

### Task 9: Run editor diagnostics and inspect diff

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/Settings/*.swift`
- Modify: `Tests/GestureFlowAppTests/*.swift`

- [ ] **Step 1: Check diagnostics for edited Swift files**

Use the editor diagnostics tool on each edited file.

Expected: no new diagnostics.

- [ ] **Step 2: Inspect the focused diff**

Run:

```bash
git diff -- \
  Sources/GestureFlowApp/App/GestureFlowApplication.swift \
  Sources/GestureFlowApp/Settings \
  Tests/GestureFlowAppTests/SettingsViewModelTests.swift \
  Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift
```

Expected:

- sidebar navigation appears only in the settings UI layer
- app-shell actions remain coordinated by `GestureFlowApplication`
- unimplemented launch-at-login surfaces a placeholder
- existing trigger, feedback, and gesture editing logic remains intact

- [ ] **Step 3: Skip commit because the user requested no git commits in this task**
