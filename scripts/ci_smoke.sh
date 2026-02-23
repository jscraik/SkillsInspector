#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Ensure system tool paths are available for codesign and Swift tooling.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:${PATH:-}"

if [[ -f "${ROOT_DIR}/Package.swift" ]]; then
  swift test
  swift run skillsctl --help
  swift run skillsctl scan --repo . --allow-empty
else
  echo "Skipping Swift smoke checks: Package.swift not found at repo root."
fi
