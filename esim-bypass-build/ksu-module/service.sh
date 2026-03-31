#!/system/bin/sh
# service.sh - eSIM bypass runtime for marble (POCO F5)
# Runs after system boot. Uses resetprop to ensure ro.* props are spoofed
# even if system.prop wasn't applied early enough.
# Also verifies PackageManager sees the euicc feature flag.
# by souleastforest

LOG="/data/local/tmp/esim-bypass.log"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"
}

log "=== esim-bypass service.sh started ==="

# ── Wait for system to boot fully ────────────────────────────────
for i in $(seq 1 20); do
    BOOT=$(getprop sys.boot_completed 2>/dev/null)
    [ "$BOOT" = "1" ] && { log "sys.boot_completed=1 (iter $i)"; break; }
    log "Waiting for boot... ($i/20)"
    sleep 3
done

# ── Strategy B: resetprop (runtime override of ro.* props) ───────
# system.prop handles the early-boot path; resetprop is the belt-AND-suspenders
# approach for ro.* properties that may have already been locked by init.
log "Applying resetprop overrides..."
resetprop ro.telephony.euicc 1
resetprop ro.telephony.sim_slots.count 2
log "resetprop done: ro.telephony.euicc=$(getprop ro.telephony.euicc)"
log "resetprop done: ro.telephony.sim_slots.count=$(getprop ro.telephony.sim_slots.count)"

# ── Verify feature flag is visible to PackageManager ─────────────
# Wait for PackageManager to be ready
for i in $(seq 1 15); do
    PM_COUNT=$(pm list packages 2>/dev/null | wc -l)
    [ "$PM_COUNT" -gt 10 ] && { log "PackageManager ready ($PM_COUNT pkgs)"; break; }
    log "Waiting PM... ($i/15)"
    sleep 2
done

FEAT=$(pm list features 2>/dev/null | grep "android.hardware.telephony.euicc")
if [ -n "$FEAT" ]; then
    log "OK: PM feature check passed: $FEAT"
else
    log "WARNING: android.hardware.telephony.euicc NOT in pm list features"
    log "  → The feature flag XML overlay may not have taken effect."
    log "  → Try rebooting again, or check KernelSU module is enabled."
fi

# ── Log final prop state for debugging ───────────────────────────
log "Final props:"
log "  ro.telephony.euicc     = $(getprop ro.telephony.euicc)"
log "  ro.telephony.sim_slots = $(getprop ro.telephony.sim_slots.count)"
log "  ro.product.model       = $(getprop ro.product.model)"

log "=== service.sh done ==="
