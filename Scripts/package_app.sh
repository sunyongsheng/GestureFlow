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
MARKETING_VERSION="${MARKETING_VERSION:-}"
BUILD_UNIVERSAL="${BUILD_UNIVERSAL:-0}"

if [[ ! -d "${PROJECT_PATH}" ]]; then
    echo "Missing Xcode project: ${PROJECT_PATH}" >&2
    exit 1
fi

XCODEBUILD_ARGS=(
    -project "${PROJECT_PATH}"
    -scheme "${SCHEME_NAME}"
    -configuration "${BUILD_CONFIGURATION}"
    -derivedDataPath "${DERIVED_DATA_ROOT}"
    -destination "generic/platform=macOS"
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_ALLOWED=YES
)

if [[ -n "${MARKETING_VERSION}" ]]; then
    XCODEBUILD_ARGS+=(MARKETING_VERSION="${MARKETING_VERSION}")
fi

if [[ "${BUILD_UNIVERSAL}" == "1" ]]; then
    XCODEBUILD_ARGS+=(
        ARCHS="arm64 x86_64"
        ONLY_ACTIVE_ARCH=NO
    )
fi

echo "Building ${SCHEME_NAME} (${BUILD_CONFIGURATION}) with xcodebuild..."
rm -rf "${DERIVED_DATA_ROOT}"
xcodebuild "${XCODEBUILD_ARGS[@]}" build >/dev/null

echo "Creating app bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
cp -R "${BUILT_APP_BUNDLE}" "${APP_BUNDLE}"

echo "Validating bundle metadata..."
plutil -lint "${APP_BUNDLE}/Contents/Info.plist" >/dev/null

if [[ "${BUILD_UNIVERSAL}" == "1" ]]; then
    EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/GestureFlowApp"
    ARCHS="$(lipo -archs "${EXECUTABLE}")"
    echo "Binary archs: ${ARCHS}"
    case "${ARCHS}" in
        *arm64*x86_64* | *x86_64*arm64*) ;;
        *)
            echo "error: expected universal binary, got: ${ARCHS}" >&2
            exit 1
            ;;
    esac
fi

echo "Signing app bundle..."
"${SCRIPT_DIR}/sign_app_bundle.sh" "${APP_BUNDLE}"

echo "Packaged app bundle:"
echo "  ${APP_BUNDLE}"
