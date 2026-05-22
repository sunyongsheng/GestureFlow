# Settings Sidebar Redesign Design

**Goal**

Redesign the current GestureFlow settings window into a macOS-style two-column settings experience:

- Left side provides stable top-level navigation.
- Right side renders the selected section content.
- General settings surface core app controls.
- Interface settings present existing Trigger and Feedback controls with a cleaner, more modern visual structure.
- Gestures continue to use the current editor and list experience for now.
- About shows application version information.

**Scope**

- Rework only the internal SwiftUI settings content.
- Keep the existing SwiftUI `Settings` scene and window lifecycle architecture unchanged.
- Reuse existing configuration editing logic in `SettingsViewModel`.
- Add app-level actions to `SettingsViewModel` by dependency injection from `GestureFlowApplication`.
- Use placeholder alerts for features that do not exist yet.

**Out Of Scope**

- Do not replace the `Settings` scene with a custom `WindowGroup`.
- Do not redesign the gesture editor interaction model in this task.
- Do not implement real login-item registration in this task.
- Do not change activation-policy handling or settings-window presentation flow.

## Architecture

### Navigation Model

Introduce a lightweight `SettingsSection` enum inside the settings UI layer:

- `general`
- `appearance`
- `gestures`
- `about`

`MainSettingsView` owns the selected section state and renders:

- A fixed-width left navigation rail.
- A flexible right detail pane.

This keeps the routing local to the view layer and avoids unnecessary changes to `SettingsSceneBridge`, `SettingsSceneRoot`, or app presentation code.

### View Model Responsibilities

`SettingsViewModel` remains the shared state container for settings and runtime state, but it gains injected actions for app-shell operations:

- Toggle gesture recognition on and off.
- Request Accessibility permission.
- Quit the application.
- Show a placeholder for launch-at-login.

The SwiftUI views call these closures through named methods on the view model. This keeps business logic out of the view hierarchy and matches the existing coordinator-style architecture.

### App Coordination

`GestureFlowApplication` remains the only place that knows how to:

- Start and stop the gesture engine.
- Request Accessibility permission.
- Terminate the process.
- Present placeholder alerts for unimplemented actions.

When constructing `SettingsViewModel`, it injects closures that map UI interactions back to app-coordinated behavior.

## UI Structure

### General

The General page contains four controls:

1. `Open at login`
   - Rendered as a toggle row.
   - Current task uses placeholder behavior because the project has no login-item implementation yet.
   - User interaction shows a placeholder alert and does not persist state.

2. `Gesture recognition`
   - Rendered as a real toggle.
   - Reflects current running state from `SettingsViewModel.isRunning`.
   - Toggling on calls the app-coordinated start path.
   - Toggling off calls the app-coordinated stop path.

3. `Accessibility`
   - Rendered as a full-width action button with status text.
   - When permission is missing, the button is enabled and requests permission.
   - When permission is granted, the button is disabled and the text uses the existing green success color convention.

4. `Quit Application`
   - Rendered as a destructive-styled button.
   - Calls the existing full-exit path.

### Appearance

The Appearance page reuses existing Trigger and Feedback configuration logic but changes layout into polished settings cards:

- Trigger card
  - Movement threshold
  - Hold timeout
  - Sample jump threshold
- Feedback card
  - Trail color
  - Trail width
  - Trail opacity

Cards use clearer hierarchy, value labels, secondary explanatory text, and more generous spacing to better match macOS settings expectations.

### Gestures

The Gestures page wraps the current gesture list and editor experience in the new detail-pane layout.

No behavioral changes are required in this task. The goal is to preserve current functionality while allowing a future redesign without changing the new sidebar shell.

### About

The About page shows:

- App name
- Version
- Build number when available

Version data should come from the app bundle so it stays accurate in packaged builds.

## Rejected Approaches

- Use `NavigationSplitView`.
  - Rejected because the page set is small and fixed, and a custom split layout gives tighter control over macOS settings styling without introducing selection-management complexity that is unnecessary here.

- Push app-shell behavior directly into SwiftUI views.
  - Rejected because start/stop/quit/permission flows belong in `GestureFlowApplication`, not in view code.

- Implement real launch-at-login as part of this redesign.
  - Rejected because the repository currently has no login-item infrastructure, and adding it would expand the task beyond a UI redesign.

## Testing

- `SettingsViewModelTests`
  - Starting gesture recognition delegates to the injected action.
  - Stopping gesture recognition delegates to the injected action.
  - Quit delegates to the injected action.
  - Launch-at-login placeholder delegates to the injected action.

- `GestureFlowApplicationTests`
  - Settings view model can start GestureFlow through the injected toggle action.
  - Settings view model can stop GestureFlow through the injected toggle action.
  - Settings view model can quit the app through the injected action.

- Diagnostics
  - Check edited Swift files for new diagnostics after implementation.

## Acceptance Criteria

- The settings window uses a left navigation column and right detail pane.
- Left navigation exposes `通用`, `界面`, `手势`, and `关于`.
- `通用` contains the requested four controls.
- `手势识别` is a real toggle tied to the running engine state.
- `Accessibility` is enabled only when permission is missing and shows a success style when permission is granted.
- `界面` reuses Trigger and Feedback functionality with updated styling.
- `手势` keeps current behavior.
- `关于` shows version information.
- Missing features use placeholder alerts instead of silent no-ops.
