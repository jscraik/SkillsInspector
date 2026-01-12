#!/usr/bin/env bash
set -euo pipefail

# Build a simple DMG for sTools with a link to /Applications.
# Usage: bin/make-dmg.sh [.build/release/sTools.app] [sTools-macos.dmg]

APP_SRC="${1:-.build/release/sTools.app}"
DMG_NAME="${2:-sTools-macos.dmg}"
VOL_NAME="sTools"

if [[ ! -d "$APP_SRC" ]]; then
  echo "App bundle not found at: $APP_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Stage contents
cp -R "$APP_SRC" "$WORKDIR/"
ln -s /Applications "$WORKDIR/Applications"

# Create DMG
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$WORKDIR" \
  -ov -format UDZO "$DMG_NAME"

echo "DMG created at $DMG_NAME"
