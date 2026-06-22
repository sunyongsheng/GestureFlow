# CLAUDE.md

## Project Overview

GestureFlow is a native macOS menu-bar utility for mouse gestures. Users draw paths with right/middle mouse button to trigger keyboard shortcuts in the target application.

- **Language:** Swift (no Objective-C)
- **Frameworks:** AppKit, SwiftUI, CoreGraphics, ApplicationServices
- **Minimum macOS:** 14.0
- **Build system:** Swift Package Manager + Xcode project (`GestureFlow.xcodeproj`)
- **App type:** Background agent (`LSUIElement = true`, no Dock icon)

## Architecture

```
Sources/
├── GestureFlowCore/       # Shared library: models, recognition, matching, YAML config
└── GestureFlowApp/        # App target
    ├── App/               # Entry point, GestureFlowApplication orchestration
    ├── Engine/            # GestureEngine — gesture lifecycle
    ├── EventTap/          # CGEvent tap for mouse capture
    ├── Overlay/           # Per-screen overlay panels (trail + feedback card)
    ├── Actions/           # ActionExecutor — sends shortcuts to target app
    ├── Menu/              # StatusBarController
    ├── Settings/          # SwiftUI settings UI + window management
    └── Target/            # Under-mouse app resolution via Accessibility

Tests/
├── GestureFlowCoreTests/
└── GestureFlowAppTests/
```

## Key Design Decisions

### Overlay Rendering

- One `NSPanel` per physical screen (NOT one panel spanning all screens — macOS cannot reliably composite a single transparent window across display boundaries)
- Panels are created at init, ordered-in lazily on first gesture via `orderFrontRegardless()`
- Hidden via `alphaValue = 0` (never `orderOut`) to preserve `.canJoinAllSpaces` membership across Spaces
- Screen changes trigger full panel rebuild via `NSApplication.didChangeScreenParametersNotification`
- All overlay views draw the full gesture trail; clipping to view bounds handles cross-screen continuity
- Feedback card only appears on the screen containing the cursor

### Coordinate System

- CGEvent tap delivers Quartz coordinates (origin at top-left of main screen, Y goes down)
- Conversion to AppKit: `appKitY = mainScreenHeight - quartzY` — always use main screen height, never the containing screen's frame dimensions
- Each overlay panel converts screen points to view-local coords via `panel.convertFromScreen` + flipped view (`isFlipped = true`)

### Configuration

- YAML-based config stored in a user-configurable directory (default `~/.config/gestureflow`)
- `AppConfigurationStore` and `GestureConfigurationStore` handle persistence
- Configuration directory is relocatable at runtime

## Do NOT

These are hard-won lessons from past bugs. Violating them will re-introduce issues:

1. **Do NOT use `orderOut(nil)` on overlay panels** — use `alphaValue = 0` instead. `orderOut` causes macOS to drop `.canJoinAllSpaces` membership on background apps, breaking multi-Space display.
2. **Do NOT use a single NSPanel spanning all screens** — macOS fails to composite transparent windows across physical display boundaries. Use one panel per screen.
3. **Do NOT use per-screen frame data for Quartz↔AppKit Y conversion** — the formula `screenFrame.maxY + screenFrame.minY - quartzY` is wrong when screens have different vertical positions. Always use `mainScreenHeight - quartzY`.
4. **Do NOT call `orderFrontRegardless()` during `GestureOverlayWindow.init`** — this breaks tests that construct `GestureFlowApplication` in headless/CI environments.
5. **Do NOT use `isEnabled: true` in integration tests that create `GestureFlowApplication`** — on CI without Accessibility permission, `reconcilePersistedRunningState` will flip it to `false` and save, corrupting test expectations.
6. `**GestureFlowCore` must NOT import AppKit** — it's the platform-independent model layer.

## Building & Testing

```bash
# SPM (development & tests)
swift build
swift test

# Xcode (mirrors CI)
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlow -destination "platform=macOS" test
```

## Module Responsibilities

| Module            | Owns                                                                      | Depends On                       |
| ----------------- | ------------------------------------------------------------------------- | -------------------------------- |
| `GestureFlowCore` | GesturePoint, GestureSignature, recognition, matching, YAML config models | Yams                             |
| `GestureFlowApp`  | App lifecycle, overlay, event tap, actions, settings UI                   | GestureFlowCore, Sparkle, AppKit |

## Testing Notes

- Overlay tests use `Mirror` reflection to access private `screenOverlays` array and its `panel`/`overlayView` members
- `ConfigurationDirectoryRelocationIntegrationTests` uses `isEnabled: false` to avoid Accessibility permission dependency
- `MouseEventTapTests` inject custom `screenFramesProvider` and `desktopFrameProvider` closures for deterministic coordinates
- `swift test` (SPM) and `xcodebuild test` (Xcode) may differ — always verify both if touching project config
