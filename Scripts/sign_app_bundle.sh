#!/usr/bin/env bash
#
# Sign a .app bundle with a stable self-signed identity.
#
# Usage:
#   Scripts/sign_app_bundle.sh path/to/GestureFlow.app
#
# Env (optional — for CI or one-off import):
#   MACOS_CERTIFICATE       base64-encoded .p12
#   MACOS_CERTIFICATE_PWD   .p12 password
#   MACOS_SIGNING_IDENTITY  cert common name (default: GestureFlow Self-Signed)
#   KEYCHAIN_PASSWORD       temp keychain password when importing MACOS_CERTIFICATE
#
set -euo pipefail

APP_PATH="${1:?usage: $0 path/to/App.app}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENTITLEMENTS="${ENTITLEMENTS:-${REPO_ROOT}/Resources/GestureFlow.entitlements}"
SIGNING_IDENTITY="${MACOS_SIGNING_IDENTITY:-GestureFlow Self-Signed}"

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app bundle not found: $APP_PATH" >&2
    exit 1
fi

if [[ "$(basename "$APP_PATH")" != *.app ]]; then
    echo "error: expected a .app bundle: $APP_PATH" >&2
    exit 1
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
    echo "error: entitlements file not found: $ENTITLEMENTS" >&2
    exit 1
fi

TEMP_KEYCHAIN=""
cleanup() {
    if [[ -n "$TEMP_KEYCHAIN" && -f "$TEMP_KEYCHAIN" ]]; then
        security delete-keychain "$TEMP_KEYCHAIN" >/dev/null 2>&1 || true
    fi
    rm -f certificate.p12
}
trap cleanup EXIT

import_certificate_to_keychain() {
    local keychain_path="$1"
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$keychain_path"
    security default-keychain -s "$keychain_path"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$keychain_path"
    security set-keychain-settings -lut 21600 "$keychain_path"
    echo "$MACOS_CERTIFICATE" | base64 --decode > certificate.p12
    security import certificate.p12 -k "$keychain_path" \
        -P "$MACOS_CERTIFICATE_PWD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -s -k "$KEYCHAIN_PASSWORD" "$keychain_path"
    TEMP_KEYCHAIN="$keychain_path"
}

sign_bundle() {
    local identity="$1"
    echo "Signing with identity: $identity"

    local executable_name
    executable_name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP_PATH/Contents/Info.plist")"
    local executable_path="$APP_PATH/Contents/MacOS/$executable_name"

    if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
        for framework in "$APP_PATH/Contents/Frameworks/"*.framework; do
            [[ -d "$framework" ]] || continue
            local framework_name framework_binary
            framework_name="$(basename "$framework" .framework)"
            framework_binary="$framework/Versions/A/$framework_name"
            if [[ -f "$framework_binary" ]]; then
                codesign --force --options runtime --sign "$identity" "$framework_binary"
            fi
            codesign --force --options runtime --sign "$identity" "$framework"
        done
    fi

    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$identity" \
        "$executable_path"
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$identity" \
        "$APP_PATH"
    codesign --verify --strict --verbose=2 "$APP_PATH"
}

can_sign_with_identity() {
    local identity="$1"
    local probe
    probe="$(mktemp)"
    cp /bin/ls "$probe"
    if codesign -s "$identity" -f --dryrun "$probe" >/dev/null 2>&1; then
        rm -f "$probe"
        return 0
    fi
    rm -f "$probe"
    return 1
}

if [[ -n "${MACOS_CERTIFICATE:-}" ]]; then
    : "${MACOS_CERTIFICATE_PWD:?MACOS_CERTIFICATE_PWD is required when MACOS_CERTIFICATE is set}"
    : "${KEYCHAIN_PASSWORD:?KEYCHAIN_PASSWORD is required when MACOS_CERTIFICATE is set}"
    import_certificate_to_keychain "$(mktemp -u "${TMPDIR:-/tmp}/gestureflow-signing.XXXXXX")"
    sign_bundle "$SIGNING_IDENTITY"
elif can_sign_with_identity "$SIGNING_IDENTITY"; then
    sign_bundle "$SIGNING_IDENTITY"
elif [[ "${REQUIRE_SIGNING:-0}" == "1" ]]; then
    echo "error: signing identity '$SIGNING_IDENTITY' not found and REQUIRE_SIGNING=1" >&2
    exit 1
else
    echo "warning: signing identity '$SIGNING_IDENTITY' not found in keychain" >&2
    echo "warning: falling back to ad-hoc signing — TCC grants will not persist across updates." >&2
    echo "warning: run Scripts/generate-signing-cert.sh and import the .p12, or set MACOS_CERTIFICATE." >&2
    codesign --force --deep --options runtime --sign - "$APP_PATH" || true
fi
