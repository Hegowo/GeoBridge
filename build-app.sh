#!/usr/bin/env bash
# Builds GeoBridge.app in the project root.
# Usage: bash build-app.sh
set -euo pipefail
cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# 1. Compile
# ---------------------------------------------------------------------------
echo "Building GeoBridge (release)…"
swift build -c release

# ---------------------------------------------------------------------------
# 2. Generate icon (skip if .icns already exists)
# ---------------------------------------------------------------------------
ICNS="GeoBridge/Resources/AppIcon.icns"
if [ ! -f "$ICNS" ]; then
  echo "Generating app icon…"
  python3 scripts/make_icon.py
else
  echo "App icon already present, skipping generation."
fi

# ---------------------------------------------------------------------------
# 3. Assemble bundle
# ---------------------------------------------------------------------------
echo "Assembling GeoBridge.app…"
rm -rf GeoBridge.app
mkdir -p GeoBridge.app/Contents/MacOS
mkdir -p GeoBridge.app/Contents/Resources

cp .build/release/GeoBridge           GeoBridge.app/Contents/MacOS/GeoBridge
cp GeoBridge/Resources/Info.plist     GeoBridge.app/Contents/Info.plist
cp GeoBridge/Resources/AppIcon.icns        GeoBridge.app/Contents/Resources/AppIcon.icns
cp GeoBridge/Resources/location_helper.py GeoBridge.app/Contents/Resources/location_helper.py
printf 'APPL????' >                   GeoBridge.app/Contents/PkgInfo

# ---------------------------------------------------------------------------
# 4. Ad-hoc code sign
# ---------------------------------------------------------------------------
echo "Signing (ad-hoc)…"
codesign --force --sign - \
  --entitlements GeoBridge/Resources/GeoBridge.entitlements \
  GeoBridge.app

# Remove quarantine so macOS does not block the first launch
xattr -cr GeoBridge.app 2>/dev/null || true

echo ""
echo "Done → GeoBridge.app"
echo "Launch:  open GeoBridge.app"
open GeoBridge.app
