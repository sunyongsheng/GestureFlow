# GestureFlow macOS Native Design

## Context

GestureFlow is a pure macOS native mouse gesture utility based on the PRD in
`docs/macOS 手势增强工具 PRD（类似 WGestures2）.md`.

The repository currently contains only product documentation and no existing
Swift or Xcode project. The first implementation should therefore scaffold a new
macOS app from scratch.

## Confirmed Direction

- Build a pure macOS native app in Swift.
- Target site distribution with Developer ID signing and notarization later.
- Use a focused MVP first, instead of implementing the full PRD at once.
- Use a hybrid native architecture:
  - SwiftUI for configuration UI.
  - AppKit for menu bar, windows, overlay, and app lifecycle details.
  - Quartz/CoreGraphics for global mouse event monitoring.

## MVP Scope

### Included

- Menu bar resident app.
- Start and stop gesture engine from menu bar and main window.
- Accessibility permission check and onboarding guidance.
- Global mouse gesture capture with right button and middle button triggers.
- Real-time gesture trail overlay.
- Basic gesture recognition for directional mouse paths.
- Gesture list and editor in a SwiftUI settings window.
- Action binding for:
  - Keyboard shortcut simulation.
  - Opening an application.
  - Opening a URL.
  - Selected system/window actions where feasible through native APIs or
    keyboard shortcuts.
- Local JSON configuration persistence.
- Basic conflict warning for identical trigger button and gesture signature.

### Deferred

- Trackpad gesture extensions.
- AppleScript import and execution.
- Script safety scanning.
- Full `.gest` import and export.
- Complex per-application scene rules.
- Startup at login.
- Full conflict detection based on high-precision gesture similarity.
- 72-hour stability and full performance test suite.

## Architecture

### App Layer

`GestureFlowApp` is the SwiftUI app entry point. It owns shared app state and
bridges into an `AppDelegate` for AppKit-only behavior.

Responsibilities:

- Initialize core services.
- Create the settings window.
- Register the menu bar item.
- Coordinate app start, stop, and termination.

### Menu Bar Layer

`StatusBarController` manages an `NSStatusItem` and menu.

Menu items:

- Start GestureFlow or Stop GestureFlow.
- Open Settings.
- Common Gestures.
- Preferences.
- Quit.

The menu state reflects whether the gesture engine is running and whether
Accessibility permission is granted.

### Permission Layer

`PermissionService` checks Accessibility permission using
`AXIsProcessTrustedWithOptions`.

Responsibilities:

- Detect current permission state.
- Prompt users to open System Settings.
- Block gesture engine startup when permission is missing.
- Publish permission status to SwiftUI views.

### Event Layer

`MouseEventTap` wraps `CGEvent.tapCreate`.

Captured events:

- Right mouse down, dragged, and up.
- Other mouse down, dragged, and up for middle-button support when available.
- Mouse movement during an active gesture.

Responsibilities:

- Start and stop the event tap.
- Detect trigger button state.
- Collect raw points while the trigger button is held.
- Prevent accidental context menu display when a gesture is recognized.
- Forward completed point sequences to recognition.

### Gesture Engine

`GestureEngine` coordinates capture, recognition, matching, and action
execution.

Responsibilities:

- Receive raw point sequences from `MouseEventTap`.
- Normalize points using `GestureNormalizer`.
- Convert movement into a compact `GestureSignature`.
- Match the signature against enabled configured gestures.
- Send recognition success or failure to the feedback layer.
- Invoke `ActionExecutor` for matched actions.

### Recognition Layer

The MVP uses deterministic directional recognition rather than machine learning.

Pipeline:

1. Remove jitter and duplicate points.
2. Normalize bounding box and path length.
3. Segment the path by dominant direction.
4. Convert segments into direction tokens such as `U`, `D`, `L`, `R`.
5. Merge repeated adjacent tokens.
6. Compare the resulting signature with stored gesture signatures.

Examples:

- Right: `R`
- Back: `L`
- Down then right: `DR`
- Up then down: `UD`

This approach is limited but predictable, easy to test, and enough for the MVP.
More advanced template matching can be added later behind the same interface.

### Overlay Layer

`GestureOverlayWindow` is an AppKit borderless transparent window above normal
content.

Responsibilities:

- Draw the gesture trail in real time.
- Respect configurable color, width, and opacity.
- Show short success, failure, and action error messages.
- Hide automatically after gesture completion.

### Configuration UI

SwiftUI views:

- `MainSettingsView`: top-level settings layout.
- `GestureListView`: lists configured gestures.
- `GestureEditorView`: edits trigger button, gesture signature, action, and
  enabled state.
- `PermissionGuideView`: shows Accessibility setup steps.
- `FeedbackSettingsView`: edits trail appearance and notification behavior.

The UI should keep the first version practical and avoid complex custom drawing
unless needed.

### Configuration Persistence

`ConfigurationStore` reads and writes a JSON file under the user's Application
Support directory.

Suggested path:

`~/Library/Application Support/GestureFlow/config.json`

Responsibilities:

- Load configuration on startup.
- Create default gestures if no configuration exists.
- Save changes atomically.
- Validate decoded configuration and fall back safely on corruption.

### Action Layer

`ActionExecutor` executes matched actions through typed action handlers.

Action types:

- `keyboardShortcut`: posts key events through `CGEvent`.
- `openApplication`: opens an app URL or bundle identifier through
  `NSWorkspace`.
- `openURL`: opens a URL through `NSWorkspace`.
- `systemCommand`: maps selected commands to native APIs or keyboard shortcuts.

Failures should be reported to the feedback layer and logged.

## Data Model

```swift
struct AppConfiguration: Codable {
    var isEnabled: Bool
    var gestures: [GestureDefinition]
    var feedback: FeedbackConfiguration
}

struct GestureDefinition: Codable, Identifiable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var trigger: GestureTrigger
    var signature: GestureSignature
    var action: GestureAction
    var scope: GestureScope
}

enum GestureTrigger: String, Codable {
    case rightMouse
    case middleMouse
}

struct GestureSignature: Codable, Equatable {
    var tokens: [GestureDirection]
}

enum GestureDirection: String, Codable {
    case up = "U"
    case down = "D"
    case left = "L"
    case right = "R"
}

enum GestureAction: Codable {
    case keyboardShortcut(KeyboardShortcutAction)
    case openApplication(OpenApplicationAction)
    case openURL(OpenURLAction)
    case systemCommand(SystemCommandAction)
}

enum GestureScope: Codable {
    case global
}
```

`GestureScope` intentionally starts with only `global`, but remains modeled as a
separate type so per-application rules can be added later.

## Error Handling

- Missing Accessibility permission:
  - Do not start the event tap.
  - Show permission guide.
  - Keep menu state as stopped.
- Event tap creation failure:
  - Show an actionable error.
  - Suggest checking permissions or restarting the app.
- Gesture recognition failure:
  - Show a short "recognition failed" message.
  - Do not execute actions.
- Action execution failure:
  - Show "action failed, check configuration".
  - Keep the app running.
- Configuration decode failure:
  - Preserve the broken file as a backup if possible.
  - Load default configuration.
  - Notify the user in settings.

## Testing Strategy

### Unit Tests

- Gesture normalization.
- Direction segmentation.
- Signature matching.
- Conflict detection for identical triggers and signatures.
- JSON encode and decode.
- Action model validation.

### Manual Tests

- First launch without Accessibility permission.
- Permission granted after onboarding.
- Start and stop from menu bar.
- Right-button gesture capture.
- Middle-button gesture capture where hardware supports it.
- Trail overlay display and auto-hide.
- Shortcut action execution.
- Open application action execution.
- Open URL action execution.
- Corrupted configuration recovery.

### Later Tests

- Long-running CPU and memory observation.
- Multiple macOS versions.
- Multiple mouse devices.
- App notarization validation.

## Risks

- Global mouse event capture depends on Accessibility permission and can fail
  silently if the user revokes permission.
- Preventing the context menu after right-button gestures requires careful event
  suppression; accidental suppression during normal right-clicks must be avoided.
- Middle mouse support varies by device and driver.
- Some system/window actions may require keyboard shortcut simulation instead
  of direct public APIs.
- App Store distribution is not compatible with the current full global gesture
  feature set; the confirmed route is site distribution.

## Implementation Notes

- Keep the gesture recognition algorithm deterministic and testable.
- Avoid overbuilding the UI before the event capture and recognition loop works.
- Treat trackpad support as a separate future subsystem.
- Keep AppKit-specific code isolated from SwiftUI views.
- Prefer small services with explicit protocols where testability matters.

