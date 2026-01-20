#!/usr/bin/env bash
set -euo pipefail

# Post-build hook to attach the app icon to the built SkillsInspector.app.
# Usage: bin/postbuild-icon.sh [.build/release/SkillsInspector.app]

APP_PATH="${1:-.build/release/SkillsInspector.app}"
ICON_SRC_ROOT="Icon.icns"
ICON_SRC_RES="Sources/SkillsInspector/Resources/Icon.icns"
ICON_SRC=""

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at: $APP_PATH" >&2
  exit 1
fi

if [[ -f "$ICON_SRC_RES" ]]; then
  ICON_SRC="$ICON_SRC_RES"
elif [[ -f "$ICON_SRC_ROOT" ]]; then
  ICON_SRC="$ICON_SRC_ROOT"
else
  echo "Icon source not found in repo root or Resources." >&2
  exit 1
fi

RES_DIR="$APP_PATH/Contents/Resources"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

cp "$ICON_SRC" "$RES_DIR/Icon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Icon" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Icon" "$INFO_PLIST"

echo "Attached Icon.icns to $APP_PATH"
