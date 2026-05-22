# GestureFlow macOS Native MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure Swift macOS native MVP for GestureFlow with menu bar control, Accessibility permission guidance, global mouse gesture capture, gesture recognition, visual feedback, action execution, and local JSON configuration.

**Architecture:** Use Swift Package Manager for a testable native macOS codebase. Keep gesture recognition, configuration, and action models in a reusable `GestureFlowCore` library; build a macOS AppKit/SwiftUI executable in `GestureFlowApp`; package it into a `.app` bundle with a script for local and future site distribution.

**Tech Stack:** Swift 5.9+, SwiftPM, XCTest, SwiftUI, AppKit, CoreGraphics/Quartz, ApplicationServices, Foundation.

---

## File Structure

- Create: `Package.swift`
  Defines `GestureFlowCore`, `GestureFlowApp`, and `GestureFlowCoreTests`.
- Create: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
  Defines persisted configuration and default values.
- Create: `Sources/GestureFlowCore/Models/GestureDefinition.swift`
  Defines gesture trigger, signature, scope, and action models.
- Create: `Sources/GestureFlowCore/Recognition/GestureNormalizer.swift`
  Cleans, simplifies, normalizes bounding box, and prepares raw gesture points
  for direction segmentation.
- Create: `Sources/GestureFlowCore/Recognition/GestureRecognizer.swift`
  Converts normalized points into direction signatures.
- Create: `Sources/GestureFlowCore/Matching/GestureMatcher.swift`
  Matches recognized signatures against enabled configured gestures.
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationStore.swift`
  Loads, validates, atomically saves, and recovers JSON configuration under
  Application Support.
- Create: `Sources/GestureFlowCore/Validation/ConflictDetector.swift`
  Performs MVP duplicate trigger/signature conflict checks.
- Create: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
  AppKit application bootstrap and service wiring.
- Create: `Sources/GestureFlowApp/App/main.swift`
  Executable entry point.
- Create: `Sources/GestureFlowApp/Menu/StatusBarController.swift`
  Menu bar item and menu commands.
- Create: `Sources/GestureFlowApp/Permissions/PermissionService.swift`
  Accessibility permission checks and prompts.
- Create: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
  Global mouse event tap and point capture.
- Create: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
  Runtime coordinator for capture, recognition, matching, feedback, and actions.
- Create: `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift`
  Transparent overlay window.
- Create: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
  AppKit drawing view for gesture trails and messages.
- Create: `Sources/GestureFlowApp/Actions/ActionExecutor.swift`
  Executes keyboard shortcut, app open, URL open, and system command actions.
- Create: `Sources/GestureFlowApp/Settings/SettingsWindowController.swift`
  Hosts SwiftUI settings in an AppKit window.
- Create: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`
  Main SwiftUI settings UI.
- Create: `Sources/GestureFlowApp/Settings/GestureListView.swift`
  Gesture list UI.
- Create: `Sources/GestureFlowApp/Settings/GestureEditorView.swift`
  Basic gesture editor UI.
- Create: `Sources/GestureFlowApp/Settings/PermissionGuideView.swift`
  Accessibility onboarding UI.
- Create: `Sources/GestureFlowApp/Settings/FeedbackSettingsView.swift`
  Trail and feedback settings UI.
- Create: `Tests/GestureFlowCoreTests/GestureRecognizerTests.swift`
  Unit tests for point-to-signature recognition.
- Create: `Tests/GestureFlowCoreTests/GestureMatcherTests.swift`
  Unit tests for matching.
- Create: `Tests/GestureFlowCoreTests/ConfigurationStoreTests.swift`
  Unit tests for JSON persistence.
- Create: `Tests/GestureFlowCoreTests/ConflictDetectorTests.swift`
  Unit tests for duplicate conflict checks.
- Create: `Resources/Info.plist`
  App bundle metadata for packaging.
- Create: `Scripts/package_app.sh`
  Builds the executable and wraps it into `build/GestureFlow.app`.
- Modify: `docs/superpowers/specs/2026-05-18-gestureflow-macos-native-design.md`
  Only if implementation discoveries require design clarification.

---

## Chunk 1: Project Scaffold and Core Models

### Task 1: Create SwiftPM Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Create: `Sources/GestureFlowCore/Models/GestureDefinition.swift`
- Create: `Sources/GestureFlowApp/App/main.swift`
- Test: `Tests/GestureFlowCoreTests/GestureRecognizerTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestureFlow",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "GestureFlowCore", targets: ["GestureFlowCore"]),
        .executable(name: "GestureFlowApp", targets: ["GestureFlowApp"])
    ],
    targets: [
        .target(
            name: "GestureFlowCore"
        ),
        .executableTarget(
            name: "GestureFlowApp",
            dependencies: ["GestureFlowCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "GestureFlowCoreTests",
            dependencies: ["GestureFlowCore"]
        )
    ]
)
```

- [ ] **Step 2: Create placeholder app entry point**

```swift
import AppKit

NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
```

- [ ] **Step 3: Create initial model files**

```swift
import Foundation

public struct AppConfiguration: Codable, Equatable {
    public var isEnabled: Bool
    public var gestures: [GestureDefinition]
    public var feedback: FeedbackConfiguration

    public init(
        isEnabled: Bool = false,
        gestures: [GestureDefinition] = GestureDefinition.defaults,
        feedback: FeedbackConfiguration = .default
    ) {
        self.isEnabled = isEnabled
        self.gestures = gestures
        self.feedback = feedback
    }
}

public struct FeedbackConfiguration: Codable, Equatable {
    public var trailColorHex: String
    public var trailWidth: Double
    public var trailOpacity: Double

    public static let `default` = FeedbackConfiguration(
        trailColorHex: "#4A90E2",
        trailWidth: 4,
        trailOpacity: 0.85
    )
}
```

```swift
import Foundation

public struct GestureDefinition: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var trigger: GestureTrigger
    public var signature: GestureSignature
    public var action: GestureAction
    public var scope: GestureScope

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        trigger: GestureTrigger,
        signature: GestureSignature,
        action: GestureAction,
        scope: GestureScope = .global
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.signature = signature
        self.action = action
        self.scope = scope
    }
}

public enum GestureTrigger: String, Codable, Equatable, CaseIterable {
    case rightMouse
    case middleMouse
}

public struct GestureSignature: Codable, Equatable, Hashable {
    public var tokens: [GestureDirection]

    public init(tokens: [GestureDirection]) {
        self.tokens = tokens
    }
}

public enum GestureDirection: String, Codable, Equatable, Hashable, CaseIterable {
    case up = "U"
    case down = "D"
    case left = "L"
    case right = "R"
}

public enum GestureScope: Codable, Equatable {
    case global
}

public enum GestureAction: Codable, Equatable {
    case keyboardShortcut(KeyboardShortcutAction)
    case openApplication(OpenApplicationAction)
    case openURL(OpenURLAction)
    case systemCommand(SystemCommandAction)
}

public struct KeyboardShortcutAction: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: [KeyboardModifier]
}

public enum KeyboardModifier: String, Codable, Equatable {
    case command
    case option
    case control
    case shift
}

public struct OpenApplicationAction: Codable, Equatable {
    public var bundleIdentifier: String
}

public struct OpenURLAction: Codable, Equatable {
    public var url: URL
}

public enum SystemCommandAction: String, Codable, Equatable {
    case showDesktop
    case lockScreen
}
```

- [ ] **Step 4: Add default gestures**

```swift
public extension GestureDefinition {
    static let defaults: [GestureDefinition] = [
        GestureDefinition(
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .keyboardShortcut(KeyboardShortcutAction(keyCode: 123, modifiers: [.command]))
        ),
        GestureDefinition(
            name: "Forward",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.right]),
            action: .keyboardShortcut(KeyboardShortcutAction(keyCode: 124, modifiers: [.command]))
        )
    ]
}
```

- [ ] **Step 5: Build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold native GestureFlow package"
```

If the directory is not a Git repository, skip the commit and record it in the final handoff.

---

## Chunk 2: Recognition, Matching, and Persistence

### Task 2: Implement Gesture Recognition with Tests

**Files:**
- Create: `Sources/GestureFlowCore/Recognition/GestureNormalizer.swift`
- Create: `Sources/GestureFlowCore/Recognition/GestureRecognizer.swift`
- Test: `Tests/GestureFlowCoreTests/GestureRecognizerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import GestureFlowCore

final class GestureRecognizerTests: XCTestCase {
    func testRecognizesRightGesture() {
        let points = [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 40, y: 2),
            GesturePoint(x: 90, y: 3)
        ]

        let signature = GestureRecognizer().recognize(points: points)

        XCTAssertEqual(signature, GestureSignature(tokens: [.right]))
    }

    func testRecognizesDownThenRightGesture() {
        let points = [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 0, y: 60),
            GesturePoint(x: 70, y: 62)
        ]

        let signature = GestureRecognizer().recognize(points: points)

        XCTAssertEqual(signature, GestureSignature(tokens: [.down, .right]))
    }

    func testRejectsTinyMovement() {
        let points = [
            GesturePoint(x: 0, y: 0),
            GesturePoint(x: 2, y: 1)
        ]

        XCTAssertNil(GestureRecognizer().recognize(points: points))
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `swift test --filter GestureRecognizerTests`

Expected: FAIL because recognizer types do not exist.

- [ ] **Step 3: Implement minimal recognizer**

```swift
import Foundation

public struct GesturePoint: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct GestureNormalizer {
    public init() {}

    public func removeJitter(from points: [GesturePoint], minimumDistance: Double = 8) -> [GesturePoint] {
        guard let first = points.first else { return [] }
        var result = [first]
        for point in points.dropFirst() {
            guard let last = result.last else { continue }
            let dx = point.x - last.x
            let dy = point.y - last.y
            if hypot(dx, dy) >= minimumDistance {
                result.append(point)
            }
        }
        return result
    }

    public func normalizeBoundingBox(_ points: [GesturePoint]) -> [GesturePoint] {
        guard points.count >= 2 else { return points }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)

        return points.map {
            GesturePoint(
                x: ($0.x - minX) / width,
                y: ($0.y - minY) / height
            )
        }
    }

    public func pathLength(of points: [GesturePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }
}
```

```swift
import Foundation

public struct GestureRecognizer {
    private let normalizer: GestureNormalizer

    public init(normalizer: GestureNormalizer = GestureNormalizer()) {
        self.normalizer = normalizer
    }

    public func recognize(points: [GesturePoint]) -> GestureSignature? {
        let cleaned = normalizer.removeJitter(from: points)
        guard cleaned.count >= 2 else { return nil }
        guard normalizer.pathLength(of: cleaned) >= 24 else { return nil }

        var directions: [GestureDirection] = []
        for pair in zip(cleaned, cleaned.dropFirst()) {
            let dx = pair.1.x - pair.0.x
            let dy = pair.1.y - pair.0.y
            let direction: GestureDirection = abs(dx) >= abs(dy)
                ? (dx >= 0 ? .right : .left)
                : (dy >= 0 ? .down : .up)
            if directions.last != direction {
                directions.append(direction)
            }
        }

        return directions.isEmpty ? nil : GestureSignature(tokens: directions)
    }
}
```

Keep `normalizeBoundingBox(_:)` covered by tests even if the first direction
segmentation uses raw deltas. This preserves the intended recognition pipeline
and gives the later template-matching implementation a tested foundation.

- [ ] **Step 4: Run tests**

Run: `swift test --filter GestureRecognizerTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Recognition Tests/GestureFlowCoreTests/GestureRecognizerTests.swift
git commit -m "feat: add deterministic gesture recognition"
```

### Task 3: Implement Matching, Conflicts, and Configuration Store

**Files:**
- Create: `Sources/GestureFlowCore/Matching/GestureMatcher.swift`
- Create: `Sources/GestureFlowCore/Validation/ConflictDetector.swift`
- Create: `Sources/GestureFlowCore/Configuration/ConfigurationStore.swift`
- Test: `Tests/GestureFlowCoreTests/GestureMatcherTests.swift`
- Test: `Tests/GestureFlowCoreTests/ConflictDetectorTests.swift`
- Test: `Tests/GestureFlowCoreTests/ConfigurationStoreTests.swift`

- [ ] **Step 1: Write matcher tests**

```swift
import XCTest
@testable import GestureFlowCore

final class GestureMatcherTests: XCTestCase {
    func testMatchesEnabledGestureWithSameTriggerAndSignature() {
        let gesture = GestureDefinition(
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .systemCommand(.showDesktop)
        )

        let match = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            in: [gesture]
        )

        XCTAssertEqual(match?.id, gesture.id)
    }

    func testDoesNotMatchDisabledGesture() {
        var gesture = GestureDefinition(
            name: "Back",
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            action: .systemCommand(.showDesktop)
        )
        gesture.isEnabled = false

        let match = GestureMatcher().match(
            trigger: .rightMouse,
            signature: GestureSignature(tokens: [.left]),
            in: [gesture]
        )

        XCTAssertNil(match)
    }
}
```

- [ ] **Step 2: Implement matcher**

```swift
public struct GestureMatcher {
    public init() {}

    public func match(
        trigger: GestureTrigger,
        signature: GestureSignature,
        in gestures: [GestureDefinition]
    ) -> GestureDefinition? {
        gestures.first {
            $0.isEnabled &&
            $0.trigger == trigger &&
            $0.signature == signature
        }
    }
}
```

- [ ] **Step 3: Add conflict and configuration tests**

Write tests that verify duplicate enabled trigger/signature combinations are reported and that configuration can round-trip through JSON in a temporary directory.

- [ ] **Step 4: Implement conflict detector and configuration store**

Keep implementations small:

- `ConflictDetector.detect(in:) -> [GestureConflict]`.
- `ConfigurationStore.load() throws -> AppConfiguration`.
- `ConfigurationStore.loadRecovering() -> ConfigurationLoadResult`.
- `ConfigurationStore.save(_:) throws` using atomic replacement.
- `ConfigurationStore` accepts an injectable file URL for tests.
- Invalid decoded configuration backs up the corrupted file as
  `config.json.corrupt-<timestamp>` and returns defaults.

- [ ] **Step 5: Run tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowCore Tests/GestureFlowCoreTests
git commit -m "feat: add gesture matching and persistence"
```

---

## Chunk 3: Native App Runtime

### Task 4: Add AppKit Application, Menu Bar, and Permission Service

**Files:**
- Create: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/App/main.swift`
- Create: `Sources/GestureFlowApp/Menu/StatusBarController.swift`
- Create: `Sources/GestureFlowApp/Permissions/PermissionService.swift`

- [ ] **Step 1: Implement permission service**

```swift
import ApplicationServices
import Foundation

final class PermissionService {
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func promptForAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 2: Implement application coordinator**

Create `GestureFlowApplication` to initialize `ConfigurationStore`, `PermissionService`, `StatusBarController`, and later runtime services.

- [ ] **Step 3: Implement status bar menu**

Menu items:

- Start GestureFlow.
- Stop GestureFlow.
- Open Settings.
- Common Gestures.
- Preferences.
- Accessibility Permission.
- Quit.

- [ ] **Step 4: Wire `main.swift`**

Create an `NSApplication`, set activation policy to `.accessory`, instantiate `GestureFlowApplication`, and call `run()`.

- [ ] **Step 5: Build and run**

Run: `swift build && swift run GestureFlowApp`

Expected: menu bar icon appears and Quit exits the app.

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp
git commit -m "feat: add menu bar application shell"
```

### Task 5: Add Mouse Event Tap and Gesture Engine

**Files:**
- Create: `Sources/GestureFlowApp/EventTap/MouseEventTap.swift`
- Create: `Sources/GestureFlowApp/Engine/GestureEngine.swift`
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/Menu/StatusBarController.swift`

- [ ] **Step 1: Implement `MouseEventTap` interface**

Use callbacks:

- `onGestureBegan(trigger: GestureTrigger, at: GesturePoint)`.
- `onGestureMoved(point: GesturePoint)`.
- `onGestureEnded(trigger: GestureTrigger, points: [GesturePoint])`.

- [ ] **Step 2: Implement CGEvent tap**

Listen for right mouse down, right mouse dragged, right mouse up, and other mouse events for middle button when available.

Return event handling decisions explicitly:

- A normal right click with movement below the gesture threshold must pass
  through and show the system context menu.
- A recognized right-button gesture must suppress the matching right-mouse-up
  context-menu path.
- A failed gesture with enough movement should suppress the context menu to
  avoid accidental right-clicks after drawing.
- Middle-button gestures should not affect right-click behavior.

- [ ] **Step 3: Implement `GestureEngine`**

Responsibilities:

- Start only when Accessibility permission is granted.
- Start and stop `MouseEventTap`.
- Recognize completed gestures.
- Match configured gestures.
- Call action execution and feedback hooks.

- [ ] **Step 4: Wire menu commands**

Start and stop menu items call `GestureEngine.start()` and `GestureEngine.stop()`.

- [ ] **Step 5: Manual test**

Run: `swift run GestureFlowApp`

Expected:

- Without permission, start prompts or shows permission guidance.
- With permission, right-drag logs recognized signatures.
- Normal right click still opens context menus.
- Right-button gesture does not open a context menu after release.
- Middle-button gesture logs recognized signatures on supported hardware.
- Stop disables event tap.

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp/EventTap Sources/GestureFlowApp/Engine Sources/GestureFlowApp/App Sources/GestureFlowApp/Menu
git commit -m "feat: capture global mouse gestures"
```

---

## Chunk 4: Feedback Overlay and Action Execution

### Task 6: Add Gesture Trail Overlay

**Files:**
- Create: `Sources/GestureFlowApp/Overlay/GestureOverlayWindow.swift`
- Create: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`

- [ ] **Step 1: Implement transparent overlay window**

Use an `NSPanel` or borderless `NSWindow` with:

- `isOpaque = false`.
- `backgroundColor = .clear`.
- `ignoresMouseEvents = true`.
- high window level such as `.statusBar` or `.screenSaver` after testing.

- [ ] **Step 2: Implement drawing view**

Draw points as a stroked path using configured color, width, and opacity.

- [ ] **Step 3: Connect engine updates**

Show overlay on gesture begin, update on movement, and hide within one second after completion.

- [ ] **Step 4: Manual test**

Run: `swift run GestureFlowApp`

Expected: right-drag displays a trail and hides after release.

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Overlay Sources/GestureFlowApp/Engine
git commit -m "feat: show gesture trail overlay"
```

### Task 7: Implement Action Execution

**Files:**
- Create: `Sources/GestureFlowApp/Actions/ActionExecutor.swift`
- Modify: `Sources/GestureFlowApp/Engine/GestureEngine.swift`

- [ ] **Step 1: Implement keyboard shortcut execution**

Map `KeyboardModifier` to `CGEventFlags`, create key down and key up events, and post them through `CGEvent.post(tap: .cghidEventTap)`.

- [ ] **Step 2: Implement app and URL opening**

Use `NSWorkspace.shared.openApplication(at:configuration:)` where possible and `NSWorkspace.shared.open(_:)` for URLs.

- [ ] **Step 3: Implement MVP system commands**

Use keyboard shortcuts or public APIs for MVP commands:

- `showDesktop`: `Command` + `F3` equivalent if reliable.
- `lockScreen`: call `/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession -suspend` through `Process` only if acceptable; otherwise defer and show unsupported action.

- [ ] **Step 4: Connect engine to executor**

On matched gesture, call executor and show success or failure feedback.

- [ ] **Step 5: Manual test**

Expected:

- Left gesture triggers Command + Left.
- Right gesture triggers Command + Right.
- URL action opens the configured URL.

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp/Actions Sources/GestureFlowApp/Engine
git commit -m "feat: execute gesture actions"
```

---

## Chunk 5: Settings UI and Packaging

### Task 8: Add SwiftUI Settings Window

**Files:**
- Create: `Sources/GestureFlowApp/Settings/SettingsWindowController.swift`
- Create: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`
- Create: `Sources/GestureFlowApp/Settings/GestureListView.swift`
- Create: `Sources/GestureFlowApp/Settings/GestureEditorView.swift`
- Create: `Sources/GestureFlowApp/Settings/PermissionGuideView.swift`
- Create: `Sources/GestureFlowApp/Settings/FeedbackSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Menu/StatusBarController.swift`

- [ ] **Step 1: Create settings window controller**

Host `MainSettingsView` inside `NSHostingController`.

- [ ] **Step 2: Create `MainSettingsView`**

Show:

- Running status.
- Permission status.
- Gesture list.
- Feedback settings.

- [ ] **Step 3: Create gesture list and editor**

Support MVP editing:

- Enable or disable gesture.
- Rename gesture.
- Select trigger.
- Select signature from preset options.
- Select action from simple action choices.

- [ ] **Step 4: Save configuration**

On changes, update `AppConfiguration` and persist through `ConfigurationStore`.

- [ ] **Step 5: Manual test**

Expected:

- Open Settings from menu.
- Edit a gesture.
- Quit and relaunch.
- Edited configuration persists.

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp/Settings Sources/GestureFlowApp/Menu
git commit -m "feat: add settings UI"
```

### Task 9: Add App Bundle Packaging

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/package_app.sh`
- Create: `.gitignore`
- Modify: `README.md`

- [ ] **Step 1: Create `Info.plist`**

Include:

- `CFBundleName`: `GestureFlow`.
- `CFBundleIdentifier`: `com.gestureflow.app`.
- `CFBundleExecutable`: `GestureFlowApp`.
- `CFBundlePackageType`: `APPL`.
- `LSUIElement`: `true`.
- `NSAppleEventsUsageDescription` only if Apple events are introduced later.

- [ ] **Step 2: Create package script**

Script flow:

- Run `swift build -c release`.
- Create `build/GestureFlow.app/Contents/MacOS`.
- Copy release executable into bundle.
- Copy `Resources/Info.plist`.

- [ ] **Step 3: Create `.gitignore`**

Ignore `.build/`, `build/`, `.DS_Store`, and Xcode derived data.

- [ ] **Step 4: Create README**

Document:

- Requirements.
- Build command.
- Run command.
- Package command.
- Accessibility permission setup.
- MVP limitations.

- [ ] **Step 5: Test package**

Run: `Scripts/package_app.sh`

Expected: `build/GestureFlow.app` exists and opens through Finder or `open build/GestureFlow.app`.

- [ ] **Step 6: Commit**

```bash
git add Resources Scripts .gitignore README.md
git commit -m "chore: package GestureFlow app bundle"
```

---

## Chunk 6: Final Verification

### Task 10: Run Full Verification

**Files:**
- Modify only files needed for fixes discovered during verification.

- [ ] **Step 1: Run unit tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Run debug app**

Run: `swift run GestureFlowApp`

Expected: menu bar app starts.

- [ ] **Step 3: Run package script**

Run: `Scripts/package_app.sh`

Expected: `.app` bundle created successfully.

- [ ] **Step 4: Manual smoke test**

Verify:

- Permission guide appears when needed.
- Start and stop work.
- Right mouse gesture shows trail.
- Normal right click still opens the context menu.
- Recognized right-button gesture suppresses the context menu.
- Middle mouse gesture works on supported hardware or is documented as unsupported for the current device.
- Recognized gesture executes configured action.
- Settings changes persist after relaunch.
- Corrupted JSON configuration is backed up and defaults are loaded.

- [ ] **Step 5: Record known limitations**

Update `README.md` with any confirmed limitations, especially:

- Trackpad gestures deferred.
- AppleScript deferred.
- Developer ID signing and notarization not configured yet.
- Some system actions may be shortcut-backed or unsupported.

- [ ] **Step 6: Final commit**

```bash
git add .
git commit -m "docs: document GestureFlow MVP verification"
```

If no Git repository exists, skip commits and list changed files in the handoff.
