#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../Config"
LOCAL="${CONFIG_DIR}/Local.xcconfig"
EXAMPLE="${CONFIG_DIR}/Local.xcconfig.example"

if [[ -f "${LOCAL}" ]]; then
    echo "Config/Local.xcconfig already exists."
    exit 0
fi

cp "${EXAMPLE}" "${LOCAL}"
echo "Created Config/Local.xcconfig"
echo "Uncomment signing overrides in that file if you want Developer signing instead of ad-hoc."
