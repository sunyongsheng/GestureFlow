#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_PATH="${REPO_ROOT}/GestureFlow.xcodeproj"
SCHEME_NAME="GestureFlowApp"

echo "[1/4] xcodebuild build"
xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME_NAME}" \
    -sdk macosx \
    build >/dev/null

echo "[2/4] xcodebuild test"
xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME_NAME}" \
    -sdk macosx \
    test >/dev/null

echo "[3/4] swift build"
swift build --package-path "${REPO_ROOT}" >/dev/null

echo "[4/4] swift test"
swift test --package-path "${REPO_ROOT}" >/dev/null

echo "All build paths validated."
