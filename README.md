# GestureFlow

GestureFlow is a native macOS menu bar utility for mouse gestures. The current
MVP focuses on right-button gesture capture, gesture matching, visual feedback,
local configuration, and a small set of built-in actions.

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

Run the menu bar app from Xcode, or build and launch the packaged bundle:

```bash
Scripts/package_app.sh
open build/GestureFlow.app
```

On first launch, macOS should show a permissions guide or prompt for
Accessibility access. The app needs Accessibility permission to observe global
mouse events and trigger actions.

## Swift Package Compatibility

The repository still supports Swift Package Manager for compatibility checks:

```bash
swift build
swift test
```

These commands are no longer the primary desktop app workflow.

## Package A Local App Bundle

Create a local unsigned `.app` bundle from the Xcode project:

```bash
Scripts/package_app.sh
```

The script builds the release app and creates:

```text
build/GestureFlow.app
```

You can launch the packaged bundle with Finder or:

```bash
open build/GestureFlow.app
```

## Accessibility Setup

1. Launch GestureFlow.
2. Open `System Settings > Privacy & Security > Accessibility`.
3. Enable GestureFlow in the app list.
4. If the app does not appear yet, relaunch it and trigger the permission
   prompt again from the in-app guide.

Without Accessibility permission, gesture capture stays disabled.

## Engineering Notes

- Mouse input troubleshooting and root-cause notes:
  [mouse-input-troubleshooting.md](file:///Users/bytedance/Projects/GestureFlow/docs/mouse-input-troubleshooting.md)

## Validation

Useful local validation commands:

```bash
Scripts/validate_build_paths.sh
Scripts/package_app.sh
open build/GestureFlow.app
```

## MVP Limitations

- Packaging currently produces a local unsigned `.app` bundle only.
- Developer ID signing, notarization, and DMG distribution are not configured.
- Trackpad gesture support is deferred; the MVP focuses on mouse gestures.
- Action coverage is intentionally limited to built-in shortcuts, app launch,
  URL open, and a small set of system commands.
- Some behaviors still depend on macOS permission state and current hardware.
