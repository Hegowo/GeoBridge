#!/usr/bin/env bash
# GeoBridge — project setup
# Generates GeoBridge.xcodeproj and optionally installs dependencies.
# Usage: bash setup.sh [--install-deps]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BOLD}→ ${1}${NC}"; }
success() { echo -e "${GREEN}✔ ${1}${NC}"; }
warn()    { echo -e "${YELLOW}⚠ ${1}${NC}"; }
die()     { echo -e "${RED}✘ ${1}${NC}"; exit 1; }

echo -e "\n${BOLD}GeoBridge Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. Generate Xcode project ──────────────────────────────────────────────
info "Generating GeoBridge.xcodeproj…"
if ! command -v python3 &>/dev/null; then
    die "python3 is required. Install Xcode Command Line Tools: xcode-select --install"
fi
python3 scripts/generate_xcodeproj.py
success "GeoBridge.xcodeproj created"

# ── 2. Optionally install deps ─────────────────────────────────────────────
if [[ "${1:-}" == "--install-deps" ]]; then
    info "Installing pymobiledevice3…"
    pip3 install --upgrade pymobiledevice3
    success "pymobiledevice3 installed"
fi

# ── 3. Run dependency check ────────────────────────────────────────────────
info "Checking dependencies…"
bash scripts/check-dependencies.sh || true

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  open GeoBridge.xcodeproj"
echo ""
echo "  Or with Swift Package Manager:"
echo "  swift build && swift run"
echo ""
if ! command -v pymobiledevice3 &>/dev/null && ! command -v idevicesetlocation &>/dev/null; then
    warn "No device backend installed. Run setup.sh --install-deps  or:"
    echo "  pip3 install pymobiledevice3"
fi
