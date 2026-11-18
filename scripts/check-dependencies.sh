#!/usr/bin/env bash
# GeoBridge dependency checker
# Usage: bash scripts/check-dependencies.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

pass() { echo -e "${GREEN}  ✔  ${1}${NC}"; }
fail() { echo -e "${RED}  ✘  ${1}${NC}"; }
warn() { echo -e "${YELLOW}  ⚠  ${1}${NC}"; }

echo -e "\n${BOLD}GeoBridge — Dependency Check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── macOS version ───────────────────────────────────────────────────────────
echo -e "\n${BOLD}System${NC}"
MACOS=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
MAJOR=$(echo "$MACOS" | cut -d. -f1)
if [ "$MAJOR" -ge 14 ] 2>/dev/null; then
    pass "macOS $MACOS (≥14 required)"
else
    warn "macOS $MACOS — GeoBridge requires macOS 14+"
fi

# ── Xcode / Swift ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Build Tools${NC}"
if command -v swift &>/dev/null; then
    VER=$(swift --version 2>&1 | head -1)
    pass "Swift: $VER"
else
    fail "Swift not found — install Xcode or Xcode Command Line Tools"
fi

if command -v xcode-select &>/dev/null; then
    XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "not set")
    pass "Xcode CLT: $XCODE_PATH"
else
    fail "Xcode Command Line Tools not found — run: xcode-select --install"
fi

# ── Python ───────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Python${NC}"
for PY in python3 python; do
    if command -v $PY &>/dev/null; then
        PY_VER=$($PY --version 2>&1)
        pass "$PY: $PY_VER"
        PYTHON_CMD=$PY
        break
    fi
done
if ! command -v python3 &>/dev/null; then
    fail "python3 not found — required to run generate_xcodeproj.py"
fi

# ── Device backends ──────────────────────────────────────────────────────────
echo -e "\n${BOLD}Device Backends (need at least one)${NC}"
BACKEND_FOUND=0

if command -v pymobiledevice3 &>/dev/null; then
    PMD3_PATH=$(command -v pymobiledevice3)
    PMD3_VER=$(pymobiledevice3 --version 2>/dev/null || echo "?")
    pass "pymobiledevice3 $PMD3_VER at $PMD3_PATH"
    BACKEND_FOUND=1
else
    fail "pymobiledevice3 not found"
    echo "     Install: pip3 install pymobiledevice3"
fi

if command -v idevicesetlocation &>/dev/null; then
    IDEV_PATH=$(command -v idevicesetlocation)
    pass "idevicesetlocation at $IDEV_PATH"
    BACKEND_FOUND=1
else
    fail "idevicesetlocation not found"
    echo "     Install: brew install libimobiledevice"
fi

if command -v idevice_id &>/dev/null; then
    pass "idevice_id at $(command -v idevice_id)"
else
    warn "idevice_id not found (optional, needed by libimobiledevice backend)"
fi

if [ "$BACKEND_FOUND" -eq 0 ]; then
    echo ""
    echo -e "${RED}  ✘  No device backend available. GeoBridge cannot set locations.${NC}"
    echo -e "     Install pymobiledevice3:  pip3 install pymobiledevice3"
    echo -e "     Or libimobiledevice:       brew install libimobiledevice"
fi

# ── Homebrew ─────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Optional${NC}"
if command -v brew &>/dev/null; then
    pass "Homebrew at $(command -v brew)"
else
    warn "Homebrew not found (useful for installing libimobiledevice)"
fi

# ── USB devices currently connected ──────────────────────────────────────────
echo -e "\n${BOLD}Connected USB Devices (live check)${NC}"
if command -v pymobiledevice3 &>/dev/null; then
    if pymobiledevice3 usbmux list 2>/dev/null | grep -q 'Identifier'; then
        pass "Device(s) found via pymobiledevice3"
    else
        warn "No devices listed by pymobiledevice3 (connect iPhone via USB)"
    fi
elif command -v idevice_id &>/dev/null; then
    DEVLIST=$(idevice_id -l 2>/dev/null || echo "")
    if [ -n "$DEVLIST" ]; then
        pass "Device(s) found: $DEVLIST"
    else
        warn "No devices found by idevice_id (connect iPhone via USB)"
    fi
else
    warn "No backend available to check connected devices"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done."
