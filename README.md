# GestureFlow

GestureFlow is a native macOS menu bar utility for mouse gestures. The current
MVP focuses on right-button gesture capture, gesture matching, visual feedback,
local configuration, and a small set of built-in actions.

## Requirements

- macOS 14.0 or later
- Xcode 26 or newer
- Swift 5.9 toolchain

## Project Structure

- `GestureFlowCore`: shared gesture models, recognition, matching, validation,
  and configuration storage
- `GestureFlowApp`: macOS menu bar application, permissions flow, event tap,
  overlay, settings, and action execution

## Open In Xcode

Open the standard macOS app project:

```bash
open GestureFlow.xcodeproj
```

Primary local workflow:

- Run the `GestureFlowApp` scheme from Xcode
- Test from Xcode's Test action
- Use `xcodebuild` for command-line validation

## Build

Build the app with Xcode:

```bash
xcodebuild -project GestureFlow.xcodeproj -scheme GestureFlowApp -sdk macosx build
```

## Run

Run the menu bar app from Xcode, or build and launch the packaged bundle:

```bash
Scripts/package_app.sh
open build/GestureFlow.app
```

On first launch, macOS should show a permissions guide or prompt for
Accessibility access. The app needs Accessibility permission to observe global
mouse events and trigger actions.

## Swift Package Compatibility

The repository still supports Swift Package Manager for compatibility checks:

```bash
swift build
swift test
```

These commands are no longer the primary desktop app workflow.

## Package A Local App Bundle

Build and sign a release `.app` with a **stable self-signed certificate** so
macOS privacy permissions (Accessibility, etc.) survive updates:

```bash
# One-time: generate and import the signing certificate
Scripts/generate-signing-cert.sh ~/Desktop
security import ~/Desktop/gestureflow-signing.p12 \
  -k ~/Library/Keychains/login.keychain-db \
  -P gestureflow \
  -T /usr/bin/codesign

# Build + sign
Scripts/package_app.sh
open build/GestureFlow.app
```

The script builds the release app and creates:

```text
build/GestureFlow.app
```

Signing identity (fixed CN): `GestureFlow Self-Signed`. Override with
`MACOS_SIGNING_IDENTITY`. If the identity is missing from your keychain,
`package_app.sh` falls back to ad-hoc signing and prints a warning.

For CI, set GitHub Actions secrets `MACOS_CERTIFICATE` (base64 `.p12`),
`MACOS_CERTIFICATE_PWD`, `MACOS_SIGNING_IDENTITY`, and `KEYCHAIN_PASSWORD`.
See `Scripts/generate-signing-cert.sh` for details.

You can launch the packaged bundle with Finder or:

```bash
open build/GestureFlow.app
```

## Release (GitHub Actions)

Push a version tag to trigger a signed universal build, zip/dmg artifacts, and
GitHub Release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Required repository secrets:

| Secret | Description |
|--------|-------------|
| `MACOS_CERTIFICATE` | Base64 of `gestureflow-signing.p12` |
| `MACOS_CERTIFICATE_PWD` | `.p12` export password |
| `MACOS_SIGNING_IDENTITY` | `GestureFlow Self-Signed` |
| `KEYCHAIN_PASSWORD` | Any throwaway string for CI keychain |

Local dry run of the release packager:

```bash
Scripts/package_release.sh 0.1.0
```

Outputs land in `dist/`:

```text
dist/GestureFlow-0.1.0-macos.zip
dist/GestureFlow-0.1.0-macos.dmg
```

Add release notes under the matching `## [version]` heading in `CHANGELOG.md`.

## Accessibility Setup

1. Launch GestureFlow.
2. Open `System Settings > Privacy & Security > Accessibility`.
3. Enable GestureFlow in the app list.
4. If the app does not appear yet, relaunch it and trigger the permission
   prompt again from the in-app guide.

Without Accessibility permission, gesture capture stays disabled.

## Engineering Notes

- Mouse input troubleshooting and root-cause notes:
  [mouse-input-troubleshooting.md](file:///Users/bytedance/Projects/GestureFlow/docs/mouse-input-troubleshooting.md)

## Validation

Useful local validation commands:

```bash
Scripts/validate_xcode_and_spm.sh
Scripts/package_app.sh
open build/GestureFlow.app
```

## MVP Limitations

- Release packaging uses a reusable self-signed certificate (not Developer ID /
  notarization). Gatekeeper may still prompt on first launch.
- GitHub Releases ship zip + dmg; notarization is not configured yet.
- Trackpad gesture support is deferred; the MVP focuses on mouse gestures.
- Action coverage is intentionally limited to built-in shortcuts, app launch,
  URL open, and a small set of system commands.
- Some behaviors still depend on macOS permission state and current hardware.
