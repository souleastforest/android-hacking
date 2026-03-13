#!/system/bin/sh
# post-fs-data.sh - SMS OTP KernelSU 模块
# 在 PackageManager 启动前，将 Companion APK bind-mount 到 priv-app
# 使 Companion App 作为特权系统服务加载，获得 BIND_ACCESSIBILITY_SERVICE 权限
# by souleastforest

LOG="/data/local/tmp/sms-otp-postfs.log"
MODULE_DIR="/data/adb/modules/sms_otp_autofill"
SRC_APK="$MODULE_DIR/system/priv-app/SmsOtpCompanion/SmsOtpCompanion.apk"
DEST_DIR="/system/priv-app/SmsOtpCompanion"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"
}

log "=== SMS OTP post-fs-data.sh started ==="

if [ ! -f "$SRC_APK" ]; then
    log "ERROR: Companion APK not found at $SRC_APK, skipping bind-mount"
    log "=== done (skipped) ==="
    exit 0
fi

# 检查是否已挂载
ALREADY=$(mount | grep "priv-app/SmsOtpCompanion" | wc -l)
if [ "$ALREADY" -gt 0 ]; then
    log "Already mounted, skipping"
    exit 0
fi

# KernelSU module overlay 应已自动挂载 system/priv-app/SmsOtpCompanion
# 这里额外验证覆盖是否生效
if [ -f "$DEST_DIR/SmsOtpCompanion.apk" ]; then
    log "Companion APK accessible via KSU overlay: $(ls -lh $DEST_DIR/SmsOtpCompanion.apk)"
else
    log "WARNING: Companion APK not found at $DEST_DIR after overlay"
fi

log "=== post-fs-data.sh done ==="
