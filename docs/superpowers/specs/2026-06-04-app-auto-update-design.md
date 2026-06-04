# App Auto-Update Design

**Goal**

Add **检查更新** and **自动更新** controls to the About settings page. When automatic updates are enabled, check for new versions every 7 days (on launch and via a repeating timer while the app runs). Use the GitHub Releases API to locate the latest release, then delegate download, install, and restart to **Sparkle** with its default UI.

**Repository:** https://github.com/sunyongsheng/GestureFlow

**Out Of Scope**

- Custom SwiftUI update dialogs (Sparkle default UI only).
- Storing auto-update preference in `config.yaml` / `AppConfiguration`.
- Delta updates or in-place patch installs beyond Sparkle’s standard zip flow.
- Windows/Linux update support.
- Private GitHub releases or authenticated API access.
- Auto-download without user confirmation (Sparkle shows its standard prompt).

## Confirmed Requirements

| Topic | Decision |
| --- | --- |
| Update framework | **Sparkle** for UI, download, signature verification, install, restart |
| Version discovery | **GitHub Releases API** `GET /repos/sunyongsheng/GestureFlow/releases/latest` |
| About page UI | Toggle (auto update) + Button (check for updates) |
| Auto-update interval | **7 days** |
| Auto-check triggers | **App launch** (if interval elapsed) + **repeating Timer** while running |
| Preference storage | **UserDefaults** (`automaticUpdateEnabled`, `lastUpdateCheckDate`) |
| Manual check | Always available; **not** gated by 7-day interval |
| Update UI | **Sparkle default** |
| Release artifact | `GestureFlow-{version}-macos.zip` + **`appcast.xml`** (CI-generated, signed) |
| DEBUG builds | Skip scheduled checks; manual button disabled or shows dev-unavailable message |

## Architecture

### Component Overview

```
GestureFlowApplication
  ├── AppUpdateController          # Sparkle SPUStandardUpdaterController wrapper
  ├── UpdateScheduler              # Launch check + 7-day repeating Timer
  └── makeSettingsViewModel()      # Injects update actions

GestureFlowApp/Services/
  ├── GitHubReleaseClient          # Fetch latest release JSON; resolve appcast URL
  ├── UpdatePreferencesStore       # UserDefaults read/write
  └── AppUpdateController          # Dynamic feedURL + trigger Sparkle

GestureFlowCore/
  └── SemanticVersion              # Parse/compare semver (testable, no AppKit)

SettingsViewModel
  ├── isAutomaticUpdateEnabled
  ├── setAutomaticUpdateEnabled(_:)
  └── checkForUpdates()

AboutSettingsView(viewModel:)
  ├── Auto-update Toggle
  └── Check for Updates Button
```

### Sparkle Configuration

Add Sparkle via SPM to `Package.swift` and mirror in `GestureFlow.xcodeproj`.

**Info.plist keys:**

| Key | Value |
| --- | --- |
| `SUPublicEDKey` | EdDSA public key from `generate_keys` |
| `SUFeedURL` | Placeholder URL (overridden before each check) |

Disable Sparkle’s built-in automatic scheduling (`automaticallyChecksForUpdates = false`). The app owns the 7-day schedule via `UpdateScheduler`.

### GitHub Release Contract

**Tag format:** `release/vX.Y.Z` (existing CI convention).

**Required release assets:**

| Asset | Purpose |
| --- | --- |
| `GestureFlow-{version}-macos.zip` | Sparkle enclosure |
| `appcast.xml` | Sparkle feed with edDSA signature and enclosure metadata |

**API parsing:**

1. `GET https://api.github.com/repos/sunyongsheng/GestureFlow/releases/latest`
2. Strip `release/v` prefix from `tag_name` → semver string
3. Find asset named `appcast.xml` → `browser_download_url`
4. Set Sparkle `feedURL` to that URL
5. Call `checkForUpdates(_:)`

Send `User-Agent: GestureFlow/{version}` on API requests (GitHub requirement).

Draft and prerelease releases are excluded by the `releases/latest` endpoint.

### Update Check Flow

**Manual (About → Check for Updates):**

1. `GitHubReleaseClient.fetchLatestRelease()`
2. Resolve `appcast.xml` URL from assets
3. `AppUpdateController.checkForUpdates(appcastURL:)` → Sparkle UI
4. Record `lastUpdateCheckDate`

**Automatic (toggle ON):**

1. On launch: if `Date.now - lastUpdateCheckDate ≥ 7 days`, run manual flow silently (no pre-alert)
2. Start `Timer` with `7 * 24 * 60 * 60` second interval, `repeats: true`
3. On toggle OFF: invalidate timer; do not run scheduled checks
4. On toggle ON: persist preference, run launch check if due, (re)start timer

**Version comparison:** Sparkle reads `appcast.xml` and decides whether an update is needed. GitHub API is used to locate the **current** release feed URL, not as the sole authority for “is newer”.

### About Page UI

Extend `AboutSettingsView` inside the existing `SettingsCard`, below the version row:

| Control | Pattern |
| --- | --- |
| Auto-update | `SettingsValueRow` + `.toggleStyle(.switch)` |
| Check for updates | Secondary button (same family as General accessibility button) |

`MainSettingsView` passes `viewModel` into `AboutSettingsView(viewModel:)`.

**New L10n keys** (all 8 language tables):

- `aboutAutomaticUpdateTitle` / `aboutAutomaticUpdateDescription`
- `aboutCheckForUpdatesButton`
- `aboutUpdateUnavailableInDevelopment`

### Preference Storage

**`UpdatePreferencesStore`** (UserDefaults):

| Key | Type | Default |
| --- | --- | --- |
| `automaticUpdateEnabled` | `Bool` | `false` |
| `lastUpdateCheckDate` | `Date?` | `nil` |

Separate from `config.yaml`; does not relocate with configuration directory changes.

### Release CI Changes

Extend `.github/workflows/release.yml` after `Scripts/package_release.sh`:

1. Fetch Sparkle release tools (`sign_update`, `generate_appcast`) or vendor from Sparkle repo
2. Sign `GestureFlow-{version}-macos.zip` with `SPARKLE_PRIVATE_KEY` (GitHub Secret)
3. Generate `appcast.xml` pointing enclosure URL to the GitHub Release download URL
4. Upload `appcast.xml` alongside zip/dmg in the GitHub Release

**One-time setup (documented in README or internal release doc):**

```bash
./Sparkle/bin/generate_keys
# Public key → Info.plist SUPublicPublicEDKey
# Private key → GitHub Secret SPARKLE_PRIVATE_KEY
```

### Error Handling

| Scenario | Behavior |
| --- | --- |
| No network (automatic) | Silent skip; retry on next 7-day trigger |
| No network (manual) | Sparkle standard error UI |
| Missing `appcast.xml` asset | Log error; manual check shows Sparkle failure |
| Malformed `tag_name` | Skip release; log warning |
| DEBUG build | No scheduler; manual button shows localized dev-unavailable message |
| App not in `/Applications` | Sparkle standard “move to Applications” guidance |

Automatic checks never show error alerts; only Sparkle UI on manual check or when automatic check finds an update and Sparkle prompts the user.

## Testing

| Layer | Coverage |
| --- | --- |
| `GestureFlowCoreTests` | `SemanticVersion` parse (`release/v1.2.3`), compare (`0.1.1` vs `0.2.0`) |
| `GestureFlowAppTests` | `GitHubReleaseClient` JSON fixture parsing; `UpdatePreferencesStore`; `UpdateScheduler` 7-day gate; `SettingsViewModel` injected update actions |
| Manual / E2E | Full Sparkle install flow against a test release (not automated) |

## Dependencies

- [Sparkle](https://github.com/sparkle-project/Sparkle) (SPM + Xcode project)
- Existing release pipeline (`Scripts/package_release.sh`, `release/v*` tags)

## Related Files (implementation touchpoints)

| File | Change |
| --- | --- |
| `Package.swift` | Add Sparkle dependency |
| `GestureFlow.xcodeproj/project.pbxproj` | Link Sparkle |
| `Resources/Info.plist` | `SUPublicEDKey`, `SUFeedURL` |
| `.github/workflows/release.yml` | Sign zip, generate/upload appcast |
| `Sources/GestureFlowApp/Settings/About/AboutSettingsView.swift` | Toggle + button |
| `Sources/GestureFlowApp/Settings/MainSettingsView.swift` | Pass viewModel to About |
| `Sources/GestureFlowApp/Settings/SettingsViewModel.swift` | Update state + actions |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Wire services, scheduler |
| `Sources/GestureFlowApp/Localization/*` | New L10n keys |
