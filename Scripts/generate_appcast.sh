#!/usr/bin/env bash
#
# Generate a Sparkle appcast.xml for a signed release zip.
#
# Usage:
#   Scripts/generate_appcast.sh <version> <zip-path> <sign-output-file> <output-appcast-path>
#
# The sign-output-file is the plist written by Sparkle's sign_update (-o flag).
#
set -euo pipefail

VERSION="${1:?usage: $0 <version> <zip-path> <sign-output-file> <output-appcast-path>}"
ZIP_PATH="${2:?}"
SIGN_PLIST="${3:?}"
OUTPUT_PATH="${4:?}"

ARTIFACT_NAME="$(basename "${ZIP_PATH}")"
ZIP_LENGTH="$(wc -c < "${ZIP_PATH}" | tr -d ' ')"
ED_SIGNATURE="$(/usr/libexec/PlistBuddy -c 'Print edSignature' "${SIGN_PLIST}")"
ENCLOSURE_URL="https://github.com/sunyongsheng/GestureFlow/releases/download/release/v${VERSION}/${ARTIFACT_NAME}"

cat > "${OUTPUT_PATH}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>GestureFlow</title>
    <item>
      <title>Version ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
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
