#!/usr/bin/env bash
set -euo pipefail

# Post-build hook to attach the app icon to the built sTools.app.
# Usage: bin/postbuild-icon.sh [.build/release/sTools.app]

APP_PATH="${1:-.build/release/sTools.app}"
ICON_SRC="Icon.icns"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$ICON_SRC" ]]; then
  echo "Icon source not found at: $ICON_SRC" >&2
  exit 1
fi

RES_DIR="$APP_PATH/Contents/Resources"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

cp "$ICON_SRC" "$RES_DIR/Icon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Icon" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Icon" "$INFO_PLIST"

echo "Attached Icon.icns to $APP_PATH"
