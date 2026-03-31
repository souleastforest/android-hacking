#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="${1:-$ROOT_DIR/output/giffgaff-frida.log}"
OUT_FILE="${2:-$ROOT_DIR/output/extracted-esim.txt}"

[ -f "$LOG_FILE" ] || { echo "log not found: $LOG_FILE" >&2; exit 1; }

python3 - "$LOG_FILE" "$OUT_FILE" <<'PY'
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
result = None

for line in log_path.read_text(errors='ignore').splitlines():
    if '[LPA_RESULT]' not in line:
        continue
    payload = line.split('[LPA_RESULT]', 1)[1].strip()
    result = json.loads(payload)

if not result:
    print('no [LPA_RESULT] entry found', file=sys.stderr)
    sys.exit(1)

out_path.write_text(
    'host={host}\nmatchingId={matchingId}\nlpaString={lpaString}\n'.format(**result),
    encoding='utf-8'
)
print(out_path)
print(out_path.read_text(encoding='utf-8'))
PY
