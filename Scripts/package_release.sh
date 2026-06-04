#!/usr/bin/env bash
#
# Build, sign, and package a versioned release (zip + dmg + checksums).
#
# Usage:
#   Scripts/package_release.sh <version>
#
# Example:
#   MACOS_CERTIFICATE=... REQUIRE_SIGNING=1 Scripts/package_release.sh 0.2.0
#
set -euo pipefail

VERSION="${1:?usage: $0 <version>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="GestureFlow"
APP_BUNDLE="${REPO_ROOT}/build/${APP_NAME}.app"
DIST_DIR="${REPO_ROOT}/dist"

export MARKETING_VERSION="${VERSION}"
export BUILD_UNIVERSAL=1
export REQUIRE_SIGNING="${REQUIRE_SIGNING:-1}"

"${SCRIPT_DIR}/package_app.sh"

ARTIFACT="${APP_NAME}-${VERSION}-macos.zip"
DMG_ARTIFACT="${APP_NAME}-${VERSION}-macos.dmg"

mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${ARTIFACT}" "${DIST_DIR}/${ARTIFACT}.sha256"
rm -f "${DIST_DIR}/${DMG_ARTIFACT}" "${DIST_DIR}/${DMG_ARTIFACT}.sha256"

ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${DIST_DIR}/${ARTIFACT}"
SHA256="$(shasum -a 256 "${DIST_DIR}/${ARTIFACT}" | awk '{print $1}')"
printf '%s %s\n' "${SHA256}" "${ARTIFACT}" > "${DIST_DIR}/${ARTIFACT}.sha256"

"${SCRIPT_DIR}/create-dmg.sh" "${APP_BUNDLE}" "${DIST_DIR}/${DMG_ARTIFACT}" "${APP_NAME}"
DMG_SHA256="$(shasum -a 256 "${DIST_DIR}/${DMG_ARTIFACT}" | awk '{print $1}')"
printf '%s %s\n' "${DMG_SHA256}" "${DMG_ARTIFACT}" > "${DIST_DIR}/${DMG_ARTIFACT}.sha256"

ls -lh "${DIST_DIR}/${ARTIFACT}" "${DIST_DIR}/${ARTIFACT}.sha256" \
    "${DIST_DIR}/${DMG_ARTIFACT}" "${DIST_DIR}/${DMG_ARTIFACT}.sha256"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "version=${VERSION}"
        echo "artifact_name=${ARTIFACT}"
        echo "artifact_sha256=${SHA256}"
        echo "dmg_name=${DMG_ARTIFACT}"
        echo "dmg_sha256=${DMG_SHA256}"
    } >> "${GITHUB_OUTPUT}"
fi
