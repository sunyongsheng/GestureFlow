# Trail Stroke Settings Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional outer trail stroke (color + width) to gesture feedback settings and overlay rendering, default off.

**Architecture:** Extend `FeedbackConfiguration` with three stroke fields; map into `GestureTrailAppearance`; draw outer-then-inner in `GestureOverlayView` and `GestureTrailPreview`; expose toggle + conditional controls in `FeedbackSettingsView`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (`NSBezierPath`), `GestureFlowCore` JSON config.

**Spec:** `docs/superpowers/specs/2026-05-24-trail-stroke-settings-design.md`

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Models/AppConfiguration.swift` | `FeedbackConfiguration` stroke fields + Codable |
| `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift` | `GestureTrailAppearance` stroke fields |
| `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift` | Double-layer trail drawing |
| `Sources/GestureFlowApp/Settings/Advanced/FeedbackSettingsView.swift` | Toggle, stroke color, stroke width UI |
| `Sources/GestureFlowApp/Settings/Advanced/GestureTrailPreview.swift` | Preview layering |
| `Tests/GestureFlowCoreTests/FeedbackConfigurationTests.swift` | Create — decode/encode defaults |
| `Tests/GestureFlowAppTests/Overlay/GestureTrailAppearanceTests.swift` | Create — appearance mapping |

---

## Chunk 1: Core model and appearance

### Task 1: FeedbackConfiguration stroke fields

**Files:**
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Create: `Tests/GestureFlowCoreTests/FeedbackConfigurationTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testFeedbackConfigurationDefaultsStrokeDisabled() {
    let config = FeedbackConfiguration.default
    XCTAssertFalse(config.trailStrokeEnabled)
    XCTAssertEqual(config.trailStrokeColorHex, "#FFFFFF")
    XCTAssertEqual(config.trailStrokeWidth, 1.5, accuracy: 0.001)
}

func testFeedbackConfigurationDecodesWithoutStrokeKeys() throws {
    let json = """
    {"trailColorHex":"#4A90E2","trailWidth":3,"trailOpacity":0.85}
    """.data(using: .utf8)!
    let config = try JSONDecoder().decode(FeedbackConfiguration.self, from: json)
    XCTAssertFalse(config.trailStrokeEnabled)
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --filter FeedbackConfigurationTests`

- [ ] **Step 3: Implement fields on `FeedbackConfiguration`**

Add properties, update `init`, `CodingKeys`, `init(from:)`, and `.default`.

- [ ] **Step 4: Run tests — expect PASS**

Run: `swift test --filter FeedbackConfigurationTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Models/AppConfiguration.swift Tests/GestureFlowCoreTests/FeedbackConfigurationTests.swift
git commit -m "feat(core): add optional trail stroke to feedback configuration"
```

### Task 2: GestureTrailAppearance mapping

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift`
- Create: `Tests/GestureFlowAppTests/Overlay/GestureTrailAppearanceTests.swift`

- [ ] **Step 1: Write failing test**

```swift
func testGestureTrailAppearanceMapsStrokeFromFeedback() {
    let feedback = FeedbackConfiguration(
        trailColorHex: "#111111",
        trailWidth: 4,
        trailOpacity: 0.9,
        trailStrokeEnabled: true,
        trailStrokeColorHex: "#FFFFFF",
        trailStrokeWidth: 2
    )
    let appearance = GestureTrailAppearance(feedback: feedback)
    XCTAssertTrue(appearance.strokeEnabled)
    XCTAssertEqual(appearance.strokeColorHex, "#FFFFFF")
    XCTAssertEqual(appearance.strokeWidth, 2)
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `swift test --filter GestureTrailAppearanceTests`

- [ ] **Step 3: Add stroke fields to `GestureTrailAppearance`**

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift Tests/GestureFlowAppTests/Overlay/GestureTrailAppearanceTests.swift
git commit -m "feat: map trail stroke fields into overlay appearance"
```

---

## Chunk 2: Rendering

### Task 3: Overlay double-layer drawing

**Files:**
- Modify: `Sources/GestureFlowApp/Overlay/GestureOverlayView.swift`

- [ ] **Step 1: Refactor `drawTrail()` to extract path builder** (polyline + single-point) used for both layers.

- [ ] **Step 2: When `trailAppearance.strokeEnabled`, draw outer stroke first**

Outer `lineWidth = trailWidth + 2 * strokeWidth`, color from `strokeColorHex`, opacity `trailOpacity`.

- [ ] **Step 3: Draw main trail on top** (existing color/width logic).

- [ ] **Step 4: Build and manual smoke test**

Run app, enable stroke in settings, perform a gesture; verify outer ring visible. Disable toggle — matches previous look.

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Overlay/GestureOverlayView.swift
git commit -m "feat: render optional outer trail stroke in overlay"
```

### Task 4: Settings preview layering

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Advanced/GestureTrailPreview.swift`

- [ ] **Step 1: Add conditional outer `.stroke()` under main stroke when `trailStrokeEnabled`.**

- [ ] **Step 2: Verify preview in Advanced settings updates live when toggling stroke.**

- [ ] **Step 3: Commit**

```bash
git add Sources/GestureFlowApp/Settings/Advanced/GestureTrailPreview.swift
git commit -m "feat: show trail stroke in settings preview"
```

---

## Chunk 3: Settings UI

### Task 5: Feedback settings controls

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Advanced/FeedbackSettingsView.swift`

- [ ] **Step 1: Add toggle binding** via `feedbackBinding(\.trailStrokeEnabled)` or dedicated binding after「轨迹颜色」.

- [ ] **Step 2: Wrap stroke color + width rows in `if viewModel.configuration.feedback.trailStrokeEnabled`.**

- [ ] **Step 3: Reuse `TrailColorPickerControl` for stroke color** (`strokeColorBinding`).

- [ ] **Step 4: Add stroke width slider** 0.5–8.0, step 0.5, label「描边粗细」.

- [ ] **Step 5: Run full test suite**

Run: `swift test`

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp/Settings/Advanced/FeedbackSettingsView.swift
git commit -m "feat: add trail stroke controls to feedback settings"
```

### Task 6: Fix downstream initializers

**Files:**
- Modify any test/app call sites that use `FeedbackConfiguration(...)` memberwise init after new parameters (grep `FeedbackConfiguration(`).

- [ ] **Step 1: Grep and update compile errors** in tests and app.

- [ ] **Step 2: Run `swift test` — all green.**

- [ ] **Step 3: Commit if not empty**

```bash
git commit -am "chore: update FeedbackConfiguration call sites for stroke fields"
```

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-24-trail-stroke-settings-plan.md`.

Ready to execute when you want implementation started.
