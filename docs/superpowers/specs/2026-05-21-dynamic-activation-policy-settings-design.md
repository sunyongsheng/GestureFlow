# Dynamic Activation Policy Settings Design

**Goal**

Make the app behave like two apps visually while remaining a single process and a single bundle:
- The menu bar app always stays alive.
- Opening Preferences promotes the app to a Dock-visible foreground app and shows the settings UI.
- Closing the last settings window hides the Dock presence and returns the app to accessory mode without stopping gesture recognition.
- Quitting from the menu bar terminates the whole process.

**Constraints**

- The implementation must use AppKit's official activation-policy APIs.
- The app remains a single process and a single bundle.
- Gesture recognition must continue running after the settings window closes.
- Returning from foreground mode to accessory mode must feel immediate to the user, but the policy switch itself must occur on the next main-run-loop turn rather than synchronously inside the window-close callback.
- Activation-policy changes must be centralized; window delegates and view code must not toggle policy directly.

## Architecture

### AppPresentationController

Add an `AppPresentationController` that owns app-shell presentation state and is the single place allowed to call `NSApplication.setActivationPolicy(_:)`.

Responsibilities:
- Promote the app from `.accessory` to `.regular` before the settings UI is opened.
- Activate the app once it becomes `.regular` so the settings UI behaves like a Dock app.
- Track whether a settings window is currently presented.
- When the last settings window closes, schedule a next-turn transition back to `.accessory`.
- Ignore duplicate open/close events so repeated menu clicks or re-entrant callbacks do not cause policy churn.

This controller is presentation-only. It does not know about gesture recognition, configuration persistence, or settings form data.

### GestureFlowApplication

`GestureFlowApplication` remains the business coordinator.

Responsibilities:
- Start and stop gesture recognition.
- Maintain menu bar actions.
- Build and reuse the single `SettingsViewModel`.
- Route "open settings" requests through an injected presentation callback that first promotes the app and then opens the settings scene.
- Keep "Quit" as the single process-wide termination path.

It no longer decides whether the app is a Dock app or a menu bar app at any given moment.

### SwiftUI Settings Scene

Keep the current SwiftUI `Settings` scene stack:
- `SettingsSceneRoot`
- `SettingsSceneBridge`
- `SettingsSceneOpenDriver`

New behavior:
- Opening settings first requests foreground presentation through `AppPresentationController`.
- The settings scene reports lifecycle events back to the presentation layer so the app can return to accessory mode after the last settings window closes.

The SwiftUI scene remains the UI surface. Activation-policy switching does not live in SwiftUI views.

## State Model

Use a small presentation state machine:

- `accessoryBackground`
  - Menu bar app alive
  - No Dock presence
  - No visible settings window

- `promotingToForeground`
  - Transition state entered when Preferences is requested
  - App policy is moving toward `.regular`
  - Settings scene open is about to be triggered

- `foregroundSettingsVisible`
  - Dock icon visible
  - Settings window visible
  - Menu bar still active

- `returningToAccessory`
  - Last settings window has closed
  - A next-turn task is scheduled to switch back to `.accessory`
  - If settings reopens before the scheduled fallback executes, cancel the fallback

## Event Flow

### App Launch

1. App starts in accessory/menu-bar mode.
2. Menu bar controller is created.
3. Coordinator requests opening settings on launch.
4. Presentation controller promotes the app to `.regular`.
5. Settings scene is opened.
6. Dock icon appears and settings acts like a normal foreground app window.

### Preferences Menu Action

1. Menu bar item triggers `openSettings`.
2. Coordinator reuses the existing `SettingsViewModel`.
3. Presentation controller ensures `.regular`.
4. Settings scene is opened or brought to front.

### Closing Settings

1. The last settings window closes.
2. The presentation layer is notified.
3. A main-queue-next-turn task switches the app back to `.accessory`.
4. Dock presence disappears.
5. Menu bar app remains active.
6. Gesture recognition keeps running if already started.

### Quit

1. Menu bar Quit action calls the existing unified quit path.
2. Gesture recognition stops.
3. The entire process terminates.
4. Both the menu bar presence and the Dock-facing settings UI disappear together.

## Implementation Boundaries

### New Types

- `AppPresentationController`
  - Owns activation-policy changes
  - Owns pending fallback scheduling
  - Exposes methods like:
    - `prepareToShowSettings()`
    - `handleSettingsWindowDidClose()`
    - `cancelPendingAccessoryFallbackIfNeeded()`

- `SettingsWindowObservation`
  - A thin observation hook that reports when a settings window appears and when the last one closes.
  - It may be implemented using AppKit notifications rather than a custom `NSWindowController`.

### Modified Types

- `AppDelegate`
  - Creates and wires a shared `AppPresentationController`
  - Default `showSettings` wiring becomes:
    1. foreground promotion
    2. bridge install
    3. settings scene open

- `GestureFlowShellApp`
  - Keeps the SwiftUI `Settings` scene
  - Attaches lifecycle observation needed by presentation control

- `GestureFlowApplication`
  - Keeps business logic
  - Uses injected presentation-aware settings callback

## Rejected Approaches

- Direct synchronous fallback to `.accessory` inside `windowWillClose`
  - Rejected because previous evidence in this codebase shows this is the most crash-prone timing.

- Returning to the old `NSPanel` implementation
  - Rejected because it breaks the new goal of showing a Dock-visible foreground app experience.

- Splitting into two separate processes
  - Rejected because the approved scope is a single process and single bundle.

## Testing

### Unit Tests

- `AppPresentationControllerTests`
  - opening settings from accessory requests `.regular`
  - repeated open requests do not duplicate state transitions
  - closing the last window schedules accessory fallback
  - reopening before fallback cancels the fallback

### Coordinator Tests

- `GestureFlowApplicationTests`
  - Preferences path promotes app then opens settings
  - closing settings does not stop gesture recognition
  - Quit still stops gesture recognition and terminates

### Runtime Verification

- Launch shows menu bar plus Dock-visible settings UI
- Closing settings removes Dock presence while leaving menu bar alive
- Gesture recognition continues after settings closes
- Reopening settings from menu bar restores Dock-visible foreground behavior
- Quit removes both presences

## Acceptance Criteria

- The app remains one process and one bundle.
- Users see a Dock app only while settings is foregrounded.
- Closing the last settings window returns to menu-bar-only mode without quitting gesture recognition.
- Preferences from the menu bar always restores the Dock-visible settings experience.
- Quit always terminates the entire app.
