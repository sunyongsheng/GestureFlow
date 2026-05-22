# Xcode macOS App Project Design

**Goal**

Convert the repository from a Swift Package-first executable into a standard
Xcode-openable macOS app project while preserving command-line compatibility for
`swift build` and `swift test`.

The migration should make Xcode the primary developer entry point without
forcing a disruptive source tree rewrite or changing existing app behavior.

**Constraints**

- Xcode must become the primary way to open, run, debug, and test the app.
- `Package.swift` must remain usable for `swift build` and `swift test`.
- The migration must preserve the current single-repository, shared-source
  layout.
- Existing macOS 14+ assumptions must remain intact because the current app
  uses the SwiftUI `Settings` scene.
- Existing app behavior is in scope for preservation, especially status bar
  behavior, settings scene lifecycle, Dock visibility, and activation-policy
  transitions.
- The migration must minimize behavioral risk; project-definition changes are
  preferred over source relocation or feature rewrites.

## Target Structure

Add a repository-root `GestureFlow.xcodeproj` as the new primary entry point.

Keep the current filesystem layout as the canonical source layout:
- `Sources/`
- `Tests/`
- `Resources/`

Do not create a second mirrored source tree for Xcode. The same files should be
referenced by both the Xcode project and `Package.swift`.

Inside Xcode, define native targets with stable names that mirror the existing
logical module split:
- `GestureFlowCore`
- `GestureFlowApp`
- `GestureFlowCoreTests`
- `GestureFlowAppTests`

The app target depends on the core target. Tests follow the same production
boundary split already present in the repository.

## Boundary Division

### GestureFlowCore

`GestureFlowCore` remains the domain layer.

Responsibilities:
- gesture models
- configuration persistence abstractions and storage logic
- recognition, matching, and validation
- logic that is platform-neutral or only weakly platform-coupled

Rules:
- avoid `SwiftUI`
- avoid `AppKit` unless a very small compatibility seam is unavoidable
- keep the module reusable by both Xcode and Swift Package builds

### GestureFlowApp

`GestureFlowApp` remains the shell and system-integration layer.

Responsibilities:
- app lifecycle and app delegate wiring
- status bar integration
- permission handling
- event tap integration
- overlay windows and presentation
- settings scene and settings bridge stack
- activation-policy and foreground/background presentation control

Rules:
- all AppKit and SwiftUI shell behavior belongs here
- app resources and bundle metadata are owned here
- core-domain logic should not drift back into this layer unless it directly
  depends on platform APIs

### Tests

Test boundaries follow production boundaries:
- `GestureFlowCoreTests` validates pure and near-pure logic
- `GestureFlowAppTests` validates lifecycle, presentation, settings, shell
  wiring, and system-integration seams

This split reduces ambiguity when maintaining both Xcode and Swift Package
descriptions.

## Project Configuration

`GestureFlow.xcodeproj` becomes the authoritative app project.

`GestureFlowApp` owns:
- app lifecycle configuration
- bundle metadata
- entitlements
- resource compilation
- scheme/run configuration

`GestureFlowCore` is compiled as an independent target reused by the app and
its tests.

The Xcode project must explicitly set macOS 14 as the deployment target so the
project-level configuration matches the current app architecture.

## Info.plist And Resources

`Info.plist` should be managed by the Xcode app target as the primary app
metadata source.

To preserve command-line compatibility, the repository may keep one shared plist
template or one shared metadata source that is referenced by both Xcode and the
existing packaging flow. The key rule is to avoid maintaining two semantically
equivalent plist definitions that can drift apart.

`LSUIElement`, bundle identifier, version metadata, and minimum system version
must resolve to the same values in both Xcode and Swift Package based workflows.

## Build And Run Entry Points

After migration:
- Xcode Run/Test and `xcodebuild` become the primary build and validation path
- `swift build` and `swift test` remain supported as compatibility paths

Primary commands:
- `xcodebuild -scheme GestureFlowApp`
- Xcode Run
- Xcode Test

Compatibility commands:
- `swift build`
- `swift test`

The Swift Package path should no longer be treated as the authoritative producer
of the desktop app bundle. It remains a compatibility and validation path.

## Migration Strategy

### Phase 1: Establish Xcode As Primary

Do not move source files physically in the first phase.

Instead:
- create `GestureFlow.xcodeproj`
- add native app/core/test targets
- assign existing files to the correct target memberships
- configure schemes, build settings, and test execution
- keep module names and product identities stable

This keeps the highest-risk work focused on project definition rather than code
movement.

### Phase 2: Selective Cleanup

After the Xcode project is stable, make only targeted cleanups that reduce
double-maintenance cost, for example:
- standardize configuration file locations
- tighten resource ownership
- simplify packaging scripts
- update CI entry points

Avoid template-driven cleanup that only makes the repository look more
"Xcode-like" without improving maintainability.

## Consistency Strategy

Because the repository will have both an Xcode project and `Package.swift`,
consistency rules are part of the design:

- target names should remain aligned between Xcode and Swift Package
- test target names should remain aligned
- product names should remain aligned
- bundle identifier and deployment target should remain aligned
- the same source files should be referenced by both systems

Any rename that is not required for the migration should be postponed. During
the transition, unnecessary renames would widen the blast radius from
"project-definition migration" into "module identity migration."

## Risks

### Definition Drift

The largest long-term risk is drift between Xcode target membership and
`Package.swift` target definitions. This can lead to files compiling in only one
of the two workflows.

### Metadata Drift

If app metadata is duplicated across Xcode settings, plist files, and packaging
scripts, runtime behavior can diverge in subtle ways. `LSUIElement`, deployment
target, bundle metadata, and app naming are especially sensitive.

### Test Environment Differences

Xcode and Swift Package test execution differ slightly in access control,
resource lookup, and bundle-loading expectations. The migration must expose
these differences early rather than treating them as post-migration cleanup.

### Runtime Behavior Regression

This codebase contains non-trivial AppKit and SwiftUI lifecycle behavior,
especially around settings presentation and activation-policy transitions. The
project migration must not introduce regressions that appear only when running
under Xcode.

## Non-Goals

This migration does not include:
- rewriting UI architecture
- changing feature behavior
- merging the app and core modules
- signing, notarization, or distribution pipeline redesign
- opportunistic refactors unrelated to making Xcode the primary app project

Existing settings scene behavior, Dock visibility behavior, menu bar behavior,
and test semantics are treated as preserved behavior unless a change is
strictly required to make the Xcode project function correctly.

## Validation

### Required Checks

- the repository opens directly through `GestureFlow.xcodeproj`
- `GestureFlowApp` runs successfully in Xcode
- `GestureFlowCoreTests` pass in Xcode
- `GestureFlowAppTests` pass in Xcode
- `swift build` still succeeds
- `swift test` still succeeds

### Documentation And Workflow Checks

- `README.md` is updated so Xcode is the primary developer entry point
- scripts are updated so their role is clearly auxiliary rather than primary
- CI reflects both the Xcode-primary path and the Swift Package compatibility
  path

## Acceptance Criteria

- A developer can clone the repository, open `GestureFlow.xcodeproj`, and use
  Xcode as the normal macOS app workflow.
- The app still builds and runs as a standard macOS app target in Xcode.
- The existing source tree remains shared rather than duplicated.
- The current logical split between core logic and app shell remains intact.
- `swift build` and `swift test` continue to work after the migration.
- Documentation and automation clearly indicate that Xcode is primary and Swift
  Package is a compatibility path.
