# Settings Window Architecture Evaluation Draft

> **For agentic workers:** This is an architecture evaluation draft, not an implementation checklist. Use it to choose the next spike before touching production behavior.

**Goal:** Evaluate stable ways for a menu bar app to present a settings surface that reliably receives focus, without reintroducing the activation-policy crashes that were already eliminated.

**Current Architecture:** `GestureFlow` runs as an `LSUIElement` menu bar app. `main.swift` installs a thin `AppDelegate`, which creates `GestureFlowApplication`; settings are opened from the status bar action path and rendered through `SettingsWindowController`, which owns a reusable `NSPanel` hosting `MainSettingsView`.

**Tech Stack:** Swift, AppKit, SwiftUI, XCTest

***

## Problem Statement

The current settings surface is visible but not reliably focused when opened from the menu bar app shell. Multiple timing and activation experiments have failed to make the app observably active during the settings presentation path. The issue is no longer well-described as a first-launch timing bug; it appears to be a mismatch between the current `LSUIElement` app shell and the chosen settings-window presentation model.

## Current State

### Runtime shape

- `Resources/Info.plist` sets `LSUIElement=true`, so the app behaves as a menu bar agent with no normal Dock presence.
- `Sources/GestureFlowApp/App/main.swift` only boots `NSApplication`, installs `AppDelegate`, and starts the event loop.
- `Sources/GestureFlowApp/App/AppDelegate.swift` is intentionally thin and forwards launch completion into `GestureFlowApplication`.
- `Sources/GestureFlowApp/App/GestureFlowApplication.swift` owns the application coordinator role: status item, permission prompts, gesture runtime state, settings view-model creation, and menu actions.
- `Sources/GestureFlowApp/Menu/StatusBarController.swift` routes the `Preferences` item into `actions.openSettings()`.
- `Sources/GestureFlowApp/Settings/SettingsWindowController.swift` owns a reusable `NSPanel`, explicit size stabilization, and recreate-on-close behavior.
- `Sources/GestureFlowApp/Settings/SettingsViewModel.swift` keeps business logic injected as closures from the coordinator, which cleanly synchronizes settings UI with application state.

### Proven constraints

- Dynamic `NSApplication.ActivationPolicy` switching is not an option. It previously caused `CA::Transaction` / window-close instability and is already a documented project constraint.
- The settings surface currently depends on `NSPanel` behavior, explicit `contentMinSize`, and first-show size stabilization to avoid collapsing layouts.
- Closing the settings surface must continue to clear cached window state and allow a clean rebuild on the next open.
- Menu actions must remain custom-selector based and scheduled asynchronously so the status item menu can close before any window work begins.
- The current MVVM-style closure injection from `GestureFlowApplication` into `SettingsViewModel` is a good design boundary and should be preserved unless there is a compelling reason to replace it.

## What Has Already Been Ruled Out

The following experiments have already failed and should not be treated as promising next steps:

- Delaying only the first auto-open until after launch.
- Pre-activating the app, then presenting the panel on the next run loop.
- Reordering `orderFrontRegardless()`, `makeKeyAndOrderFront(nil)`, and activation calls.
- Chaining stronger activation requests inside the current path:
  - `NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])`
  - `NSApp.activate(ignoringOtherApps: true)`
  - `NSApp.activate()`
  - `NSApp.unhide(nil)`
- Treating the issue as a missing first responder assignment.

The debug record in `debug-settings-focus-retry.md` shows a consistent pattern: the panel becomes visible, but the app does not exhibit an observable `active` transition during the presentation window, and the panel remains visible-but-not-key.

## Evaluation Criteria

Any replacement architecture should be judged against the same criteria:

1. **Focus reliability**
   - Opening settings should result in a surface that is immediately interactive without requiring an extra click.
2. **Crash safety**
   - The design must not depend on dynamic activation-policy flips.
3. **State continuity**
   - The settings UI must continue to reflect gesture-engine state, permission status, and configuration changes through the existing coordinator/view-model boundary.
4. **Lifecycle clarity**
   - The chosen model should make it obvious when the settings UI is created, shown, hidden, and rebuilt.
5. **Testability**
   - The solution should remain compatible with focused XCTest coverage and not force all verification into manual testing.

## Candidate Routes

### Route 1: Move to a System-Managed Settings Window Model

**Summary**

Adopt a more system-native settings presentation model instead of directly owning an AppKit floating panel. The goal is to let the system own more of the activation and focus semantics.

**What would likely change**

- `main.swift` / `AppDelegate.swift`: may need to move toward a shell that can cooperate with a system-managed settings entry point.
- `GestureFlowApplication.swift`: remains the coordinator, but settings opening becomes an adapter call rather than direct `SettingsWindowController.show(...)`.
- `SettingsWindowController.swift`: likely shrinks substantially or is replaced by a thinner bridge.
- Tests around settings presentation would move away from `NSPanel` internals and toward launch/open orchestration.

**Pros**

- Best semantic match for a "settings window" concept.
- Highest chance of aligning focus behavior with platform expectations.
- Reduces custom activation choreography in production code.

**Cons**

- Compatibility with an `LSUIElement`-style app shell must be validated before committing.
- Likely requires the biggest shell/lifecycle refactor of the options listed here.
- Existing `NSPanel`-specific tests and assumptions would need to be revisited.

**Risk level**

- Medium to high.

**Best when**

- You want a desktop-grade settings experience and are willing to pay some architecture cost to get native semantics.

### Route 2: Split Settings into a Separate Regular-Focus Host

**Summary**

Keep the menu bar agent lightweight, but host settings in a more conventional focus-capable surface that is decoupled from the current agent window path. This could be a separate host component, window subsystem, or target-level split.

**What would likely change**

- `GestureFlowApplication.swift`: becomes responsible for delegating "open settings" to a separate host boundary instead of presenting directly.
- New abstraction for state sharing or command forwarding between the menu bar runtime and the settings host.
- `SettingsViewModel.swift` can likely stay, but the place where closures are bound would move.

**Pros**

- Strongest path if "immediate focus" is non-negotiable and the current agent shell fundamentally resists it.
- Keeps the menu bar runtime small and focused.
- Makes focus ownership explicit instead of trying to coax it out of the agent shell.

**Cons**

- Largest implementation scope.
- Introduces coordination complexity, and possibly lifecycle or data-flow duplication.
- Raises packaging, launch, and testing complexity.

**Risk level**

- High.

**Best when**

- Reliable focus is mandatory and Route 1 turns out to be incompatible with the menu bar agent shell.

### Route 3: Replace the Window with a Menu-Bar-Native Presentation Model

**Summary**

Stop trying to make the current settings UI behave like a regular desktop window. Instead, redesign the settings interaction around a menu-bar-native surface, such as a popover or staged menu-adjacent workflow, where activation expectations are different.

**What would likely change**

- `StatusBarController.swift`: would become more central because the settings surface would be anchored to the status item interaction model.
- `SettingsWindowController.swift`: likely replaced by a popover or menu-adjacent presenter.
- `MainSettingsView.swift`: likely split into smaller sections because the current 700px-wide form is not naturally suited to popover dimensions.

**Pros**

- Aligns with menu bar app UX instead of fighting it.
- May avoid the need for app-wide activation altogether.
- Keeps the app shell simple.

**Cons**

- Biggest UX change relative to the current product.
- The current settings content is too large for a direct one-to-one swap.
- May require a meaningful redesign of the settings information architecture.

**Risk level**

- Medium.

**Best when**

- You are open to changing the UX model, not just fixing the current window.

## Rejected Non-Option

### Dynamic Activation Policy Switching

This should remain off the table. Prior work already showed that toggling between `.accessory` and `.regular` reintroduced low-level close-time instability. Even if it appears tempting as a brute-force focus fix, it conflicts with project memory and would reopen a crash class that has already been retired.

## Recommendation

### Recommended order of investigation

1. **Do a feasibility spike for Route 1**
   - Confirm whether a system-managed settings entry point can coexist with the current menu bar architecture and `LSUIElement` configuration.
   - Success condition: we can preserve `GestureFlowApplication` as coordinator while handing off focus semantics to a system-owned settings surface.
2. **If Route 1 is not compatible, choose between Route 2 and Route 3 based on UX priorities**
   - If immediate focus and a desktop-style settings window matter most, prefer Route 2.
   - If preserving the lightweight menu bar mental model matters most, prefer Route 3.

### Why Route 1 is the first spike

- It offers the best chance of recovering native focus behavior without introducing the complexity of a split-host architecture.
- It preserves the current MVVM-style coordinator boundary more naturally than Route 2.
- It changes less product UX than Route 3.

## Suggested Spike Questions

The next spike should answer these before any implementation plan is written:

1. Can a system-managed settings model coexist with the current menu bar target shape, or does it require a larger app-shell migration?
2. If the answer is "yes, but with lifecycle changes", can `GestureFlowApplication` remain the coordinator of gesture runtime state and settings bindings?
3. If the answer is "no", is the product willing to redesign settings into a menu-bar-native surface, or is a dedicated settings host acceptable?
4. Which existing tests are asserting `NSPanel` mechanics rather than true user-facing behavior, and can those be rewritten around orchestration contracts instead?

## Proposed Decision Gates

Do not start implementation until these decisions are explicit:

- **Gate 1:** Keep desktop-style settings window semantics, or permit a menu-bar-native redesign?
- **Gate 2:** Keep a single-process app shell, or allow a more separated settings host boundary?
- **Gate 3:** Preserve the current `SettingsViewModel` injection model as-is? Recommendation: **yes**.

## Files Most Likely to Change by Route

### Route 1

- `Sources/GestureFlowApp/App/main.swift`
- `Sources/GestureFlowApp/App/AppDelegate.swift`
- `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- `Sources/GestureFlowApp/Settings/SettingsWindowController.swift`
- `Tests/GestureFlowAppTests/AppDelegateTests.swift`
- `Tests/GestureFlowAppTests/GestureFlowApplicationTests.swift`
- `Tests/GestureFlowAppTests/SettingsWindowControllerTests.swift`

### Route 2

- `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- New settings-host abstraction and related tests

### Route 3

- `Sources/GestureFlowApp/Menu/StatusBarController.swift`
- `Sources/GestureFlowApp/Settings/MainSettingsView.swift`
- `Sources/GestureFlowApp/Settings/SettingsWindowController.swift` or its replacement
- `Tests/GestureFlowAppTests/StatusBarControllerTests.swift`
- `Tests/GestureFlowAppTests/SettingsWindowControllerTests.swift`

## Short Conclusion

The current `LSUIElement + NSPanel` path has exhausted the low-cost activation and timing tweaks that were reasonable to try. The next productive move is not another focus hack; it is a bounded architecture spike that decides whether settings should be system-managed, separately hosted, or redesigned around a menu-bar-native interaction model.

Selected implementation path: Route B with a SwiftUI-managed settings scene, coordinator retention, and macOS 14+ support only.
Execution plan: `docs/superpowers/plans/2026-05-21-route-b-swiftui-settings-window-plan.md`
