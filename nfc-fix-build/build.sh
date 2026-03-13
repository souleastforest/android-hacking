#!/usr/bin/env bash
# build.sh - NFC Fix modules builder for marble MIUI14 Global
# Author: souleastforest
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ANDROID_SDK="${ANDROID_SDK_HOME:-$HOME/Library/Android/sdk}"
BUILD_TOOLS="$ANDROID_SDK/build-tools/30.0.2"
ANDROID_JAR="$ANDROID_SDK/platforms/android-29/android.jar"
AAPT="$BUILD_TOOLS/aapt"
KEYSTORE="$SCRIPT_DIR/debug.keystore"
OUTPUT_DIR="$SCRIPT_DIR/../nfc-fix-output"

# ── colors ──────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
die()     { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# ── preflight checks ────────────────────────────────
[ -f "$AAPT" ]        || die "aapt not found at $BUILD_TOOLS. Set ANDROID_SDK_HOME."
[ -f "$ANDROID_JAR" ] || die "android.jar not found. Install android-29 platform."
command -v java      >/dev/null || die "java not found in PATH."
[ -f smali.jar ]     || die "smali.jar not found. Run: curl -L -o smali.jar https://bitbucket.org/JesusFreke/smali/downloads/smali-2.5.2.jar"

info "Build environment OK"

# ── clean build dirs ────────────────────────────────
rm -rf build/dex build/apk-tmp
mkdir -p build/dex build/apk-tmp "$OUTPUT_DIR"

# ── Step 1: assemble smali → dex ────────────────────
info "Assembling smali → classes.dex ..."
java -jar smali.jar assemble smali-src/ -o build/dex/classes.dex
info "classes.dex: $(du -sh build/dex/classes.dex | cut -f1)"

# ── Step 2: generate keystore if absent ─────────────
if [ ! -f "$KEYSTORE" ]; then
    warn "No keystore found, generating debug keystore..."
    keytool -genkeypair -v \
        -keystore "$KEYSTORE" \
        -alias androiddebugkey \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass android -keypass android \
        -dname "CN=Android Debug,O=Android,C=US" \
        2>/dev/null
    info "Keystore generated."
fi

# ── Step 3: aapt package (resources + manifest + assets) ──
info "Packaging APK resources via aapt ..."
"$AAPT" package -f \
    -M xposed-module/AndroidManifest.xml \
    -S xposed-module/res \
    -A xposed-module/assets \
    -I "$ANDROID_JAR" \
    -F build/apk-tmp/base.apk

# ── Step 4: add classes.dex to APK ──────────────────
info "Adding classes.dex to APK ..."
(cd build/dex && zip -j "$SCRIPT_DIR/build/apk-tmp/base.apk" classes.dex)

# ── Step 5: sign APK ────────────────────────────────
info "Signing APK ..."
jarsigner \
    -keystore "$KEYSTORE" \
    -storepass android -keypass android \
    -signedjar build/nfc-fix-xposed-signed.apk \
    build/apk-tmp/base.apk \
    androiddebugkey 2>/dev/null

# ── Step 6: prepare priv-app symlink (make NFC a privileged system app) ──
info "Creating priv-app overlay (symlink → /system/app/NQNfcNci/NQNfcNci.apk) ..."
mkdir -p ksu-module/system/priv-app/NQNfcNci
# 创建相对 symlink：priv-app/NQNfcNci/NQNfcNci.apk → /system/app/NQNfcNci/NQNfcNci.apk
# KernelSU 会把此 symlink bind-mount 到真实 /system/priv-app/NQNfcNci/NQNfcNci.apk
ln -sf /system/app/NQNfcNci/NQNfcNci.apk \
    ksu-module/system/priv-app/NQNfcNci/NQNfcNci.apk 2>/dev/null || true
info "priv-app symlink: $(ls -la ksu-module/system/priv-app/NQNfcNci/NQNfcNci.apk)"

# ── Step 7: package KernelSU zip ────────────────────
info "Packaging KernelSU module zip ..."
(cd ksu-module && zip -r "$SCRIPT_DIR/build/nfc-fix-ksu.zip" .)


# ── Step 7: copy to output dir ──────────────────────
cp build/nfc-fix-xposed-signed.apk "$OUTPUT_DIR/nfc-fix-lsposed.apk"
cp build/nfc-fix-ksu.zip           "$OUTPUT_DIR/nfc-fix-ksu-marble.zip"

# ── Done ─────────────────────────────────────────────
echo ""
info "Build complete! Output files:"
ls -lh "$OUTPUT_DIR/nfc-fix-lsposed.apk" "$OUTPUT_DIR/nfc-fix-ksu-marble.zip"
echo ""
info "Verify APK contents:"
unzip -l "$OUTPUT_DIR/nfc-fix-lsposed.apk" | grep -E "xposed|classes|Manifest"
