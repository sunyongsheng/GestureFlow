# App Language Settings Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add **应用语言** in General settings (`zh-Hans` / `en`) stored in `AppConfiguration`, with immediate full-app UI refresh via `LocalizationManager`.

**Architecture:** Extend `AppConfiguration` with `general.language`; introduce `LocalizationManager` + `L10nKey` + per-language string tables; inject manager at app root; replace hardcoded UI copy across SwiftUI and AppKit; refresh menu bar and overlay on language change after successful save.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, `GestureFlowCore` YAML config (Yams).

**Spec:** `docs/superpowers/specs/2026-05-28-app-language-settings-design.md`

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Models/AppConfiguration.swift` | `GeneralConfiguration`, `AppLanguage`, `AppConfiguration.general` |
| `Sources/GestureFlowCore/Models/AppLanguage.swift` | Create — enum + raw value `zh-Hans` / `en` |
| `Sources/GestureFlowApp/Localization/LocalizationManager.swift` | Create — runtime language + lookup |
| `Sources/GestureFlowApp/Localization/L10nKey.swift` | Create — stable keys |
| `Sources/GestureFlowApp/Localization/L10nStrings+zh.swift` | Create — Chinese table |
| `Sources/GestureFlowApp/Localization/L10nStrings+en.swift` | Create — English table |
| `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift` | Language Picker below gesture recognition |
| `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift` | Language binding + save-then-apply |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Own manager, init from config, inject |
| `Sources/GestureFlowApp/Menu/StatusBarController.swift` | Localized titles; refresh on change |
| `Sources/GestureFlowApp/Overlay/GestureOverlayDisplaying.swift` | Remove hardcoded overlay copy |
| `Sources/GestureFlowApp/App/GestureFlowShellApp.swift` | Localized Settings command |
| `Tests/GestureFlowCoreTests/GeneralConfigurationTests.swift` | Create — Codable defaults |
| `Tests/GestureFlowAppTests/Localization/LocalizationManagerTests.swift` | Create — lookup + switch |
| `Tests/GestureFlowAppTests/Settings/General/GeneralSettingsViewTests.swift` | Extend — language row |
| ~25 Swift files with Chinese literals | Migrate to `L10nKey` (see grep list in spec) |

---

## Chunk 1: Core configuration

### Task 1: `AppLanguage` and `GeneralConfiguration`

**Files:**
- Create: `Sources/GestureFlowCore/Models/AppLanguage.swift`
- Modify: `Sources/GestureFlowCore/Models/AppConfiguration.swift`
- Create: `Tests/GestureFlowCoreTests/GeneralConfigurationTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testGeneralConfigurationDefaultsToZhHans() {
    let config = AppConfiguration()
    XCTAssertEqual(config.general.language, .zhHans)
}

func testAppConfigurationDecodesWithoutGeneralSection() throws {
    let yaml = "isEnabled: true\n"
    // decode — general.language == .zhHans
}

func testAppConfigurationRoundTripsLanguageEn() throws {
    var config = AppConfiguration()
    config.general.language = .en
    // encode/decode — language == .en
}

func testUnknownLanguageFallsBackToZhHans() throws {
    // YAML general.language: fr → .zhHans
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --filter GeneralConfigurationTests`

- [ ] **Step 3: Implement `AppLanguage` (`zh-Hans`, `en`) and `GeneralConfiguration`**

Add `public var general: GeneralConfiguration` to `AppConfiguration` with `CodingKeys`, `init`, `init(from:)`, default.

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore Tests/GestureFlowCoreTests
git commit -m "feat(core): add general.language to app configuration"
```

---

## Chunk 2: Localization runtime

### Task 2: `LocalizationManager` and string tables

**Files:**
- Create: `Sources/GestureFlowApp/Localization/L10nKey.swift`
- Create: `Sources/GestureFlowApp/Localization/L10nStrings+zh.swift`
- Create: `Sources/GestureFlowApp/Localization/L10nStrings+en.swift`
- Create: `Sources/GestureFlowApp/Localization/LocalizationManager.swift`
- Create: `Tests/GestureFlowAppTests/Localization/LocalizationManagerTests.swift`

- [ ] **Step 1: Define initial `L10nKey` cases**

Minimum set for next tasks: sidebar sections, status bar menu, general settings (including `general.appLanguage.title` / description), overlay unmatched, settings command.

- [ ] **Step 2: Write failing tests**

```swift
func testStringReturnsChineseByDefault() {
    let manager = LocalizationManager(language: .zhHans)
    XCTAssertEqual(manager.string(.settingsSectionGeneral), "通用")
}

func testSetLanguageUpdatesStrings() {
    let manager = LocalizationManager(language: .zhHans)
    manager.setLanguage(.en)
    XCTAssertEqual(manager.string(.settingsSectionGeneral), "General")
}
```

- [ ] **Step 3: Implement manager + both tables**

`setLanguage` must publish change on main actor / main queue.

- [ ] **Step 4: Run tests — expect PASS**

Run: `swift test --filter LocalizationManagerTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowApp/Localization Tests/GestureFlowAppTests/Localization
git commit -m "feat: add LocalizationManager with zh/en string tables"
```

### Task 3: Wire manager at application root

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`
- Modify: `Sources/GestureFlowApp/Settings/Window/Hosting/SettingsWindowDependencies.swift` (if needed)
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift` — `makeSettingsViewModel`

- [ ] **Step 1: Create `localizationManager` in `GestureFlowApplication`**

Init from `configuration.general.language` after load.

- [ ] **Step 2: Pass manager into `SettingsViewModel` init**

Add parameter; store weak/let reference.

- [ ] **Step 3: Pass manager into `StatusBarController`**

Subscribe to language changes; call `refreshLocalizedStrings()` (new method).

- [ ] **Step 4: Manual smoke**

Launch app — default Chinese UI unchanged.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: inject LocalizationManager at app composition root"
```

---

## Chunk 3: General settings UI + save flow

### Task 4: Language Picker in `GeneralSettingsView`

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/General/GeneralSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/Shell/SettingsViewModel.swift`
- Modify: `Tests/GestureFlowAppTests/Settings/General/GeneralSettingsViewTests.swift`

- [ ] **Step 1: Add `languageBinding` on ViewModel**

On change: update `configuration.general.language`, call existing persist path, on success `localizationManager.setLanguage`.

- [ ] **Step 2: Insert row after gesture recognition**

Title via `l10n.string(.generalAppLanguageTitle)` → 应用语言 / Application Language. Picker labels fixed: 中文（简体）, English.

- [ ] **Step 3: Inject `environmentObject` at `SettingsRootView`**

- [ ] **Step 4: Test binding writes config + updates manager**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: add application language picker in general settings"
```

---

## Chunk 4: SwiftUI string migration

### Task 5: Settings shell and sidebar

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/Shell/SettingsSidebarModels.swift`
- Modify: `Sources/GestureFlowApp/Settings/Shell/MainSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/Shell/SettingsRootView.swift`
- Extend: `L10nKey` + both string tables

- [ ] **Step 1: Replace `SettingsSection.title` with `l10n.string`**

- [ ] **Step 2: Migrate `MainSettingsView` recovery banner strings**

- [ ] **Step 3: Run `swift test` — fix any snapshot/title tests**

- [ ] **Step 4: Commit**

### Task 6: General, About, Permission, Advanced settings

**Files:**
- Modify: `GeneralSettingsView.swift`, `PermissionGuideView.swift`, `AboutSettingsView.swift`
- Modify: `AdvancedSettingsView.swift`, `FeedbackSettingsView.swift`, `FeedbackPopupSettingsView.swift`, `GestureTriggerSettingsView.swift`, `GestureTrailPreview.swift`

- [ ] **Step 1: Add keys for all visible strings in these views**

- [ ] **Step 2: Replace literals with `l10n.string`**

- [ ] **Step 3: Commit per sub-area or one commit for advanced**

### Task 7: Gesture settings views

**Files:**
- Modify: `GestureSettingsView.swift`, `GestureSignaturePicker.swift`, `GestureSignatureRecordingView.swift`, `GestureSignatureRecordingSheet.swift`, `GestureShortcutTagView.swift`

- [ ] **Step 1: Localize UI chrome only (buttons, section titles, empty states)**

- [ ] **Step 2: Do NOT translate user gesture names or recorded signatures**

- [ ] **Step 3: Commit**

### Task 8: Commands and recovery messages

**Files:**
- Modify: `GestureFlowShellApp.swift`
- Modify: `SettingsViewModel.swift` (recovery notice strings)
- Modify: `Sources/GestureFlowCore/Configuration/ConfigurationDirectoryRelocator.swift` (user-facing errors → keys or pass l10n from app layer)

- [ ] **Step 1: Expose manager to `SettingsWindowCommands` (minimal shared accessor)**

- [ ] **Step 2: Localize recovery / relocator messages**

- [ ] **Step 3: Commit**

---

## Chunk 5: AppKit, overlay, engine copy

### Task 9: Status bar full localization

**Files:**
- Modify: `StatusBarController.swift`
- Modify: `Tests/GestureFlowAppTests/StatusBarControllerTests.swift`

- [ ] **Step 1: Remove `StatusBarMenuCopy` static Chinese**

- [ ] **Step 2: Use `LocalizationManager` in `configureMenu` / `update`**

- [ ] **Step 3: Ensure tests use `performMenuItem(tag:)` not title**

- [ ] **Step 4: Add test: after `setLanguage(.en)`, menu titles are English**

- [ ] **Step 5: Commit**

### Task 10: Overlay and live feedback copy

**Files:**
- Modify: `GestureOverlayDisplaying.swift`
- Modify: `GestureOverlayWindow.swift` / coordinator if message resolved upstream
- Modify: `GestureEngine.swift` (only fixed user-visible strings, if any)

- [ ] **Step 1: Replace `GestureFeedbackCopy` with manager lookup at display time**

- [ ] **Step 2: On language change notification, refresh visible feedback card if shown**

- [ ] **Step 3: Update `GestureOverlayWindowTests` for localized unmatched string**

- [ ] **Step 4: Commit**

### Task 11: Core model display names (if user-visible)

**Files:**
- Modify: `GestureTargetApplication.swift`, `GestureDefinition.swift` — only if defaults are shown in UI

- [ ] **Step 1: Audit default gesture/target labels shown in picker**

- [ ] **Step 2: Localize defaults via keys; keep user overrides as-is**

- [ ] **Step 3: Commit**

---

## Chunk 6: Integration and gap fill

### Task 12: Language switch integration test

**Files:**
- Create or extend: `Tests/GestureFlowAppTests/Localization/AppLanguageSwitchTests.swift`

- [ ] **Step 1: Test save + `setLanguage(.en)` updates sidebar + status bar without restart**

- [ ] **Step 2: Full suite `swift test`**

- [ ] **Step 3: Commit**

```bash
git commit -m "test: verify language switch refreshes UI immediately"
```

### Task 13: Final audit

- [ ] **Step 1: Grep `Sources` for `"[\u4e00-\u9fff]` — remaining literals must be user content, logs, or Picker fixed labels**

- [ ] **Step 2: Update default `config.yaml` fixture in tests if samples omit `general`**

- [ ] **Step 3: Final commit if audit fixes needed**

---

## Verification Checklist

- [ ] General settings: **应用语言** row below gesture recognition, above config directory
- [ ] Switch to English: sidebar, general rows, menu bar, overlay unmatched text change immediately
- [ ] Restart app: language persists from YAML
- [ ] Invalid YAML language → falls back to Chinese
- [ ] User gesture names unchanged when switching language
