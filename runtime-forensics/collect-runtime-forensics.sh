#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADB_BIN="${ADB_BIN:-$ROOT_DIR/platform-tools/adb}"
DEVICE_SCRIPT_LOCAL="$SCRIPT_DIR/device-runtime-forensics.sh"
STAMP="$(date +%Y%m%d-%H%M%S)"
LABEL=""
KEEP_REMOTE=0

usage() {
  cat <<'EOF'
Usage:
  ./collect-runtime-forensics.sh [--label NAME] [--keep-remote]

Behavior:
  1. Pushes a read-only collection script to the connected phone
  2. Executes it via su
  3. Pulls the captured snapshot into logs/runtime-forensics/<timestamp>[-label]

Examples:
  ./collect-runtime-forensics.sh
  ./collect-runtime-forensics.sh --label sleep-before
  ./collect-runtime-forensics.sh --label sleep-after --keep-remote
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --label)
      LABEL="-$2"
      shift 2
      ;;
    --keep-remote)
      KEEP_REMOTE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -n "$LABEL" ]; then
  LABEL="$(printf '%s' "$LABEL" | tr ' /' '__' | tr -cd '[:alnum:]_.-')"
fi

if [ ! -x "$ADB_BIN" ]; then
  if command -v adb >/dev/null 2>&1; then
    ADB_BIN="$(command -v adb)"
  else
    echo "adb not found. Expected at $ADB_BIN" >&2
    exit 1
  fi
fi

if [ ! -f "$DEVICE_SCRIPT_LOCAL" ]; then
  echo "Missing device script: $DEVICE_SCRIPT_LOCAL" >&2
  exit 1
fi

LOCAL_OUT_DIR="$ROOT_DIR/logs/runtime-forensics/${STAMP}${LABEL}"
REMOTE_BASE="/data/local/tmp/runtime-forensics-${STAMP}${LABEL}"
REMOTE_SCRIPT="/data/local/tmp/device-runtime-forensics.sh"

mkdir -p "$LOCAL_OUT_DIR"

echo "[1/5] Checking adb device ..."
"$ADB_BIN" get-state >/dev/null

echo "[2/5] Checking root access ..."
"$ADB_BIN" shell 'su -c id' > "$LOCAL_OUT_DIR/root-check.txt"

echo "[3/5] Pushing collector ..."
"$ADB_BIN" push "$DEVICE_SCRIPT_LOCAL" "$REMOTE_SCRIPT" > "$LOCAL_OUT_DIR/push.txt"
"$ADB_BIN" shell "chmod 0755 '$REMOTE_SCRIPT'" >> "$LOCAL_OUT_DIR/push.txt"

echo "[4/5] Running collection ..."
"$ADB_BIN" shell "su -c 'sh $REMOTE_SCRIPT $REMOTE_BASE'" | tee "$LOCAL_OUT_DIR/remote-out.txt"

echo "[5/5] Pulling snapshot ..."
"$ADB_BIN" pull "$REMOTE_BASE" "$LOCAL_OUT_DIR" > "$LOCAL_OUT_DIR/pull.txt"

if [ "$KEEP_REMOTE" -eq 0 ]; then
  "$ADB_BIN" shell "su -c 'rm -rf $REMOTE_BASE $REMOTE_SCRIPT'" > "$LOCAL_OUT_DIR/cleanup.txt" || true
fi

echo
echo "Snapshot saved to:"
echo "  $LOCAL_OUT_DIR"
echo
echo "Start here:"
echo "  $LOCAL_OUT_DIR/$(basename "$REMOTE_BASE")/meta/summary.txt"
