#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_SDK_HOME:-$HOME/Library/Android/sdk}}"
BUILD_DIR="$SCRIPT_DIR/build"
OUT_DIR="$SCRIPT_DIR/output"
KEYSTORE="$SCRIPT_DIR/debug.keystore"
XPOSED_API_JAR="$SCRIPT_DIR/api-82.jar"
APK_NAME="theme-cn-identity-hook-1.1-legacyfix.apk"

command -v javac >/dev/null 2>&1 || { echo "javac missing" >&2; exit 1; }
[ -d "$ANDROID_SDK" ] || { echo "Android SDK not found: $ANDROID_SDK" >&2; exit 1; }

BUILD_TOOLS_DIR="$(find "$ANDROID_SDK/build-tools" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -n 1)"
AAPT="$BUILD_TOOLS_DIR/aapt"
D8="$BUILD_TOOLS_DIR/d8"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
DX="$BUILD_TOOLS_DIR/dx"
if [ ! -x "$DX" ]; then
  DX="$(find "$ANDROID_SDK/build-tools" -maxdepth 2 -name dx | sort -V | tail -n 1 || true)"
fi
ANDROID_JAR="$(find "$ANDROID_SDK/platforms" -maxdepth 2 -type f -name android.jar | sort -V | tail -n 1)"

mkdir -p "$BUILD_DIR/classes" "$BUILD_DIR/dex" "$OUT_DIR" "$BUILD_DIR/res"
rm -rf "$BUILD_DIR/classes"/* "$BUILD_DIR/dex"/*
rm -f "$BUILD_DIR/base.apk" "$BUILD_DIR/$APK_NAME" "$OUT_DIR/$APK_NAME"

find src -name '*.java' | sort > "$BUILD_DIR/sources.txt"
javac --release 8 -Xlint:-options -cp "$ANDROID_JAR:$XPOSED_API_JAR" -d "$BUILD_DIR/classes" @"$BUILD_DIR/sources.txt"

CLASS_FILES="$(find "$BUILD_DIR/classes" -name '*.class' | tr '\n' ' ')"
D8_EXIT=0
"$D8" --output "$BUILD_DIR/dex" --lib "$ANDROID_JAR" --classpath "$XPOSED_API_JAR" --min-api 26 $CLASS_FILES >/dev/null 2>&1 || D8_EXIT=$?
if [ "$D8_EXIT" -ne 0 ]; then
  [ -x "$DX" ] || { echo "d8 failed and dx missing" >&2; exit 1; }
  rm -rf "$BUILD_DIR/dex"/*
  (
    cd "$BUILD_DIR/classes"
    find . -name '*.class' -print0 | xargs -0 "$DX" --dex --min-sdk-version=26 --output=../dex/classes.dex
  )
fi

"$AAPT" package -f -M AndroidManifest.xml -S res -I "$ANDROID_JAR" -A assets -F "$BUILD_DIR/base.apk"
(cd "$BUILD_DIR/dex" && zip -qj ../base.apk classes.dex)

cp "$BUILD_DIR/base.apk" "$BUILD_DIR/$APK_NAME"
"$APKSIGNER" sign \
  --ks "$KEYSTORE" \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  "$BUILD_DIR/$APK_NAME"

cp "$BUILD_DIR/$APK_NAME" "$OUT_DIR/$APK_NAME"
echo "$OUT_DIR/$APK_NAME"
