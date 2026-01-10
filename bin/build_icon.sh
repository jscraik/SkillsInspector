#!/usr/bin/env bash
# Generate Icon.icns from Icon.png using iconutil
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# Generate the base PNG if it doesn't exist or if regenerating
if [[ ! -f "Icon.png" ]] || [[ "${1:-}" == "--regenerate" ]]; then
  echo "Generating Icon.png..."
  swift Scripts/generate_icon.swift
fi

if [[ ! -f "Icon.png" ]]; then
  echo "ERROR: Icon.png not found. Run 'swift Scripts/generate_icon.swift' first." >&2
  exit 1
fi

ICONSET_DIR="Icon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required sizes
sizes=(16 32 64 128 256 512)
for sz in "${sizes[@]}"; do
  sips -z "$sz" "$sz" Icon.png --out "$ICONSET_DIR/icon_${sz}x${sz}.png" >/dev/null
  dbl=$((sz * 2))
  sips -z "$dbl" "$dbl" Icon.png --out "$ICONSET_DIR/icon_${sz}x${sz}@2x.png" >/dev/null
done

# 512@2x is 1024
cp Icon.png "$ICONSET_DIR/icon_512x512@2x.png"

# Convert to icns
iconutil -c icns "$ICONSET_DIR" -o Icon.icns

echo "Icon.icns generated at $ROOT/Icon.icns"

# Cleanup
rm -rf "$ICONSET_DIR"
