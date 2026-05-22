# Xcode macOS App Project Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `GestureFlow.xcodeproj` the standard macOS app entry point while preserving `swift build` and `swift test` compatibility on the current shared source tree.

**Architecture:** Add a native Xcode project with app/core/test targets that reference the existing `Sources/`, `Tests/`, and `Resources/` layout instead of copying files. Keep `Package.swift` as a compatibility description and align app metadata, target membership, and validation commands so Xcode is primary and Swift Package remains a supported fallback path.

**Tech Stack:** Swift, AppKit, SwiftUI, Xcode project files, Swift Package Manager, XCTest, shell scripts

---

## File Map

- Create: `GestureFlow.xcodeproj/project.pbxproj`
  - Define native Xcode targets, build settings, file references, and target memberships.
- Create: `GestureFlow.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
  - Make the project open cleanly in Xcode.
- Create: `GestureFlow.xcodeproj/xcshareddata/xcschemes/GestureFlowApp.xcscheme`
  - Provide a shared run/test scheme for the app target.
- Create: `GestureFlow.xcodeproj/xcshareddata/xcschemes/GestureFlowCore.xcscheme`
  - Provide a shared scheme for focused core target validation.
- Create: `GestureFlow.xcodeproj/xcshareddata/xcschemes/GestureFlowPackageCompatibility.xcscheme`
  - Optional compatibility scheme if the project needs an explicit dual-path validation entry point.
- Modify: `Resources/Info.plist`
  - Align app metadata with the Xcode app target and remove any values that would drift from Xcode-managed settings.
- Modify: `Scripts/package_app.sh`
  - Demote the script from primary build path to auxiliary packaging path and optionally route bundle creation through `xcodebuild`.
- Create: `Scripts/validate_build_paths.sh`
  - Run both the Xcode-primary path and the Swift Package compatibility path in one command.
- Modify: `README.md`
  - Make Xcode the primary onboarding, build, run, and test workflow.
- Modify: `Package.swift`
  - Only if needed to preserve source alignment or compatibility semantics after the Xcode project lands.

## Chunk 1: Create The Native Xcode Project Shell

### Task 1: Add the minimal project files and shared schemes

**Files:**
- Create: `GestureFlow.xcodeproj/project.pbxproj`
- Create: `GestureFlow.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `GestureFlow.xcodeproj/xcshareddata/xcschemes/GestureFlowApp.xcscheme`
- Create: `GestureFlow.xcodeproj/xcshareddata/xcschemes/GestureFlowCore.xcscheme`

- [ ] **Step 1: Verify the project does not exist yet**

Run:

```bash
xcodebuild -list -project GestureFlow.xcodeproj
```

Expected:
- FAIL with "does not exist" or equivalent because the Xcode project has not been created yet.

- [ ] **Step 2: Create the minimal Xcode project shell**

Create a native Xcode project that defines these targets:
- `GestureFlowCore`
- `GestureFlowApp`
- `GestureFlowCoreTests`
- `GestureFlowAppTests`

Required project settings:
- macOS deployment target `14.0`
- product names aligned with current module names
- `GestureFlowApp` depends on `GestureFlowCore`
- shared schemes committed to source control

Required app target wiring:
- executable name remains `GestureFlowApp`
- app display name remains `GestureFlow`
- `Info.plist` points at `Resources/Info.plist` unless a clearly shared replacement is introduced in the same task

- [ ] **Step 3: Verify Xcode can enumerate the project**

Run:

```bash
xcodebuild -list -project GestureFlow.xcodeproj
```

Expected:
- PASS
- output lists the four targets and the shared `GestureFlowApp` scheme

- [ ] **Step 4: Commit**

```bash
git add GestureFlow.xcodeproj
git commit -m "build: add native xcode project shell"
```

## Chunk 2: Attach The Existing Source Tree To The Correct Targets

### Task 2: Add source, resource, and test memberships without moving files

**Files:**
- Modify: `GestureFlow.xcodeproj/project.pbxproj`

- [ ] **Step 1: Verify the shell project cannot build the app yet**

Run:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
```

Expected:
- FAIL because source files, frameworks, resources, or target memberships are not fully wired yet.

- [ ] **Step 2: Add the existing files to the native targets**

Assign current repository files to the correct targets:
- `Sources/GestureFlowCore/**` -> `GestureFlowCore`
- `Sources/GestureFlowApp/**` -> `GestureFlowApp`
- `Tests/GestureFlowCoreTests/**` -> `GestureFlowCoreTests`
- `Tests/GestureFlowAppTests/**` -> `GestureFlowAppTests`
- `Resources/Info.plist` -> `GestureFlowApp`

Required build settings:
- link `AppKit`, `SwiftUI`, `CoreGraphics`, and `ApplicationServices` for the app target
- keep module names aligned with existing imports used by tests
- configure test targets with `@testable import` compatibility

Do not:
- move files into Xcode-generated folders
- create duplicate source files under the project
- rename modules during this task

- [ ] **Step 3: Verify the app target builds in Xcode**

Run:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
```

Expected:
- PASS
- the build completes without missing-file or missing-framework errors

- [ ] **Step 4: Verify the test targets are visible**

Run:

```bash
xcodebuild -list -project GestureFlow.xcodeproj
```

Expected:
- PASS
- output shows `GestureFlowCoreTests` and `GestureFlowAppTests` as testable targets under the app scheme or project definition

- [ ] **Step 5: Commit**

```bash
git add GestureFlow.xcodeproj/project.pbxproj
git commit -m "build: wire existing sources into xcode targets"
```

## Chunk 3: Align Metadata And Preserve Dual-Path Compatibility

### Task 3: Make Xcode the primary app definition without breaking Swift Package

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `Package.swift`
- Modify: `Scripts/package_app.sh`

- [ ] **Step 1: Verify the current package path still works before changing metadata**

Run:

```bash
swift build
```

Expected:
- PASS

- [ ] **Step 2: Align app metadata ownership**

Make `GestureFlowApp` in Xcode the primary owner of app metadata while keeping one shared metadata source.

Required checks:
- `CFBundleExecutable` remains consistent with the Xcode app target product
- `CFBundleName` remains `GestureFlow`
- `LSUIElement` remains enabled by default
- minimum system version remains `14.0`

If `Package.swift` needs no changes after the Xcode project exists, leave it untouched. Only edit it if compatibility fails or naming has drifted.

- [ ] **Step 3: Update packaging to use the Xcode-primary path**

Refactor `Scripts/package_app.sh` so it no longer defines the canonical app bundle creation path through `swift build`.

Preferred direction:
- use `xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -configuration Release build`
- package the resulting `.app` bundle or derived product
- keep the script as a convenience wrapper, not the source of app metadata truth

- [ ] **Step 4: Verify both build paths still work**

Run:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
swift build
```

Expected:
- both commands PASS

- [ ] **Step 5: Commit**

```bash
git add Resources/Info.plist Package.swift Scripts/package_app.sh
git commit -m "build: align xcode metadata with package compatibility"
```

## Chunk 4: Make Validation And Onboarding Match The New Primary Workflow

### Task 4: Add one command that validates both workflows

**Files:**
- Create: `Scripts/validate_build_paths.sh`

- [ ] **Step 1: Write the validation script**

Create a shell script that runs:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx test
swift build
swift test
```

Script requirements:
- `set -euo pipefail`
- clear logging around each phase
- repository-root relative path handling

- [ ] **Step 2: Verify the script fails before documentation is updated if any command is broken**

Run:

```bash
Scripts/validate_build_paths.sh
```

Expected:
- PASS if all dual-path wiring is complete
- otherwise FAIL with the first broken path, which must be fixed before continuing

- [ ] **Step 3: Commit**

```bash
git add Scripts/validate_build_paths.sh
git commit -m "build: add dual path validation script"
```

### Task 5: Update developer documentation to make Xcode the default

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the primary developer workflow**

Replace the current Swift Package-first instructions so the top-level workflow becomes:
- open `GestureFlow.xcodeproj`
- Run from Xcode
- Test from Xcode or `xcodebuild`

Keep a separate section for compatibility commands:
- `swift build`
- `swift test`

Keep packaging documentation, but describe it as an auxiliary flow.

- [ ] **Step 2: Verify the documentation matches the real commands**

Manually run or spot-check every command written into `README.md`:

```bash
xcodebuild -list -project GestureFlow.xcodeproj
Scripts/validate_build_paths.sh
```

Expected:
- PASS
- no README command is stale or package-first in tone

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: make xcode the primary workflow"
```

## Chunk 5: Final Verification

### Task 6: Run the full migration acceptance checklist

**Files:**
- Modify: `README.md` if command mismatches are found
- Modify: `Scripts/validate_build_paths.sh` if command mismatches are found
- Modify: `GestureFlow.xcodeproj/project.pbxproj` if target drift is found
- Modify: `Package.swift` if compatibility drift is found

- [ ] **Step 1: Validate project discovery**

Run:

```bash
xcodebuild -list -project GestureFlow.xcodeproj
```

Expected:
- PASS
- lists app/core/test targets and shared schemes

- [ ] **Step 2: Validate Xcode-primary build and test**

Run:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx test
```

Expected:
- PASS

- [ ] **Step 3: Validate Swift Package compatibility**

Run:

```bash
swift build
swift test
```

Expected:
- PASS

- [ ] **Step 4: Validate packaging**

Run:

```bash
Scripts/package_app.sh
```

Expected:
- PASS
- produces an app bundle using the Xcode-primary build path or a clearly documented equivalent

- [ ] **Step 5: Commit any final fixes**

```bash
git add GestureFlow.xcodeproj Package.swift Resources/Info.plist Scripts/package_app.sh Scripts/validate_build_paths.sh README.md
git commit -m "chore: finalize xcode app project migration"
```
