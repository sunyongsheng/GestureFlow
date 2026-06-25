#!/usr/bin/env bash
#
# Generate a Sparkle appcast.xml for a signed release zip.
#
# Usage:
#   Scripts/generate_appcast.sh <version> <zip-path> <ed-signature> <output-appcast-path> [release-notes-file]
#
# <ed-signature> is the base64 EdDSA string from sign_update output.
# [release-notes-file] is an optional path to a Markdown file whose content will be
# embedded as HTML <description> so Sparkle displays it in the update dialog.
#
set -euo pipefail

VERSION="${1:?usage: $0 <version> <zip-path> <ed-signature> <output-appcast-path> [release-notes-file]}"
ZIP_PATH="${2:?}"
ED_SIGNATURE="${3:?}"
OUTPUT_PATH="${4:?}"
RELEASE_NOTES_FILE="${5:-}"

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

# Convert markdown bullet list to HTML for Sparkle's release notes viewer.
DESCRIPTION_BLOCK=""
if [[ -n "${RELEASE_NOTES_FILE}" && -s "${RELEASE_NOTES_FILE}" ]]; then
    HTML_ITEMS=""
    while IFS= read -r line; do
        # Strip leading "- " and convert to <li>
        item="${line#- }"
        if [[ -n "${item}" ]]; then
            HTML_ITEMS="${HTML_ITEMS}        <li>${item}</li>
"
        fi
    done < "${RELEASE_NOTES_FILE}"

    if [[ -n "${HTML_ITEMS}" ]]; then
        DESCRIPTION_BLOCK="      <description><![CDATA[<ul>
${HTML_ITEMS}      </ul>]]></description>"
    fi
fi

{
    cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>GestureFlow</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${BUILD_VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
EOF
    if [[ -n "${DESCRIPTION_BLOCK}" ]]; then
        echo "${DESCRIPTION_BLOCK}"
    fi
    cat <<EOF
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
} > "${OUTPUT_PATH}"

echo "Wrote ${OUTPUT_PATH}"
