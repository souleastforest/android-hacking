#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_SDK_HOME:-$HOME/Library/Android/sdk}}"
OUTPUT_DIR="$SCRIPT_DIR/../esim-bypass-output"
BUILD_DIR="$SCRIPT_DIR/build"
KEYSTORE="$SCRIPT_DIR/debug.keystore"
LEGACY_XPOSED_API_JAR="$SCRIPT_DIR/api-82.jar"
LEGACY_XPOSED_API_URLS=(
  "https://furkank.net/maven/de/robv/android/xposed/api/82/api-82.jar"
  "https://archiva.interlocsolutions.com/archiva/repository/internal/de/robv/android/xposed/api/82/api-82.jar"
  "https://artifactory.appodeal.com/appodeal-public/de/robv/android/xposed/api/82/api-82.jar"
)
MODERN_XPOSED_AAR="$SCRIPT_DIR/api-101.0.1.aar"
MODERN_XPOSED_AAR_URL="https://github.com/libxposed/api/releases/download/101.0.1/api-101.0.1.aar"
MODERN_XPOSED_CLASSES_JAR="$BUILD_DIR/libxposed-api-classes.jar"
XPOSED_VARIANT="${XPOSED_VARIANT:-legacy}"
USE_MODERN_API=false
APK_NAME="esim-bypass-xposed-legacy.apk"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }
case "$XPOSED_VARIANT" in
  legacy)
    USE_MODERN_API=false
    APK_NAME="esim-bypass-xposed-legacy.apk"
    ;;
  dual)
    USE_MODERN_API=true
    APK_NAME="esim-bypass-xposed-dual.apk"
    ;;
  *)
    die "Unsupported XPOSED_VARIANT=$XPOSED_VARIANT (expected: legacy or dual)"
    ;;
esac
jar_is_valid() {
  [ -f "$1" ] && jar tf "$1" >/dev/null 2>&1
}
prepare_modern_xposed_api() {
  if [ ! -f "$MODERN_XPOSED_AAR" ]; then
    info "Downloading libxposed API AAR (101.0.1)..."
    curl -fsSL "$MODERN_XPOSED_AAR_URL" -o "$MODERN_XPOSED_AAR" || return 1
  fi

  unzip -o -q "$MODERN_XPOSED_AAR" classes.jar -d "$BUILD_DIR"
  [ -f "$BUILD_DIR/classes.jar" ] || return 1
  mv -f "$BUILD_DIR/classes.jar" "$MODERN_XPOSED_CLASSES_JAR"
  jar_is_valid "$MODERN_XPOSED_CLASSES_JAR"
}

command -v javac >/dev/null 2>&1 || die "javac not found in PATH"
command -v keytool >/dev/null 2>&1 || die "keytool not found in PATH"
command -v zip >/dev/null 2>&1 || die "zip not found in PATH"
command -v unzip >/dev/null 2>&1 || die "unzip not found in PATH"

[ -d "$ANDROID_SDK" ] || die "Android SDK not found: $ANDROID_SDK"

BUILD_TOOLS_DIR="$(find "$ANDROID_SDK/build-tools" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -n 1)"
[ -n "$BUILD_TOOLS_DIR" ] || die "No build-tools found under $ANDROID_SDK/build-tools"
AAPT="$BUILD_TOOLS_DIR/aapt"
D8="$BUILD_TOOLS_DIR/d8"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
DX="$BUILD_TOOLS_DIR/dx"
if [ ! -x "$DX" ]; then
  DX="$(find "$ANDROID_SDK/build-tools" -maxdepth 2 -name dx | sort -V | tail -n 1 || true)"
fi

[ -x "$AAPT" ] || die "aapt not found: $AAPT"
[ -x "$D8" ] || die "d8 not found: $D8"

ANDROID_JAR="$(find "$ANDROID_SDK/platforms" -maxdepth 2 -type f -name android.jar | sort -V | tail -n 1)"
[ -f "$ANDROID_JAR" ] || die "android.jar not found under $ANDROID_SDK/platforms"

mkdir -p "$BUILD_DIR/classes" "$BUILD_DIR/dex" "$OUTPUT_DIR"
rm -f "$BUILD_DIR/base.apk" "$BUILD_DIR/$APK_NAME" "$OUTPUT_DIR/$APK_NAME"
rm -rf "$BUILD_DIR/classes"/* "$BUILD_DIR/dex"/*

command -v curl >/dev/null 2>&1 || die "curl not found in PATH"

if [ "$USE_MODERN_API" = true ]; then
  if prepare_modern_xposed_api; then
    info "Using modern libxposed API: $MODERN_XPOSED_AAR"
  else
    die "Failed to prepare modern libxposed API classes"
  fi
else
  info "Building legacy-only module (without META-INF/xposed modern API metadata)"
fi

USE_LEGACY_XPOSED_API_JAR=false
if jar_is_valid "$LEGACY_XPOSED_API_JAR"; then
  info "Using existing legacy Xposed API jar: $LEGACY_XPOSED_API_JAR"
  USE_LEGACY_XPOSED_API_JAR=true
else
  warn "Legacy Xposed API jar missing/invalid, trying to download..."
  for url in "${LEGACY_XPOSED_API_URLS[@]}"; do
    if curl -fsSL "$url" -o "$LEGACY_XPOSED_API_JAR" && jar_is_valid "$LEGACY_XPOSED_API_JAR"; then
      info "Downloaded valid legacy Xposed API jar from: $url"
      USE_LEGACY_XPOSED_API_JAR=true
      break
    fi
  done
  if [ "$USE_LEGACY_XPOSED_API_JAR" = false ]; then
    warn "Legacy API unavailable; using local stubs in src/de/robv for backward-compat compile"
  fi
fi

SOURCE_LIST="$BUILD_DIR/sources.txt"
if [ "$USE_LEGACY_XPOSED_API_JAR" = true ]; then
  if [ "$USE_MODERN_API" = true ]; then
    find src/com -name "*.java" | sort > "$SOURCE_LIST"
    JAVAC_CP="$ANDROID_JAR:$MODERN_XPOSED_CLASSES_JAR:$LEGACY_XPOSED_API_JAR"
  else
    find src/com -name "*.java" ! -name "EsimHookModern.java" | sort > "$SOURCE_LIST"
    JAVAC_CP="$ANDROID_JAR:$LEGACY_XPOSED_API_JAR"
  fi
  D8_CLASSPATH_RESOURCE="$LEGACY_XPOSED_API_JAR"
else
  if [ "$USE_MODERN_API" = true ]; then
    find src -name "*.java" | sort > "$SOURCE_LIST"
    JAVAC_CP="$ANDROID_JAR:$MODERN_XPOSED_CLASSES_JAR"
  else
    find src -name "*.java" ! -name "EsimHookModern.java" | sort > "$SOURCE_LIST"
    JAVAC_CP="$ANDROID_JAR"
  fi
  D8_CLASSPATH_RESOURCE="$BUILD_DIR/xposed-stubs.jar"
fi
[ -s "$SOURCE_LIST" ] || die "No Java sources found under src/"

info "Compiling Java sources..."
javac --release 8 -Xlint:-options -cp "$JAVAC_CP" -d "$BUILD_DIR/classes" @"$SOURCE_LIST"

if [ "$USE_LEGACY_XPOSED_API_JAR" = false ]; then
  if [ -d "$BUILD_DIR/classes/de/robv/android/xposed" ]; then
    (cd "$BUILD_DIR/classes" && jar cf "$D8_CLASSPATH_RESOURCE" de/robv/android/xposed)
  else
    die "Local Xposed stubs not found under src/de/robv/android/xposed"
  fi
fi

info "Converting class files to classes.dex..."
CLASS_FILES="$(find "$BUILD_DIR/classes" -name "*.class" | grep -v "/de/robv/android/xposed/" | tr '\n' ' ')"
[ -n "$CLASS_FILES" ] || die "No .class files generated"
D8_LOG="$BUILD_DIR/d8.log"
set +e
D8_ARGS=(
  --output "$BUILD_DIR/dex"
  --lib "$ANDROID_JAR"
  --classpath "$D8_CLASSPATH_RESOURCE"
  --min-api 26
)
if [ "$USE_MODERN_API" = true ]; then
  D8_ARGS+=(--classpath "$MODERN_XPOSED_CLASSES_JAR")
fi
"$D8" "${D8_ARGS[@]}" $CLASS_FILES >"$D8_LOG" 2>&1
D8_EXIT=$?
set -e

if [ "$D8_EXIT" -ne 0 ]; then
  [ -x "$DX" ] || die "d8 failed and no dx fallback found"
  warn "d8 failed, retrying dex build with dx... (details: $D8_LOG)"
  rm -rf "$BUILD_DIR/dex"
  mkdir -p "$BUILD_DIR/dex"
  (
    cd "$BUILD_DIR/classes"
    find com -name "*.class" -print0 | xargs -0 "$DX" --dex --min-sdk-version=26 --output=../dex/classes.dex
  )
fi

info "Packaging base APK..."
"$AAPT" package -f -M AndroidManifest.xml -I "$ANDROID_JAR" -A assets -F "$BUILD_DIR/base.apk"

info "Injecting classes.dex..."
(cd "$BUILD_DIR/dex" && zip -qj ../base.apk classes.dex)

if [ "$USE_MODERN_API" = true ] && [ -d "$SCRIPT_DIR/src/main/resources/META-INF/xposed" ]; then
  info "Injecting META-INF/xposed entries for modern API..."
  (
    cd "$SCRIPT_DIR/src/main/resources"
    zip -qur "$BUILD_DIR/base.apk" META-INF/xposed/java_init.list META-INF/xposed/module.prop META-INF/xposed/scope.list
  )
fi

if [ ! -f "$KEYSTORE" ]; then
  warn "debug.keystore not found, generating one..."
  keytool -genkeypair \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -alias androiddebugkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

if [ -x "$APKSIGNER" ]; then
  info "Signing with apksigner..."
  cp "$BUILD_DIR/base.apk" "$BUILD_DIR/$APK_NAME"
  "$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias androiddebugkey \
    --ks-pass pass:android \
    --key-pass pass:android \
    "$BUILD_DIR/$APK_NAME"
else
  warn "apksigner not found, falling back to jarsigner"
  command -v jarsigner >/dev/null 2>&1 || die "jarsigner not found in PATH"
  jarsigner \
    -keystore "$KEYSTORE" \
    -storepass android \
    -keypass android \
    -signedjar "$BUILD_DIR/$APK_NAME" \
    "$BUILD_DIR/base.apk" \
    androiddebugkey >/dev/null
fi

cp "$BUILD_DIR/$APK_NAME" "$OUTPUT_DIR/$APK_NAME"

info "Build complete: $OUTPUT_DIR/$APK_NAME"
echo "Next:"
echo "  ./platform-tools/adb install \"$OUTPUT_DIR/$APK_NAME\""
echo "  Enable in LSPosed and scope it to com.giffgaffmobile.controller (or com.giffgaffmobile.app on older builds)"
