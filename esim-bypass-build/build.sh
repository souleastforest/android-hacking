#!/usr/bin/env bash
# build.sh - eSIM Bypass KernelSU module builder for marble (POCO F5)
# Packages ksu-module/ into a zip installable via KernelSU Manager.
# by souleastforest
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="$SCRIPT_DIR/../esim-bypass-output"
MODULE_DIR="$SCRIPT_DIR/ksu-module"
OUTPUT_ZIP="$OUTPUT_DIR/esim-bypass-ksu-marble.zip"

# ── colors ──────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# ── preflight ────────────────────────────────────────
command -v zip > /dev/null || die "zip not found. Install via: brew install zip"

info "Build environment OK"
mkdir -p "$OUTPUT_DIR"

# ── package KernelSU module zip ──────────────────────
info "Packaging KernelSU module zip..."
rm -f "$OUTPUT_ZIP"
(cd "$MODULE_DIR" && zip -r "$OUTPUT_ZIP" .)
info "Module zip: $(du -sh "$OUTPUT_ZIP" | cut -f1) → $OUTPUT_ZIP"

# ── print next steps ─────────────────────────────────
echo ""
info "Build complete! Next steps:"
echo ""
echo "  1. Push to device:"
echo "     ./platform-tools/adb push $OUTPUT_ZIP /data/local/tmp/"
echo ""
echo "  2a. Install via KernelSU Manager UI:"
echo "      Open KernelSU Manager → Modules → Install from storage"
echo "      → pick /data/local/tmp/esim-bypass-ksu-marble.zip"
echo ""
echo "  2b. Or install via ADB (if ksud is available):"
echo "      ./platform-tools/adb shell su -c \"ksud module install /data/local/tmp/esim-bypass-ksu-marble.zip\""
echo ""
echo "  3. Reboot:"
echo "     ./platform-tools/adb reboot"
echo ""
echo "  4. Verify after reboot:"
echo "     ./platform-tools/adb shell pm has-feature android.hardware.telephony.euicc"
echo "     ./platform-tools/adb shell getprop ro.telephony.euicc"
echo "     ./platform-tools/adb shell cat /data/local/tmp/esim-bypass.log"
echo ""
