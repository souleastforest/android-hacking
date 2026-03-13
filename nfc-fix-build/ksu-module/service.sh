#!/system/bin/sh
# service.sh v4 - NFC Fix for POCO F5 (marble) MIUI14 Global
# 根因修复：pm install -r 每次执行都会触发 Force Stop → 陷入死循环
# 解决方案：只在 NFC 包未注册时执行一次 install，之后用 broadcast 触发启动
# by souleastforest

NFC_APK="/system/app/NQNfcNci/NQNfcNci.apk"
NFC_PKG="com.android.nfc"
LOG="/data/local/tmp/nfc-fix-service.log"
RESTART_COOLDOWN=30    # 两次重启之间最短等待秒数

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"
}

# 通过广播触发 NFC 启动（验证有效：--include-stopped-packages 是关键）
trigger_nfc_start() {
    # 经 ADB 验证：必须加 --include-stopped-packages，BOOT_COMPLETED 才能送达
    am broadcast --include-stopped-packages \
        -a android.intent.action.BOOT_COMPLETED \
        -p "$NFC_PKG" 2>/dev/null
    log "trigger_nfc_start: BOOT_COMPLETED sent"
}

# 设置进程保护（只对已运行的进程有效）
protect_nfc() {
    local PID
    PID=$(pidof "$NFC_PKG" 2>/dev/null)
    [ -z "$PID" ] && return 1
    echo -1000 > /proc/$PID/oom_score_adj 2>/dev/null
    renice -n -20 -p "$PID" 2>/dev/null
    log "Protected NFC pid=$PID"
    return 0
}

# ── 等待 PackageManager 就绪 ──────────────────────────────────
log "=== NFC Fix service.sh v4 started ==="

for i in $(seq 1 30); do
    PM_COUNT=$(pm list packages 2>/dev/null | wc -l)
    [ "$PM_COUNT" -gt 10 ] && { log "PM ready ($PM_COUNT pkgs)"; break; }
    log "Waiting PM... ($i/30)"
    sleep 2
done

# ── 一次性注册（只要包未注册才执行 pm install）────────────────
REGISTERED=$(pm list packages 2>/dev/null | grep "^package:${NFC_PKG}$")
if [ -z "$REGISTERED" ]; then
    log "Package not registered, installing (ONE TIME)..."
    pm install -r "$NFC_APK" >> "$LOG" 2>&1
    log "pm install result: $?"
    # 安装后等待 PM 处理完毕，让系统自动触发 BOOT_COMPLETED 广播
    sleep 10
else
    log "Package already registered, skip install"
fi

# ── 确保 NFC prop 正确 ────────────────────────────────────────
setprop persist.nfc.enable 1
setprop ro.vendor.nfc.disable.i2c false

# 触发 NFC 启动（如果此时未运行）
NFC_PID=$(pidof "$NFC_PKG" 2>/dev/null)
if [ -z "$NFC_PID" ]; then
    log "NFC not running after install, triggering start..."
    trigger_nfc_start
    sleep 20   # HAL 初始化需要时间，首次给足 20 秒
fi
protect_nfc

# ── 看门狗：检测到 NFC 消失时只用 broadcast 触发，不重新 install ──
log "Watchdog started (cooldown=${RESTART_COOLDOWN}s)"
LAST_RESTART=0
KILL_COUNT=0

while true; do
    sleep 10

    NFC_PID=$(pidof "$NFC_PKG" 2>/dev/null)
    if [ -z "$NFC_PID" ]; then
        NOW=$(date +%s)
        SINCE=$((NOW - LAST_RESTART))
        if [ "$SINCE" -lt "$RESTART_COOLDOWN" ]; then
            # 冷却中，等待
            continue
        fi

        KILL_COUNT=$((KILL_COUNT + 1))
        log "NFC missing (#${KILL_COUNT}), triggering restart..."
        LAST_RESTART=$NOW
        trigger_nfc_start
        sleep 8
        protect_nfc
    else
        # 进程在跑，每 60 秒刷新一次保护
        if [ $(( $(date +%s) % 60 )) -lt 10 ]; then
            protect_nfc 2>/dev/null
        fi
    fi
done
