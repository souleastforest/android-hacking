#!/usr/bin/env bash
# build.sh - SMS OTP AutoFill KernelSU Module 一键打包脚本
# 用法：./build.sh [--debug|--release]
# 类比 nfc-fix-build/build.sh
# by souleastforest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_MODE="${1:---debug}"
COMPANION_DIR="$SCRIPT_DIR/companion-app"
KSU_MODULE_DIR="$SCRIPT_DIR/ksu-module"
OUTPUT_DIR="$SCRIPT_DIR/build"
MODULE_ID="sms_otp_autofill"
VERSION=$(grep versionCode "$KSU_MODULE_DIR/module.prop" | head -1 | cut -d= -f2)
OUTPUT_ZIP="$OUTPUT_DIR/${MODULE_ID}_v${VERSION}.zip"

# Gradle wrapper jar 版本
GRADLE_WRAPPER_JAR="$COMPANION_DIR/gradle/wrapper/gradle-wrapper.jar"
GRADLE_WRAPPER_JAR_URL="https://raw.githubusercontent.com/spring-projects/spring-boot/main/gradle/wrapper/gradle-wrapper.jar"

echo "========================================="
echo "  SMS OTP AutoFill - KernelSU Module Build"
echo "  Mode: $BUILD_MODE | Version: $VERSION"
echo "========================================="

mkdir -p "$OUTPUT_DIR"

# ── Step 0: 下载 gradle-wrapper.jar（如果不存在）────────────────
if [ ! -f "$GRADLE_WRAPPER_JAR" ]; then
    echo ""
    echo "[0/3] Downloading gradle-wrapper.jar..."
    mkdir -p "$(dirname "$GRADLE_WRAPPER_JAR")"
    curl -fsSL -o "$GRADLE_WRAPPER_JAR" "$GRADLE_WRAPPER_JAR_URL" \
        || { echo "[ERROR] Failed to download gradle-wrapper.jar"; exit 1; }
    echo "  [OK] gradle-wrapper.jar downloaded"
fi

# ── Step 1: 编译 Companion App ──────────────────────────────────
echo ""
echo "[1/3] Building Companion App ($BUILD_MODE)..."
cd "$COMPANION_DIR"

if [ "$BUILD_MODE" = "--release" ]; then
    ./gradlew assembleRelease --quiet
    APK_SRC="$COMPANION_DIR/app/build/outputs/apk/release/app-release.apk"
else
    ./gradlew assembleDebug --quiet
    APK_SRC="$COMPANION_DIR/app/build/outputs/apk/debug/app-debug.apk"
fi

if [ ! -f "$APK_SRC" ]; then
    echo "[ERROR] APK build failed: $APK_SRC not found"
    exit 1
fi
echo "  [OK] APK built: $APK_SRC"

# ── Step 2: 复制 APK 到 KSU 模块 priv-app 目录 ─────────────────
echo ""
echo "[2/3] Copying Companion APK to KSU module..."
PRIV_APP_DIR="$KSU_MODULE_DIR/system/priv-app/SmsOtpCompanion"
mkdir -p "$PRIV_APP_DIR"
cp "$APK_SRC" "$PRIV_APP_DIR/SmsOtpCompanion.apk"
echo "  [OK] Copied to $PRIV_APP_DIR/SmsOtpCompanion.apk"

# ── Step 3: 打包为 KernelSU zip ────────────────────────────────
echo ""
echo "[3/3] Packaging KernelSU module zip..."
cd "$KSU_MODULE_DIR"
# KernelSU 模块 zip 必须包含根目录直接的文件（无子文件夹包裹）
zip -r "$OUTPUT_ZIP" \
    module.prop \
    service.sh \
    post-fs-data.sh \
    customize.sh \
    system/ \
    -x "*.DS_Store" \
    -x "*.git*"
echo "  [OK] Module zip: $OUTPUT_ZIP"

echo ""
echo "========================================="
echo "  Build complete!"
echo "  Output: $OUTPUT_ZIP"
echo ""
echo "  Install via KernelSU Manager:"
echo "    adb push $OUTPUT_ZIP /sdcard/"
echo "    # Then install in KernelSU Manager → Modules → Install"
echo ""
echo "  Or via adb:"
echo "    adb shell su -c 'ksud module install /sdcard/$(basename $OUTPUT_ZIP)'"
echo "========================================="
