# App Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add About-page **检查更新** button and **自动更新** toggle; check GitHub Releases every 7 days when enabled; use Sparkle default UI for download and restart install.

**Architecture:** `GitHubReleaseClient` resolves the latest release's `appcast.xml` URL via GitHub API; `AppUpdateController` sets Sparkle `feedURL` and calls `checkForUpdates`; `UpdateScheduler` runs launch + 7-day timer checks when auto-update is on; preferences live in UserDefaults via `UpdatePreferencesStore`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, Sparkle 2.x (SPM), GitHub REST API, existing release CI.

**Spec:** `docs/superpowers/specs/2026-06-04-app-auto-update-design.md`

---

## File Map

| File | Responsibility |
| --- | --- |
| `Sources/GestureFlowCore/Models/SemanticVersion.swift` | Create — parse/compare semver strings |
| `Sources/GestureFlowApp/Services/GitHubReleaseClient.swift` | Create — fetch latest release, resolve appcast URL |
| `Sources/GestureFlowApp/Services/UpdatePreferencesStore.swift` | Create — UserDefaults for toggle + last check date |
| `Sources/GestureFlowApp/Services/UpdateScheduler.swift` | Create — 7-day launch + timer scheduling |
| `Sources/GestureFlowApp/Services/AppUpdateController.swift` | Create — Sparkle wrapper, dynamic feedURL |
| `Sources/GestureFlowApp/Settings/About/AboutSettingsView.swift` | Toggle + check button |
| `Sources/GestureFlowApp/Settings/MainSettingsView.swift` | Pass `viewModel` to About |
| `Sources/GestureFlowApp/Settings/SettingsViewModel.swift` | Update state + injected actions |
| `Sources/GestureFlowApp/App/GestureFlowApplication.swift` | Wire services, start scheduler |
| `Sources/GestureFlowApp/Localization/L10nKey.swift` | New about-update keys |
| `Sources/GestureFlowApp/Localization/Tables/L10nStrings*.swift` | Translations (8 tables) |
| `Package.swift` | Sparkle SPM dependency |
| `GestureFlow.xcodeproj/project.pbxproj` | Link Sparkle in Xcode target |
| `Resources/Info.plist` | `SUPublicEDKey`, `SUFeedURL` placeholder |
| `.github/workflows/release.yml` | Sign zip, generate/upload `appcast.xml` |
| `Tests/GestureFlowCoreTests/SemanticVersionTests.swift` | Create |
| `Tests/GestureFlowAppTests/Services/GitHubReleaseClientTests.swift` | Create |
| `Tests/GestureFlowAppTests/Services/UpdatePreferencesStoreTests.swift` | Create |
| `Tests/GestureFlowAppTests/Services/UpdateSchedulerTests.swift` | Create |
| `Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift` | Extend update tests |

---

## Chunk 1: Core version parsing

### Task 1: `SemanticVersion`

**Files:**
- Create: `Sources/GestureFlowCore/Models/SemanticVersion.swift`
- Create: `Tests/GestureFlowCoreTests/SemanticVersionTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import GestureFlowCore

final class SemanticVersionTests: XCTestCase {
    func testParsesPlainVersion() throws {
        let version = try SemanticVersion(parsing: "1.2.3")
        XCTAssertEqual(version.major, 1)
        XCTAssertEqual(version.minor, 2)
        XCTAssertEqual(version.patch, 3)
    }

    func testParsesReleaseTagPrefix() throws {
        let version = try SemanticVersion(parsing: "release/v0.1.1")
        XCTAssertEqual(version.description, "0.1.1")
    }

    func testCompareOrdersVersions() throws {
        let older = try SemanticVersion(parsing: "0.1.1")
        let newer = try SemanticVersion(parsing: "0.2.0")
        XCTAssertTrue(older < newer)
        XCTAssertFalse(newer < older)
    }

    func testInvalidStringThrows() {
        XCTAssertThrowsError(try SemanticVersion(parsing: "not-a-version"))
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --filter SemanticVersionTests`

- [ ] **Step 3: Implement `SemanticVersion`**

```swift
public struct SemanticVersion: Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var description: String { "\(major).\(minor).\(patch)" }

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(parsing rawValue: String) throws {
        let trimmed = rawValue.hasPrefix("release/v")
            ? String(rawValue.dropFirst("release/v".count))
            : rawValue.hasPrefix("v") ? String(rawValue.dropFirst()) : rawValue
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else {
            throw SemanticVersionParseError.invalidFormat(rawValue)
        }
        self.init(major: major, minor: minor, patch: patch)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `swift test --filter SemanticVersionTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/GestureFlowCore/Models/SemanticVersion.swift Tests/GestureFlowCoreTests/SemanticVersionTests.swift
git commit -m "feat(core): add SemanticVersion for release tag parsing"
```

---

## Chunk 2: GitHub release client

### Task 2: `GitHubReleaseClient`

**Files:**
- Create: `Sources/GestureFlowApp/Services/GitHubReleaseClient.swift`
- Create: `Tests/GestureFlowAppTests/Services/GitHubReleaseClientTests.swift`

- [ ] **Step 1: Define models and protocol**

```swift
struct GitHubReleaseInfo: Equatable {
    let tagName: String
    let version: SemanticVersion
    let appcastURL: URL
}

protocol GitHubReleaseFetching {
    func fetchLatestRelease() async throws -> GitHubReleaseInfo
}

enum GitHubReleaseClientError: Error, Equatable {
    case invalidResponse
    case missingAppcastAsset
    case invalidTagName(String)
}

final class GitHubReleaseClient: GitHubReleaseFetching {
    static let repository = "sunyongsheng/GestureFlow"
    static let appcastAssetName = "appcast.xml"

    private let session: URLSession
    private let currentAppVersion: String

    init(session: URLSession = .shared, currentAppVersion: String) { ... }

    func fetchLatestRelease() async throws -> GitHubReleaseInfo { ... }
}
```

Parse JSON fields: `tag_name`, `assets[].name`, `assets[].browser_download_url`.

Request URL: `https://api.github.com/repos/sunyongsheng/GestureFlow/releases/latest`

Set header: `User-Agent: GestureFlow/\(currentAppVersion)`.

- [ ] **Step 2: Write failing tests with fixture JSON**

```swift
func testParsesLatestReleaseFixture() async throws {
    let fixture = """
    {
      "tag_name": "release/v0.2.0",
      "assets": [
        { "name": "GestureFlow-0.2.0-macos.zip", "browser_download_url": "https://example.com/app.zip" },
        { "name": "appcast.xml", "browser_download_url": "https://example.com/appcast.xml" }
      ]
    }
    """.data(using: .utf8)!
    let client = GitHubReleaseClient(session: MockURLSession(data: fixture), currentAppVersion: "0.1.1")
    let release = try await client.fetchLatestRelease()
    XCTAssertEqual(release.version.description, "0.2.0")
    XCTAssertEqual(release.appcastURL.absoluteString, "https://example.com/appcast.xml")
}

func testMissingAppcastThrows() async { ... }
```

- [ ] **Step 3: Run tests — expect FAIL**

Run: `swift test --filter GitHubReleaseClientTests`

- [ ] **Step 4: Implement client + test URLSession mock**

- [ ] **Step 5: Run tests — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add Sources/GestureFlowApp/Services/GitHubReleaseClient.swift Tests/GestureFlowAppTests/Services/
git commit -m "feat(app): add GitHubReleaseClient for latest release lookup"
```

---

## Chunk 3: Preferences and scheduler

### Task 3: `UpdatePreferencesStore`

**Files:**
- Create: `Sources/GestureFlowApp/Services/UpdatePreferencesStore.swift`
- Create: `Tests/GestureFlowAppTests/Services/UpdatePreferencesStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testAutomaticUpdateDefaultsToFalse() {
    let defaults = UserDefaults(suiteName: "test.update.\(UUID().uuidString)")!
    let store = UpdatePreferencesStore(defaults: defaults)
    XCTAssertFalse(store.isAutomaticUpdateEnabled)
}

func testPersistsAutomaticUpdateToggle() {
    let store = UpdatePreferencesStore(defaults: testDefaults)
    store.isAutomaticUpdateEnabled = true
    let reloaded = UpdatePreferencesStore(defaults: testDefaults)
    XCTAssertTrue(reloaded.isAutomaticUpdateEnabled)
}

func testLastCheckDateRoundTrip() { ... }
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement store**

Keys: `automaticUpdateEnabled` (Bool), `lastUpdateCheckDate` (Date as `timeIntervalSince1970`).

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(app): add UpdatePreferencesStore for auto-update settings"
```

### Task 4: `UpdateScheduler`

**Files:**
- Create: `Sources/GestureFlowApp/Services/UpdateScheduler.swift`
- Create: `Tests/GestureFlowAppTests/Services/UpdateSchedulerTests.swift`

- [ ] **Step 1: Write failing tests for 7-day gate**

```swift
func testShouldCheckWhenNeverCheckedBefore() {
    let scheduler = UpdateScheduler(interval: 7 * 24 * 60 * 60, now: { Date() })
    XCTAssertTrue(scheduler.shouldPerformCheck(lastCheckDate: nil))
}

func testShouldNotCheckWithinInterval() {
    let now = Date()
    let scheduler = UpdateScheduler(interval: 7 * 24 * 60 * 60, now: { now })
    let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: now)!
    XCTAssertFalse(scheduler.shouldPerformCheck(lastCheckDate: threeDaysAgo))
}

func testShouldCheckAfterInterval() {
    let now = Date()
    let scheduler = UpdateScheduler(interval: 7 * 24 * 60 * 60, now: { now })
    let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: now)!
    XCTAssertTrue(scheduler.shouldPerformCheck(lastCheckDate: eightDaysAgo))
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `UpdateScheduler`**

```swift
final class UpdateScheduler {
    static let defaultInterval: TimeInterval = 7 * 24 * 60 * 60

    private let interval: TimeInterval
    private let now: () -> Date
    private var timer: Timer?

    func shouldPerformCheck(lastCheckDate: Date?) -> Bool { ... }

    func startRepeating(onFire: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in onFire() }
    }

    func stop() { timer?.invalidate(); timer = nil }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(app): add UpdateScheduler with 7-day check interval"
```

---

## Chunk 4: Sparkle integration

### Task 5: Add Sparkle dependency

**Files:**
- Modify: `Package.swift`
- Modify: `GestureFlow.xcodeproj/project.pbxproj`
- Modify: `Resources/Info.plist`

- [ ] **Step 1: Add Sparkle to `Package.swift`**

```swift
dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
],
// GestureFlowApp target:
dependencies: [
    "GestureFlowCore",
    .product(name: "Sparkle", package: "Sparkle")
],
linkerSettings: [
    // existing...
    .linkedFramework("Sparkle")
]
```

- [ ] **Step 2: Add Sparkle package reference in Xcode project**

Open Xcode or mirror Yams pattern in `project.pbxproj`: add `XCRemoteSwiftPackageReference` for Sparkle, link `Sparkle` product to `GestureFlowApp` target.

- [ ] **Step 3: Update Info.plist**

```xml
<key>SUFeedURL</key>
<string>https://github.com/sunyongsheng/GestureFlow</string>
<key>SUPublicEDKey</key>
<string>REPLACE_WITH_GENERATED_PUBLIC_KEY</string>
```

Use placeholder public key until release keys are generated; document in README that first release maintainer must run `generate_keys`.

- [ ] **Step 4: Verify build**

Run: `Scripts/validate_xcode_and_spm.sh`

Expected: build succeeds (Sparkle linked).

- [ ] **Step 5: Commit**

```bash
git commit -m "build: add Sparkle dependency and Info.plist update keys"
```

### Task 6: `AppUpdateController`

**Files:**
- Create: `Sources/GestureFlowApp/Services/AppUpdateController.swift`

- [ ] **Step 1: Implement Sparkle wrapper**

```swift
import AppKit
import Sparkle

protocol AppUpdateControlling: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates(appcastURL: URL)
}

@MainActor
final class AppUpdateController: NSObject, AppUpdateControlling {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        updaterController.updater.automaticallyChecksForUpdates = false
        updaterController.updater.automaticallyDownloadsUpdates = false
    }

    var canCheckForUpdates: Bool {
        #if DEBUG
        return false
        #else
        return updaterController.updater.canCheckForUpdates
        #endif
    }

    func checkForUpdates(appcastURL: URL) {
        updaterController.updater.setFeedURL(appcastURL)
        updaterController.checkForUpdates(nil)
    }
}
```

- [ ] **Step 2: Verify compile**

Run: `xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlow -destination "platform=macOS" build`

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(app): add AppUpdateController Sparkle wrapper"
```

### Task 7: `AppUpdateService` orchestration

**Files:**
- Create: `Sources/GestureFlowApp/Services/AppUpdateService.swift`

- [ ] **Step 1: Compose client + controller + preferences**

```swift
@MainActor
final class AppUpdateService {
    private let releaseClient: GitHubReleaseFetching
    private let updateController: AppUpdateControlling
    private let preferencesStore: UpdatePreferencesStore

    func checkForUpdatesIfNeeded(force: Bool) async {
        guard force || preferencesStore.isAutomaticUpdateEnabled else { return }
        if !force {
            guard scheduler.shouldPerformCheck(lastCheckDate: preferencesStore.lastUpdateCheckDate) else { return }
        }
        preferencesStore.lastUpdateCheckDate = Date()
        do {
            let release = try await releaseClient.fetchLatestRelease()
            updateController.checkForUpdates(appcastURL: release.appcastURL)
        } catch {
            // automatic: silent; manual errors surface via Sparkle when feed unreachable
            if force { /* optionally log */ }
        }
    }
}
```

Wire `force: true` for manual button; `force: false` for scheduled checks.

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(app): add AppUpdateService orchestrating GitHub + Sparkle"
```

---

## Chunk 5: Settings UI and ViewModel

### Task 8: Localization keys

**Files:**
- Modify: `Sources/GestureFlowApp/Localization/L10nKey.swift`
- Modify: all `Sources/GestureFlowApp/Localization/Tables/L10nStrings*.swift` (8 files)

- [ ] **Step 1: Add keys**

```swift
case aboutAutomaticUpdateTitle
case aboutAutomaticUpdateDescription
case aboutCheckForUpdatesButton
case aboutUpdateUnavailableInDevelopment
```

- [ ] **Step 2: Add translations**

Example English:

```swift
.aboutAutomaticUpdateTitle: "Automatic Updates",
.aboutAutomaticUpdateDescription: "Check for updates every 7 days while GestureFlow is running.",
.aboutCheckForUpdatesButton: "Check for Updates",
.aboutUpdateUnavailableInDevelopment: "Updates are not available in development builds.",
```

Add zh-Hans, zh-Hant, ja, ko, fr, es, hi equivalents.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(l10n): add about-page update strings"
```

### Task 9: `SettingsViewModel` update API

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/SettingsViewModel.swift`
- Modify: `Tests/GestureFlowAppTests/Settings/Shell/SettingsViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
func testSetAutomaticUpdateEnabledPersistsViaAction() {
    var saved = false
    let viewModel = makeViewModel(
        isAutomaticUpdateEnabled: false,
        setAutomaticUpdateEnabled: { saved = $0 }
    )
    viewModel.setAutomaticUpdateEnabled(true)
    XCTAssertTrue(saved)
    XCTAssertTrue(viewModel.isAutomaticUpdateEnabled)
}

func testCheckForUpdatesInvokesAction() {
    var invoked = false
    let viewModel = makeViewModel(checkForUpdates: { invoked = true })
    viewModel.checkForUpdates()
    XCTAssertTrue(invoked)
}
```

- [ ] **Step 2: Add published state + injected closures**

```swift
@Published private(set) var isAutomaticUpdateEnabled: Bool
@Published private(set) var canCheckForUpdates: Bool

private let setAutomaticUpdateEnabledAction: (Bool) -> Void
private let checkForUpdatesAction: () -> Void

func setAutomaticUpdateEnabled(_ isEnabled: Bool) {
    setAutomaticUpdateEnabledAction(isEnabled)
    isAutomaticUpdateEnabled = isEnabled
}

func checkForUpdates() {
    checkForUpdatesAction()
}
```

- [ ] **Step 3: Run tests — expect PASS**

Run: `swift test --filter SettingsViewModelTests`

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(settings): expose auto-update state and actions on view model"
```

### Task 10: `AboutSettingsView` UI

**Files:**
- Modify: `Sources/GestureFlowApp/Settings/About/AboutSettingsView.swift`
- Modify: `Sources/GestureFlowApp/Settings/MainSettingsView.swift`

- [ ] **Step 1: Add viewModel parameter and update section**

```swift
struct AboutSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var l10n: LocalizationManager

    var body: some View {
        SettingsPage {
            SettingsCard(title: appName, description: nil) {
                VStack(alignment: .leading, spacing: 18) {
                    versionRow(...)
                    Divider()
                    SettingsValueRow(
                        title: l10n.string(.aboutAutomaticUpdateTitle),
                        description: l10n.string(.aboutAutomaticUpdateDescription),
                        statusText: nil
                    ) {
                        Toggle("", isOn: automaticUpdateBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    Divider()
                    Button(action: { viewModel.checkForUpdates() }) {
                        Text(l10n.string(.aboutCheckForUpdatesButton))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canCheckForUpdates)
                    #if DEBUG
                    Text(l10n.string(.aboutUpdateUnavailableInDevelopment))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    #endif
                }
            }
        }
    }
}
```

- [ ] **Step 2: Update `MainSettingsView`**

```swift
case .about:
    AboutSettingsView(viewModel: viewModel)
```

- [ ] **Step 3: Compile**

Run: `swift test --filter SettingsViewModelTests`

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(settings): add auto-update controls to About page"
```

---

## Chunk 6: App wiring

### Task 11: Wire in `GestureFlowApplication`

**Files:**
- Modify: `Sources/GestureFlowApp/App/GestureFlowApplication.swift`

- [ ] **Step 1: Create services in init**

```swift
private let updatePreferencesStore = UpdatePreferencesStore()
private let updateScheduler = UpdateScheduler()
private lazy var appUpdateService = AppUpdateService(
    releaseClient: GitHubReleaseClient(
        currentAppVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    ),
    updateController: AppUpdateController(),
    preferencesStore: updatePreferencesStore,
    scheduler: updateScheduler
)
```

- [ ] **Step 2: Start scheduler after launch**

In `applicationDidFinishLaunching` path (or existing startup hook):

```swift
if updatePreferencesStore.isAutomaticUpdateEnabled {
    Task { await appUpdateService.checkForUpdatesIfNeeded(force: false) }
    updateScheduler.startRepeating { [weak self] in
        Task { await self?.appUpdateService.checkForUpdatesIfNeeded(force: false) }
    }
}
```

- [ ] **Step 3: Inject into `makeSettingsViewModel`**

```swift
isAutomaticUpdateEnabled: updatePreferencesStore.isAutomaticUpdateEnabled,
canCheckForUpdates: appUpdateService.canCheckForUpdates,
setAutomaticUpdateEnabled: { [weak self] enabled in
    self?.updatePreferencesStore.isAutomaticUpdateEnabled = enabled
    if enabled {
        self?.updateScheduler.startRepeating { ... }
        Task { await self?.appUpdateService.checkForUpdatesIfNeeded(force: false) }
    } else {
        self?.updateScheduler.stop()
    }
},
checkForUpdates: { [weak self] in
    Task { await self?.appUpdateService.checkForUpdatesIfNeeded(force: true) }
},
```

- [ ] **Step 4: Run full test suite**

Run: `Scripts/validate_xcode_and_spm.sh`

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(app): wire update service, scheduler, and settings actions"
```

---

## Chunk 7: Release CI

### Task 12: Generate signed appcast in release workflow

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `README.md` (release maintainer section)

- [ ] **Step 1: Add Sparkle signing step after package**

```yaml
- name: Generate Sparkle appcast
  env:
    SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
  run: |
    set -euo pipefail
    VERSION="${{ steps.version.outputs.version }}"
    ZIP="dist/GestureFlow-${VERSION}-macos.zip"
    curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
    tar xf sparkle.tar.xz
    echo "$SPARKLE_PRIVATE_KEY" | base64 --decode > ed_private_key.pem
    ./Sparkle/bin/sign_update "$ZIP" -f ed_private_key.pem -o dist/sign_output.plist
    # Build appcast.xml from sign output + enclosure URL
    Scripts/generate_appcast.sh "$VERSION" "$ZIP" dist/appcast.xml
    rm -f ed_private_key.pem
```

- [ ] **Step 2: Create `Scripts/generate_appcast.sh`**

Script writes minimal appcast XML:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>GestureFlow</title>
    <item>
      <title>Version VERSION</title>
      <sparkle:version>VERSION</sparkle:version>
      <sparkle:shortVersionString>VERSION</sparkle:shortVersionString>
      <enclosure url="ENCLOSURE_URL" sparkle:edSignature="SIG" length="LENGTH" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

Enclosure URL: `https://github.com/sunyongsheng/GestureFlow/releases/download/release/v${VERSION}/GestureFlow-${VERSION}-macos.zip`

- [ ] **Step 3: Upload appcast in release assets**

Add `dist/appcast.xml` to `softprops/action-gh-release` files list.

- [ ] **Step 4: Document key generation in README**

```markdown
### Sparkle update signing (maintainers)

1. Download Sparkle and run `./Sparkle/bin/generate_keys`
2. Put public key in `Resources/Info.plist` → `SUPublicEDKey`
3. Base64-encode private key → GitHub Secret `SPARKLE_PRIVATE_KEY`
```

- [ ] **Step 5: Commit**

```bash
git commit -m "ci: generate signed Sparkle appcast on release"
```

---

## Chunk 8: Manual verification

### Task 13: End-to-end smoke test

- [ ] **Step 1: Generate Sparkle keys locally (maintainer)**

Run Sparkle `generate_keys`; update `Info.plist` with public key.

- [ ] **Step 2: Build Release app**

Run: `Scripts/package_release.sh 0.1.2-test`

- [ ] **Step 3: Publish test GitHub release** with zip + appcast (or use staging tag).

- [ ] **Step 4: Manual checks**

1. Install older version in `/Applications`
2. About → Check for Updates → Sparkle shows update
3. Download → Install and Relaunch
4. Enable auto-update → confirm scheduler starts (log or debugger)

- [ ] **Step 5: Final commit if any doc fixes**

```bash
git commit -m "docs: document Sparkle signing setup for releases"
```

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-04-app-auto-update.md`.

**Ready to execute?** Use subagent-driven-development (one task per subagent) or executing-plans in the current session.

**Prerequisite before first real release with updates:** Maintainer must generate Sparkle EdDSA keys and add `SPARKLE_PRIVATE_KEY` GitHub Secret.
