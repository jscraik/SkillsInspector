#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REQUIRED_ASSETS=(
  "brand/brand-mark.webp"
  "brand/brand-mark@2x.webp"
  "brand/brand-mark.png"
  "brand/brand-mark@2x.png"
  "brand/sTools-brand-logo.png"
  "brand/sTools-brand-logo@2x.webp"
)

missing=()
for asset in "${REQUIRED_ASSETS[@]}"; do
  if [[ ! -f "$asset" ]]; then
    missing+=("$asset")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  printf "Missing brand assets:\\n"
  printf " - %s\\n" "${missing[@]}"
  exit 1
fi

README_PATH="README.md"

if ! grep -q "brand/brand-mark.webp" "$README_PATH"; then
  echo "README.md is missing the brand mark image reference (brand/brand-mark.webp)."
  exit 1
fi

if ! grep -q "brand/brand-mark@2x.webp" "$README_PATH"; then
  echo "README.md is missing the retina brand mark reference (brand/brand-mark@2x.webp)."
  exit 1
fi

if ! grep -qi "from demo to duty" "$README_PATH"; then
  echo "README.md is missing the brAInwav tagline 'from demo to duty'."
  exit 1
fi

if ! grep -q "brand/sTools-brand-logo.png" "$README_PATH"; then
  echo "README.md is missing the sTools brand hero (brand/sTools-brand-logo.png)."
  exit 1
fi

if ! grep -q "brand/sTools-brand-logo@2x.webp" "$README_PATH"; then
  echo "README.md is missing the retina hero source (brand/sTools-brand-logo@2x.webp)."
  exit 1
fi

echo "Brand check passed: assets present and README signature/hero found."
