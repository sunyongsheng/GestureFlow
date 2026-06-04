# GestureFlow

[简体中文 README](README.md)

GestureFlow is a native macOS mouse gesture utility. Hold a mouse
button, draw a path, and trigger shortcuts or actions in the app you are using.

## Features

### Mouse gestures

- Trigger gestures with the **right** or **middle** mouse button
- Draw single- or multi-segment paths (up, down, left, right)

### Gesture library

- **Global** gestures that work everywhere, plus **per-app** sets for registered
  applications
- Built-in presets for common shortcuts: back/forward, copy/paste, find, new tab,
  refresh, minimize, undo/redo, and more
- Configure **app-specific gestures** for each application
- Create **custom gestures**: record a path on the canvas and bind a keyboard
  shortcut

### Visual feedback

- Live **gesture trail** overlay while drawing
- Customize trail color, width, opacity, and stroke
- Optional on-screen **feedback card** when a gesture is recognized

### Advanced tuning

- Adjust movement threshold, hold timeout, and sample distance
- Send actions to the **foreground app** or the **app under the cursor**
- **Ignore applications** where gestures should not activate

### Settings & configuration

- **Launch at login** and a global gesture recognition toggle
- **Custom configuration directory** for syncing settings across machines
  (including XDG `~/.config/gestureflow`)
- **Multilingual support**

## Requirements

- macOS 14.0 or later
- Xcode 26 or newer
- Swift 5.9 toolchain

## Project Structure

- `GestureFlowCore`: shared gesture models, recognition, matching, validation,
  and configuration storage
- `GestureFlowApp`: macOS menu bar application, permissions flow, event tap,
  overlay, settings, and action execution

## Open In Xcode

Open the standard macOS app project:

```bash
open GestureFlow.xcodeproj
```

Primary local workflow:

- Run the `GestureFlowApp` scheme from Xcode
- Test from Xcode's Test action
- Use `xcodebuild` for command-line validation

## Build

Build the app with Xcode:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
```

## Run

Run the app from Xcode, or build and launch the packaged bundle:

```bash
Scripts/package_app.sh
open build/GestureFlow.app
```

On first launch, macOS should show a permissions guide or prompt for
Accessibility access. The app needs Accessibility permission to observe global
mouse events and trigger actions.
