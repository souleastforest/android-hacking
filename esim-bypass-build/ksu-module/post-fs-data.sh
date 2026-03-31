#!/system/bin/sh
# post-fs-data.sh - eSIM bypass for marble (POCO F5)
# Runs at early boot, BEFORE PackageManager starts.
#
# /system/etc/permissions is a MIUI overlay (EROFS lowerdir, read-only).
# KernelSU's module system/ dir bind-mount cannot penetrate it.
# Strategy: copy all existing permission XMLs + our euicc XML into a tmpfs
# dir, then bind-mount that tmpfs dir over /system/etc/permissions/ so
# PackageManager sees the euicc feature flag when it first reads features.
# by souleastforest

LOG="/data/local/tmp/esim-bypass.log"
PERM_SRC="/system/etc/permissions"
TMP_PERM="/dev/esim_permissions"

# Our euicc feature flag XML content
EUICC_XML='<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <feature name="android.hardware.telephony.euicc" />
</permissions>'

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"
}

log "=== esim-bypass post-fs-data.sh started ==="

# ── 1. Create tmpfs work directory ───────────────────────────────
mkdir -p "$TMP_PERM"
mount -t tmpfs tmpfs "$TMP_PERM"
if [ $? -ne 0 ]; then
    log "ERROR: failed to mount tmpfs at $TMP_PERM"
    exit 1
fi
log "tmpfs mounted at $TMP_PERM"

# ── 2. Copy all existing permission XMLs into tmpfs ───────────────
for f in "$PERM_SRC"/*.xml; do
    [ -f "$f" ] && cp "$f" "$TMP_PERM/"
done
log "Copied $(ls "$TMP_PERM" | wc -l) existing permission XMLs"

# ── 3. Inject our euicc feature flag XML ─────────────────────────
echo "$EUICC_XML" > "$TMP_PERM/android.hardware.telephony.euicc.xml"
if [ -f "$TMP_PERM/android.hardware.telephony.euicc.xml" ]; then
    log "OK: euicc XML written to tmpfs"
else
    log "ERROR: failed to write euicc XML"
    exit 1
fi

# ── 4. Bind-mount tmpfs dir over /system/etc/permissions ─────────
mount --bind "$TMP_PERM" "$PERM_SRC"
if [ $? -ne 0 ]; then
    log "ERROR: bind-mount failed"
    exit 1
fi
log "OK: bind-mounted $TMP_PERM over $PERM_SRC"

# ── 5. Verify ─────────────────────────────────────────────────────
if [ -f "$PERM_SRC/android.hardware.telephony.euicc.xml" ]; then
    log "OK: euicc XML visible in $PERM_SRC - PackageManager will pick it up"
else
    log "WARNING: euicc XML NOT visible after bind-mount"
fi

log "Total permissions files now: $(ls "$PERM_SRC" | wc -l)"
log "=== post-fs-data.sh done ==="
