#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="GestureFlow"
SCHEME_NAME="GestureFlow"
BUILD_CONFIGURATION="Release"
OUTPUT_ROOT="${REPO_ROOT}/build"
APP_BUNDLE="${OUTPUT_ROOT}/${APP_NAME}.app"
DERIVED_DATA_ROOT="${OUTPUT_ROOT}/DerivedData"
BUILT_APP_BUNDLE="${DERIVED_DATA_ROOT}/Build/Products/${BUILD_CONFIGURATION}/${APP_NAME}.app"
PROJECT_PATH="${REPO_ROOT}/GestureFlow.xcodeproj"

if [[ ! -d "${PROJECT_PATH}" ]]; then
    echo "Missing Xcode project: ${PROJECT_PATH}" >&2
    exit 1
fi

echo "Building ${SCHEME_NAME} (${BUILD_CONFIGURATION}) with xcodebuild..."
rm -rf "${DERIVED_DATA_ROOT}"
xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${BUILD_CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_ROOT}" \
    build >/dev/null

echo "Creating app bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
cp -R "${BUILT_APP_BUNDLE}" "${APP_BUNDLE}"

echo "Validating bundle metadata..."
plutil -lint "${APP_BUNDLE}/Contents/Info.plist" >/dev/null

echo "Packaged app bundle:"
echo "  ${APP_BUNDLE}"
