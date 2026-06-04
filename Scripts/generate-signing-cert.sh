#!/usr/bin/env bash
#
# Generate a self-signed code-signing certificate for GestureFlow.
#
# macOS TCC (Accessibility, Input Monitoring, etc.) keys grants to an app's
# code-signing identity. Ad-hoc signatures have no stable identity, so users
# must re-authorize on every build/update. One reusable self-signed certificate
# keeps a stable Designated Requirement across releases.
#
# This is NOT a Developer ID certificate — Gatekeeper may still warn about an
# unidentified developer on first launch.
#
# Run once, back up the .p12, and reuse it for every release. Regenerating
# forces users to re-authorize permissions one more time.
#
# Usage:
#   Scripts/generate-signing-cert.sh [output_dir]
#
# Env:
#   CERT_PASSWORD   password protecting the .p12 (default: gestureflow)
#   CERT_NAME       certificate common name (default: GestureFlow Self-Signed)
#   CERT_DAYS       validity in days (default: 3650 — ~10 years)
#
set -euo pipefail

OUT_DIR="${1:-$HOME/Desktop}"
CERT_NAME="${CERT_NAME:-GestureFlow Self-Signed}"
CERT_PASSWORD="${CERT_PASSWORD:-gestureflow}"
CERT_DAYS="${CERT_DAYS:-3650}"

mkdir -p "$OUT_DIR"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[dn]
CN = $CERT_NAME

[v3]
basicConstraints   = critical, CA:false
keyUsage           = critical, digitalSignature
extendedKeyUsage   = critical, codeSigning
EOF

echo "==> generating RSA key + self-signed cert ($CERT_DAYS days)"
openssl req -x509 -newkey rsa:2048 -sha256 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -days "$CERT_DAYS" -nodes -config "$WORK/cert.cnf" >/dev/null 2>&1

P12="$OUT_DIR/gestureflow-signing.p12"
echo "==> bundling into $P12"
openssl pkcs12 -export -legacy \
    -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$CERT_NAME" -out "$P12" \
    -passout "pass:$CERT_PASSWORD"

B64="$OUT_DIR/gestureflow-signing.p12.base64"
base64 -i "$P12" -o "$B64"

echo ""
echo "✅ done"
echo "   certificate : $P12"
echo "   base64      : $B64"
echo ""
echo "Local install (optional — package_app.sh can also import from env):"
echo "   security import \"$P12\" -k ~/Library/Keychains/login.keychain-db -P \"$CERT_PASSWORD\" -T /usr/bin/codesign"
echo ""
echo "Note: self-signed identities may not appear in"
echo "   security find-identity -v -p codesigning"
echo "even when import succeeded. Verify with:"
echo "   codesign -s \"$CERT_NAME\" -f --dryrun /bin/ls"
echo ""
echo "For CI (GitHub Actions secrets):"
echo "   MACOS_CERTIFICATE      = contents of $B64"
echo "   MACOS_CERTIFICATE_PWD  = $CERT_PASSWORD"
echo "   MACOS_SIGNING_IDENTITY = $CERT_NAME"
echo "   KEYCHAIN_PASSWORD      = (any throwaway string)"
echo ""
echo "Keep $P12 backed up — reuse it for every release forever."
