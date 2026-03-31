#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
FRIDA_SERVER_BIN="${FRIDA_SERVER_BIN:-}"
REMOTE_PATH="${REMOTE_PATH:-/data/local/tmp/frida-server}"

if ! command -v "$ADB" >/dev/null 2>&1; then
  echo "adb not found: $ADB" >&2
  exit 1
fi

if [ -z "$FRIDA_SERVER_BIN" ] || [ ! -f "$FRIDA_SERVER_BIN" ]; then
  echo "set FRIDA_SERVER_BIN to the local frida-server binary path" >&2
  exit 1
fi

"$ADB" push "$FRIDA_SERVER_BIN" "$REMOTE_PATH"
"$ADB" shell "su -c 'killall frida-server >/dev/null 2>&1 || true; chmod 755 $REMOTE_PATH; nohup $REMOTE_PATH >/data/local/tmp/frida-server.log 2>&1 </dev/null &'"
"$ADB" shell "su -c 'ps -A | grep frida-server || true'"
