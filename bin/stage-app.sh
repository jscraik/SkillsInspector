#!/usr/bin/env bash
set -euo pipefail

# Stage a SwiftPM-built binary into an app bundle using the repo's template sTools.app.
# Usage: bin/stage-app.sh [.build/release/sTools] [.build/release/sTools.app]

BIN_SRC="${1:-.build/release/sTools}"
TARGET_APP="${2:-.build/release/sTools.app}"
TEMPLATE_APP="Template.app"
ICON_SRC="Icon.icns"

if [[ ! -f "$BIN_SRC" ]]; then
  echo "Binary not found at: $BIN_SRC" >&2
  exit 1
fi

if [[ ! -d "$TEMPLATE_APP" ]]; then
  echo "Template app not found at: $TEMPLATE_APP" >&2
  exit 1
fi

rm -rf "$TARGET_APP"
cp -R "$TEMPLATE_APP" "$TARGET_APP"

cp "$BIN_SRC" "$TARGET_APP/Contents/MacOS/sTools"

# Framework staging
BUILD_DIR="$(dirname "$BIN_SRC")"
FRAMEWORKS_DIR="$TARGET_APP/Contents/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

# Copy Sparkle.framework if present
if [[ -d "$BUILD_DIR/Sparkle.framework" ]]; then
    # Use -L to dereference symlinks inside the build dir if necessary, 
    # but usually cp -R is fine. Sparkle.framework might be a symlink or contain them.
    cp -R "$BUILD_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/"
    
    # Ensure standard macOS structure rpath is present
    # SwiftPM binaries often only have @loader_path. We need @executable_path/../Frameworks
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$TARGET_APP/Contents/MacOS/sTools" || true
fi

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$TARGET_APP/Contents/Resources/Icon.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Icon" "$TARGET_APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Icon" "$TARGET_APP/Contents/Info.plist"
fi

echo "Staged app at $TARGET_APP"
