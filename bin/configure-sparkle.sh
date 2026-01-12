#!/usr/bin/env bash
set -e

# Usage: bin/configure-sparkle.sh <AppBundlePath> <FeedURL> <PublicKey>

APP_PATH="$1"
FEED_URL="$2"
PUBLIC_KEY="$3"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"

echo "Configuring Sparkle in Info.plist..."
echo "  Feed URL: $FEED_URL"
echo "  Public Key: ${PUBLIC_KEY:0:10}..."

# Helper to set or add string
set_string() {
    local key="$1"
    local val="$2"
    /usr/libexec/PlistBuddy -c "Set :$key $val" "$INFO_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :$key string $val" "$INFO_PLIST"
}

# Helper to set or add bool
set_bool() {
    local key="$1"
    local val="$2"
    /usr/libexec/PlistBuddy -c "Set :$key $val" "$INFO_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :$key bool $val" "$INFO_PLIST"
}

set_string "SUFeedURL" "$FEED_URL"
set_string "SUPublicEDKey" "$PUBLIC_KEY"
set_bool "SUEnableAutomaticChecks" "true"
set_bool "SUAutomaticallyUpdate" "false"

echo "Sparkle configuration applied."
