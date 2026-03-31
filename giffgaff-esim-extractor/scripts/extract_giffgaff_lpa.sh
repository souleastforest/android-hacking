#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$ROOT_DIR/hooks/giffgaff_esim_token_hook.js"
OUT_DIR="$ROOT_DIR/output"
LOG_FILE="$OUT_DIR/giffgaff-frida.log"
APP_ID="${APP_ID:-com.giffgaffmobile.controller}"
ACTIVITY="${ACTIVITY:-com.giffgaffmobile.controller/.MainActivity}"
ADB="${ADB:-adb}"

mkdir -p "$OUT_DIR"

command -v "$ADB" >/dev/null 2>&1 || { echo "adb not found: $ADB" >&2; exit 1; }
command -v frida >/dev/null 2>&1 || { echo "frida not found in PATH" >&2; exit 1; }

"$ADB" shell am force-stop "$APP_ID" >/dev/null 2>&1 || true
"$ADB" shell am start -W -n "$ACTIVITY" >/dev/null
sleep 2
PID="$($ADB shell pidof "$APP_ID" | tr -d '\r')"

if [ -z "$PID" ]; then
  echo "failed to locate $APP_ID pid" >&2
  exit 1
fi

echo "[*] attached target pid: $PID"
echo "[*] log file: $LOG_FILE"
echo "[*] now reproduce the giffgaff eSIM flow on the phone"
echo "[*] press Ctrl+C when done"

frida -U -p "$PID" -l "$HOOK" 2>&1 | tee "$LOG_FILE"
