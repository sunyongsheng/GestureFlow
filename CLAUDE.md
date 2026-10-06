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
├── GestureFlowCore/       # Platform-independent model layer (no AppKit)
│   ├── Models/            # AppConfiguration, GestureDefinition, GestureConfiguration, …
│   ├── Configuration/     # Config directory resolution/relocation, YAML stores, built-in gesture seeds
│   ├── Recognition/       # Mouse points → direction-token GestureSignature
│   ├── Matching/          # GestureMatcher — exact/prefix match, app-specific over global
│   ├── Validation/        # ConflictDetector
│   └── Target/            # GestureTargetResolving protocol
└── GestureFlowApp/        # App target
    ├── App/               # @main SwiftUI shell, AppDelegate, GestureFlowApplication (composition root)
    ├── EventTap/          # MouseEventTap — CGEvent tap for right/middle mouse capture
    ├── Engine/            # GestureEngine — gesture lifecycle: recognize → match → execute → feedback
    ├── Target/            # Target app resolution (foreground / under mouse) and ignored-app gate
    ├── Actions/           # ActionExecutor — activates the target app and posts shortcuts
    ├── Overlay/           # Per-screen overlay panels (trail + feedback card)
    ├── Menu/              # StatusBarController
    ├── Permissions/       # Accessibility trust checks and prompts
    ├── Services/          # Gesture config merge/save, launch at login, Sparkle updates
    ├── Localization/      # L10nKey, per-language string tables, LocalizationManager
    └── Settings/          # SwiftUI settings: General/Advanced/Gestures/About slices + Window/ plumbing

Tests/
├── GestureFlowCoreTests/
└── GestureFlowAppTests/   # Roughly mirrors the Sources/GestureFlowApp layout
```

### Runtime Flow

1. `MouseEventTap` receives right/middle mouse events and converts them to AppKit coordinates. On press it asks `GestureActivationGate` whether to track the press; `nil` (an ignored app) lets the event pass through untouched. The target app (`gestureTargetApplication`: foreground or under mouse) resolves lazily when the press becomes a gesture, or at press time when the ignore list needs it.
2. Right button: the press is suppressed and held as a pending click. It becomes a gesture once the path exceeds `trigger.movementThreshold`; if it is released earlier or held past `holdTimeoutMilliseconds`, a synthetic right click is replayed so context menus keep working. Middle-button events pass through while being tracked.
3. `GestureEngine` (main thread) updates the overlay on every sample with the live prefix match (`IncrementalGestureRecognizer`), and after the release's tap callback returns runs `GestureRecognizer` → `GestureMatcher` (exact match; an app-specific gesture beats a global one) → `ActionExecutor`.
4. `ActionExecutor` posts the shortcut with `CGEvent.postToPid` right away when the target or its helper process is frontmost; otherwise it requests activation and, once the target is active (or after 0.5 s), raises the window under the gesture origin and posts. Failures surface as typed `GestureOverlayCompletion` cases on the feedback card.

The target is resolved once, before the overlay appears, and reused at release.

## Key Design Decisions

### Overlay Rendering

- One `NSPanel` per physical screen (NOT one panel spanning all screens — macOS cannot reliably composite a single transparent window across display boundaries)
- Panels are created at init, ordered-in lazily on first gesture via `orderFrontRegardless()`
- Hidden via `alphaValue = 0` (never `orderOut`) to preserve `.canJoinAllSpaces` membership across Spaces
- Screen changes trigger full panel rebuild via `NSApplication.didChangeScreenParametersNotification`
- All overlay views draw the full gesture trail; clipping to view bounds handles cross-screen continuity
- Feedback card only appears on the screen containing the cursor
- Overlay panels are non-activating and never become key, so anything that follows key-window / active-app state (system materials, focus styling) renders in its inactive appearance there
- The trail and the timeout marker are non-animating `CAShapeLayer`s in `GestureTrailView`, below the feedback card; the render server rasterizes them, so no overlay view keeps a backing store
- Overlay updates run on every mouse sample: appended points are rendered once per display refresh through the overlay view's display link, while begin, marker and reset changes apply immediately; the feedback card's `show` is called per sample and must stay cheap when nothing changed

### Coordinate System

- CGEvent tap delivers Quartz coordinates (origin at top-left of main screen, Y goes down)
- Conversion to AppKit: `appKitY = mainScreenHeight - quartzY` — always use main screen height, never the containing screen's frame dimensions
- Each overlay panel converts screen points to view-local coords via `panel.convertFromScreen` + flipped view (`isFlipped = true`)

### Event Tap

- The tap callback runs on the main thread and holds the system's mouse events until it returns: keep per-event work cheap and run anything slow (activation, LaunchServices, Accessibility) after it returns. Accessibility calls are capped by `AccessibilityMessaging.applyTimeout()`
- Synthetic mouse events are tagged with `syntheticEventSignature` in `eventSourceUserData` and the tap passes tagged events through; tag any mouse event GestureFlow posts the same way or the tap intercepts it
- When macOS disables the tap (`tapDisabledByTimeout` / `tapDisabledByUserInput`, e.g. across sleep/wake), the in-flight gesture is cancelled, the held button released, and the tap re-enabled

### Configuration

- YAML-based config stored in a user-configurable directory (default `~/.config/gestureflow`) holding `config.yaml` (`AppConfiguration`), `gestures-builtin.yaml` (seeded from `BuiltInGestureSeeds`) and `gestures-custom.yaml` (user gestures)
- `AppConfigurationStore` persists `config.yaml`; `GestureConfigurationService` merges the two gesture files, tagging each `GestureDefinition.source`, and splits them back by `source` on save (custom gestures reusing a built-in ID are reported as conflicts)
- Configuration directory is relocatable at runtime
- Runtime components read settings through provider closures (`{ runtimeState.appConfiguration }`), so saved settings apply without restarting the engine
- New config fields decode with `decodeIfPresent(...) ?? Self.default.<field>` so existing user files keep loading
- App language is stored in `UserDefaults` (`AppleLanguages`), not in the YAML config

### Settings Window

- Hosted by a value-bound `WindowGroup` (not SwiftUI's `Settings` scene) so reopening brings the existing window forward
- The app runs as `.accessory`; `AppPresentationController` switches it to `.regular` while settings are visible and back to `.accessory` after the last settings window closes
- All presentation paths — cold launch, menu bar / Settings command, silent launch at login — go through `SettingsPresentationFlow`; app activation is owned by the key-focus claim in `SettingsWindowFrontmostPresenter`
- One `SettingsViewModel` backs every section; its side effects (save, start/stop, relocate, …) are closures injected by `GestureFlowApplication`. Shared card/row components live in `Settings/SettingsSidebarModels.swift`

### Localization

- User-facing strings go through `LocalizationManager` (`string(_:)` / `format(_:_:)`) keyed by `L10nKey`, with one in-code table per language in `Localization/Tables/`
- Localized strings don't end with a period
- Built-in gestures are displayed by their localized name unless the user stored a custom name

## Do NOT

These are hard-won lessons from past bugs. Violating them will re-introduce issues:

1. **Do NOT use `orderOut(nil)` on overlay panels** — use `alphaValue = 0` instead. `orderOut` causes macOS to drop `.canJoinAllSpaces` membership on background apps, breaking multi-Space display.
2. **Do NOT use a single NSPanel spanning all screens** — macOS fails to composite transparent windows across physical display boundaries. Use one panel per screen.
3. **Do NOT use per-screen frame data for Quartz↔AppKit Y conversion** — the formula `screenFrame.maxY + screenFrame.minY - quartzY` is wrong when screens have different vertical positions. Always use `mainScreenHeight - quartzY`.
4. **Do NOT call `orderFrontRegardless()` during `GestureOverlayWindow.init`** — this breaks tests that construct `GestureFlowApplication` in headless/CI environments.
5. **Do NOT use `isEnabled: true` in integration tests that create `GestureFlowApplication`** — on CI without Accessibility permission, `reconcilePersistedRunningState` will flip it to `false` and save, corrupting test expectations.
6. **`GestureFlowCore` must NOT import AppKit** — it's the platform-independent model layer.
7. **Do NOT make overlay panels key or activate the app from overlay code** — the app receiving the gesture would lose keyboard focus.
8. **Do NOT add extra `NSApp.activate` / force-activation calls when presenting settings** — activation is owned by the single key-focus claim in `SettingsWindowFrontmostPresenter`; other paths only order the window so the app is activated once per open.
9. **Do NOT drop the synthetic button-up in `MouseEventTap`** (after consumed gestures and tap-disabled recovery) — macOS then thinks the right button is still held and left clicks act as right clicks.
10. **Do NOT block or spin a nested run loop inside the event tap callback** (e.g. waiting for app activation) — the system's mouse events stall until it returns; wait asynchronously instead.
11. **Do NOT implement `draw(_:)` in the full-screen overlay views** (`GestureOverlayView`, `GestureTrailView`) — a self-drawing full-screen view gets screen-sized backing stores (about 300 MB per 2x screen at peak) and every mouse sample then waits milliseconds in the Core Animation commit. Use non-animating shape layers instead.

## Mandatory Maintenance

- **When adding a new configuration item** to `AppConfiguration` (or its nested structs in `AppConfiguration.swift`), you **must** update the configuration table in both `README.md` and `README.en.md` to document the new field's YAML path, type, default value, description, and which settings page exposes it.
- **README files come in pairs** — `README.md` (Chinese) and `README.en.md` (English). Any content change must be applied to both files.
- **When adding a source or test file**, also register it in `GestureFlow.xcodeproj/project.pbxproj`. The Xcode project lists files explicitly while SwiftPM picks them up automatically, so a missing entry only breaks the Xcode/CI build. `Scripts/validate_xcode_and_spm.sh` builds and tests both.
- **When adding a user-facing string**, add the `L10nKey` case and an entry in every `Localization/Tables/L10nStrings*.swift` table (`L10nTablesCompletenessTests` fails otherwise).
- **Releases** follow `.claude/skills/release-gestureflow` (version bump, CHANGELOG drafted for user confirmation, `release/vX.Y.Z` tag).

## Building & Testing

```bash
# SPM (development & tests)
swift build
swift test

# Xcode (mirrors CI)
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlow -destination "platform=macOS" test
```

- CI (`.github/workflows/release.yml`) runs only for `release/v*` tags, on `macos-26` with the Xcode 26 SDK: `xcodebuild test`, then signing and packaging. Pushes to `main` run no checks.
- The local Xcode can be newer than CI's. APIs missing from the Xcode 26 SDK break the CI build even behind `#available`, and a newer SDK can change framework behavior that tests observe.
- Debug builds are ad-hoc signed (`Config/GestureFlowApp-Debug.xcconfig`); a stable signing identity can go in the gitignored `Config/Local.xcconfig` (created by `Scripts/setup_local_xcconfig.sh`).

## Module Responsibilities

| Module            | Owns                                                                      | Depends On                       |
| ----------------- | ------------------------------------------------------------------------- | -------------------------------- |
| `GestureFlowCore` | GesturePoint, GestureSignature, recognition, matching, YAML config models | Yams                             |
| `GestureFlowApp`  | App lifecycle, overlay, event tap, actions, settings UI                   | GestureFlowCore, Sparkle, AppKit |

## Testing Notes

- Overlay tests use `Mirror` reflection to access private `screenOverlays` array and its `panel`/`overlayView` members, and the overlay view's `trailView`/`feedbackCardView`
- Don't test implicit layer animations through `action(forKey:)`: it returns nil for standalone layers even for properties that do animate. Change the state for real and assert that `animationKeys()` is empty
- `ConfigurationDirectoryRelocationIntegrationTests` uses `isEnabled: false` to avoid Accessibility permission dependency
- `MouseEventTapTests` inject custom `screenFramesProvider` and `desktopFrameProvider` closures for deterministic coordinates
- `swift test` (SPM) and `xcodebuild test` (Xcode) may differ — always verify both if touching project config
- Components take protocol/closure dependencies with production defaults; tests inject fakes instead of touching the real event tap, window server, file system or `UserDefaults`
- `NSWindow.isVisible` is unreliable on headless CI — assert on spied calls (e.g. `close()` counts) instead
- `MemoryFootprintProbeTests` is an opt-in diagnostic (`GESTUREFLOW_MEMORY_PROBE=1 swift test --filter MemoryFootprintProbeTests`) that shows real overlay and settings windows and prints the process footprint around them; it is skipped otherwise
- Don't assert synthesized property-wrapper storage names via `Mirror`: `@State` stores `_name: State<T>` in older SDKs but is a macro storing `__name: LazyState<T>` in the macOS 27 SDK. Match on the stored type instead
