#!/bin/bash
#
# Double‑click this file on your Mac (or run it in Terminal) to generate and
# open the Xcode project. It installs XcodeGen automatically if needed.
#
set -e
cd "$(dirname "$0")"

echo "▸ Philips Remote — project bootstrap"

# 1. Ensure XcodeGen is available (via Homebrew).
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "▸ XcodeGen not found."
  if command -v brew >/dev/null 2>&1; then
    echo "▸ Installing XcodeGen with Homebrew…"
    brew install xcodegen
  else
    echo "✗ Homebrew is not installed."
    echo "  Install Homebrew first from https://brew.sh, then run this again,"
    echo "  or install XcodeGen manually from https://github.com/yonaskolb/XcodeGen/releases"
    exit 1
  fi
fi

# 2. Generate the .xcodeproj from project.yml.
echo "▸ Generating PhilipsRemote.xcodeproj…"
xcodegen generate

# 3. Open it in Xcode.
echo "▸ Opening in Xcode…"
open PhilipsRemote.xcodeproj

echo "✓ Done. In Xcode: set your Team under Signing & Capabilities for each"
echo "  target, connect your iPhone, and press Run (▶)."
