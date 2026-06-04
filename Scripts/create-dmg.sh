#!/usr/bin/env bash
# Create a draggable macOS DMG from an existing .app bundle.
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "usage: $0 <App.app> <output.dmg> [volume-name]" >&2
    exit 64
fi

APP_PATH="$1"
OUTPUT_DMG="$2"
VOLNAME="${3:-GestureFlow}"

if [ ! -d "$APP_PATH" ]; then
    echo "error: app bundle not found: $APP_PATH" >&2
    exit 1
fi

APP_BUNDLE="$(basename "$APP_PATH")"
if [[ "$APP_BUNDLE" != *.app ]]; then
    echo "error: expected a .app bundle, got: $APP_PATH" >&2
    exit 1
fi

OUTPUT_DIR="$(dirname "$OUTPUT_DMG")"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/gestureflow-dmg.XXXXXX")"
cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
cp -R "$APP_PATH" "$STAGE/$APP_BUNDLE"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUTPUT_DMG"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$OUTPUT_DMG" >/dev/null

echo "Created DMG: $OUTPUT_DMG"
