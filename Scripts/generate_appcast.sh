#!/usr/bin/env bash
#
# Generate a Sparkle appcast.xml for a signed release zip.
#
# Usage:
#   Scripts/generate_appcast.sh <version> <zip-path> <ed-signature> <output-appcast-path>
#
# <ed-signature> is the base64 EdDSA string from sign_update output.
#
set -euo pipefail

VERSION="${1:?usage: $0 <version> <zip-path> <ed-signature> <output-appcast-path>}"
ZIP_PATH="${2:?}"
ED_SIGNATURE="${3:?}"
OUTPUT_PATH="${4:?}"

ARTIFACT_NAME="$(basename "${ZIP_PATH}")"
ZIP_LENGTH="$(wc -c < "${ZIP_PATH}" | tr -d ' ')"
ENCLOSURE_URL="https://github.com/sunyongsheng/GestureFlow/releases/download/release/v${VERSION}/${ARTIFACT_NAME}"

# Sparkle compares sparkle:version against the host app's CFBundleVersion (build number),
# not CFBundleShortVersionString. Read the build number from the packaged app.
APP_NAME="GestureFlow"
BUILD_VERSION=""
if [[ -f "${ZIP_PATH}" ]]; then
    PLIST_DATA="$(unzip -p "${ZIP_PATH}" "${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -n "${PLIST_DATA}" ]]; then
        BUILD_VERSION="$(printf '%s' "${PLIST_DATA}" | plutil -extract CFBundleVersion raw - 2>/dev/null || true)"
    fi
fi
if [[ -z "${BUILD_VERSION}" ]]; then
    echo "error: could not read CFBundleVersion from ${ZIP_PATH}" >&2
    exit 1
fi

cat > "${OUTPUT_PATH}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>GestureFlow</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <enclosure
        url="${ENCLOSURE_URL}"
        sparkle:edSignature="${ED_SIGNATURE}"
        length="${ZIP_LENGTH}"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF

echo "Wrote ${OUTPUT_PATH}"
