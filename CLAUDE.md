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

1. `MouseEventTap` receives right/middle mouse events and converts them to AppKit coordinates. On press it asks `GestureActivationGate` for the target app (`gestureTargetApplication`: foreground or under mouse); `nil` (an ignored app) lets the event pass through untouched.
2. Right button: the press is suppressed and held as a pending click. It becomes a gesture once the path exceeds `trigger.movementThreshold`; if it is released earlier or held past `holdTimeoutMilliseconds`, a synthetic right click is replayed so context menus keep working. Middle-button events pass through while being tracked.
3. `GestureEngine` (main thread) updates the overlay on every sample with the live prefix match, and on release runs `GestureRecognizer` → `GestureMatcher` (exact match; an app-specific gesture beats a global one) → `ActionExecutor`.
4. `ActionExecutor` activates the target and raises the window under the gesture origin (skipped when the target or its helper process is already frontmost), then posts the shortcut with `CGEvent.postToPid`. Failures surface as typed `GestureOverlayCompletion` cases on the feedback card.

The target is resolved once at press time (before the overlay appears) and reused at release.

## Key Design Decisions

### Overlay Rendering

- One `NSPanel` per physical screen (NOT one panel spanning all screens — macOS cannot reliably composite a single transparent window across display boundaries)
- Panels are created at init, ordered-in lazily on first gesture via `orderFrontRegardless()`
- Hidden via `alphaValue = 0` (never `orderOut`) to preserve `.canJoinAllSpaces` membership across Spaces
- Screen changes trigger full panel rebuild via `NSApplication.didChangeScreenParametersNotification`
- All overlay views draw the full gesture trail; clipping to view bounds handles cross-screen continuity
- Feedback card only appears on the screen containing the cursor
- Overlay panels are non-activating and never become key, so anything that follows key-window / active-app state (system materials, focus styling) renders in its inactive appearance there
- Overlay updates run on every mouse sample: keep them incremental (the trail invalidates only the new segment; the feedback card's `show` is called per sample and must stay cheap when nothing changed)

### Coordinate System

- CGEvent tap delivers Quartz coordinates (origin at top-left of main screen, Y goes down)
- Conversion to AppKit: `appKitY = mainScreenHeight - quartzY` — always use main screen height, never the containing screen's frame dimensions
- Each overlay panel converts screen points to view-local coords via `panel.convertFromScreen` + flipped view (`isFlipped = true`)

### Event Tap

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

- Overlay tests use `Mirror` reflection to access private `screenOverlays` array and its `panel`/`overlayView` members
- `ConfigurationDirectoryRelocationIntegrationTests` uses `isEnabled: false` to avoid Accessibility permission dependency
- `MouseEventTapTests` inject custom `screenFramesProvider` and `desktopFrameProvider` closures for deterministic coordinates
- `swift test` (SPM) and `xcodebuild test` (Xcode) may differ — always verify both if touching project config
- Components take protocol/closure dependencies with production defaults; tests inject fakes instead of touching the real event tap, window server, file system or `UserDefaults`
- `NSWindow.isVisible` is unreliable on headless CI — assert on spied calls (e.g. `close()` counts) instead
- Don't assert synthesized property-wrapper storage names via `Mirror`: `@State` stores `_name: State<T>` in older SDKs but is a macro storing `__name: LazyState<T>` in the macOS 27 SDK. Match on the stored type instead
