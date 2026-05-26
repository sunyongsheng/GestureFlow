# Custom Gesture Signature Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users draw custom gesture signatures from the Picker, store them in `gestures.yaml` under `customGestureSignatures`, and select duplicates instead of re-adding.

**Architecture:** Extend `GestureConfiguration` with a new array field; add a recording sheet with canvas-local recognition (Y-flip wrapper around `GestureRecognizer`); extend `GestureSignaturePicker` with divider, custom grid, and + button; pause `GestureEngine` while the sheet is visible.

**Tech Stack:** Swift, SwiftUI, AppKit, GestureFlowCore recognizer, XCTest.

**Spec:** `docs/superpowers/specs/2026-05-26-custom-gesture-signature-design.md`

---

## File Map

| File | Change |
| --- | --- |
| `Sources/GestureFlowCore/Models/GestureConfiguration.swift` | Add `customGestureSignatures` |
| `Sources/GestureFlowCore/Recognition/GestureRecognizer.swift` | Optional `coordinateSystem` for recording |
| `Sources/GestureFlowCore/Recognition/GestureSignatureIdentity.swift` | **Create** — stable `id` for any signature |
| `Sources/GestureFlowCore/Recognition/CustomGestureSignatureLibrary.swift` | **Create** — lookup/append/contains |
| `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSignatureRecordingView.swift` | **Create** — canvas + live preview |
| `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSignatureRecordingSheet.swift` | **Create** — sheet chrome |
| `Sources/GestureFlowApp/Settings/Gestures/UI/GestureSignaturePicker.swift` | Divider, custom section, +, scroll |
| `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift` | Mutate custom list, restore default |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Pause/resume engine hook |
| `Tests/GestureFlowCoreTests/GestureConfigurationTests.swift` | **Create** or extend |
| `Tests/GestureFlowCoreTests/GestureRecognizerRecordingTests.swift` | **Create** |
| `Tests/GestureFlowAppTests/Settings/Gestures/CustomGestureSignatureTests.swift` | **Create** |

---

### Task 1: Configuration model + YAML

**Files:**
- Modify: `GestureConfiguration.swift`
- Test: `Tests/GestureFlowCoreTests/GestureConfigurationTests.swift`

- [ ] **Step 1:** Failing test — encode/decode `customGestureSignatures`, default empty array.
- [ ] **Step 2:** Add property with default `[]`; update `defaultTemplate` / `restoreDefaultGestureConfiguration` to clear customs.
- [ ] **Step 3:** `swift test --filter GestureConfigurationTests`

---

### Task 2: Recognizer coordinate system for canvas

**Files:**
- Modify: `GestureRecognizer.swift`
- Create: `GestureRecognizerRecordingTests.swift`

- [ ] **Step 1:** Failing test — points moving down in view coords → `.down` token.
- [ ] **Step 2:** Add `GesturePointCoordinateSystem` (`.screen` / `.view`) and branch dy sign in direction extraction.
- [ ] **Step 3:** `swift test --filter GestureRecognizerRecordingTests`

---

### Task 3: Signature lookup helpers

**Files:**
- Create: `GestureSignatureIdentity.swift`, `CustomGestureSignatureLibrary.swift`
- Test: `CustomGestureSignatureLibraryTests.swift`

- [ ] **Step 1:** `id(for:)` → `"D,R"`; `contains(_:catalog:customs:)` checks catalog + customs.
- [ ] **Step 2:** Tests for built-in hit, custom hit, miss.
- [ ] **Step 3:** `swift test --filter CustomGestureSignatureLibraryTests`

---

### Task 4: Recording UI

**Files:**
- Create: `GestureSignatureRecordingView.swift`, `GestureSignatureRecordingSheet.swift`

- [ ] **Step 1:** Canvas `DragGesture` collects points; live `recognize` updates `@State signature`.
- [ ] **Step 2:** Show glyph + `chineseDisplayName`; confirm disabled when nil.
- [ ] **Step 3:** Sheet with 取消 / 确认 callbacks (no persistence yet).

---

### Task 5: Picker integration

**Files:**
- Modify: `GestureSignaturePicker.swift`, `SettingsViewModel.swift`

- [ ] **Step 1:** Bind `customGestureSignatures` + `onPersist` from parent.
- [ ] **Step 2:** Divider, custom `LazyVGrid`,「+」opens sheet.
- [ ] **Step 3:** `ScrollViewReader` + `scrollTo` on confirm (duplicate or new).
- [ ] **Step 4:** Confirm handler: duplicate → set selection only; else append + persist.

---

### Task 6: Engine pause

**Files:**
- Modify: `GestureFlowApplication.swift`, wire from `GestureSettingsView` / picker

- [ ] **Step 1:** `pauseGestureRecognitionIfNeeded()` / `resumeGestureRecognitionIfNeeded()` on application.
- [ ] **Step 2:** Call on sheet `onAppear` / `onDisappear`.
- [ ] **Step 3:** Mock test — engine stopped while sheet flag set.

---

### Task 7: App tests + full run

**Files:**
- Create: `CustomGestureSignatureTests.swift`

- [ ] **Step 1:** ViewModel tests — append custom, duplicate selects without count increase.
- [ ] **Step 2:** `swift test`
- [ ] **Step 3:** Manual — draw custom, confirm, verify `gestures.yaml` and Picker scroll.

---

### Task 8: Commit

- [ ] `feat: add custom gesture signature drawing and storage`
