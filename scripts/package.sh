#!/usr/bin/env bash
# Builds the release ZIP: the content of sdcard/ at the root of the archive,
# plus LICENSE. Usage: scripts/package.sh [output directory]   (default: dist)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$ROOT/dist}
VERSION=$(sed -n 's/^VERSION=//p' "$ROOT/sdcard/run.sh")
NAME=mmi3g-green-menu-activator-$VERSION.zip

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp -R "$ROOT/sdcard/." "$STAGE/"
cp "$ROOT/LICENSE" "$STAGE/LICENSE.txt"
rm -rf "$STAGE/backup" "$STAGE"/*.log "$STAGE"/DISABLE*

# Same bytes for the same sources: fixed dates, sorted entries, no extra fields
find "$STAGE" -exec touch -h -d '2000-01-01 00:00:00' {} +
mkdir -p "$OUT"
rm -f "$OUT/$NAME"
(cd "$STAGE" && find . -type f | sed 's#^\./##' | LC_ALL=C sort | zip -q -X -@ "$OUT/$NAME")

echo "$OUT/$NAME"
