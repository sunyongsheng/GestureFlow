# Changelog

All notable changes to GestureFlow are documented in this file.

## [0.2.3] - 2026-06-04

- Fix Sparkle falsely reporting “up to date” when a newer release exists: write `CFBundleVersion` to `sparkle:version` in `appcast.xml` and use `sparkle:shortVersionString` for marketing version checks.

## [0.2.2] - 2026-06-04

- Fetch the latest `appcast.xml` via GitHub release download URL instead of the REST API to avoid HTTP 403 rate limits.
- Allow **Check for Updates** in development builds (appcast check and alerts); Sparkle install remains disabled in Debug.

## [0.2.1] - 2026-06-04

- Fix manual **Check for Updates** on the About page: show a loading indicator, an up-to-date alert, and clear error messages when the GitHub release or appcast metadata is unavailable.

## [0.2.0] - 2026-06-04

- Add in-app updates on the About page: manual **Check for Updates** and an **Automatic Updates** toggle (checks every 7 days while the app is running).
- Discover new releases via the GitHub Releases API and install through Sparkle with the standard update UI.
- Generate a signed `appcast.xml` during the release CI workflow for update verification.

## [0.1.0] - 2026-06-03

- Initial public release workflow with self-signed distribution.
