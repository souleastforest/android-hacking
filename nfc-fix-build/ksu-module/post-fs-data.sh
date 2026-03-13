#!/system/bin/sh
# post-fs-data.sh - 在 PackageManager 启动前，将 NQNfcNci bind-mount 到 priv-app
# 使 com.android.nfc 作为特权系统服务加载（android:persistent=true 生效，adj=0）
# by souleastforest

LOG="/data/local/tmp/nfc-fix-postfs.log"
SRC_APK="/system/app/NQNfcNci/NQNfcNci.apk"
SRC_ODEX="/system/app/NQNfcNci/oat/arm64/NQNfcNci.odex"
SRC_VDEX="/system/app/NQNfcNci/oat/arm64/NQNfcNci.vdex"
DEST_DIR="/system/priv-app/NQNfcNci"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"
}

log "=== post-fs-data.sh started ==="

# 检查源文件
if [ ! -f "$SRC_APK" ]; then
    log "ERROR: $SRC_APK not found, aborting"
    exit 1
fi

# 如果 /system/priv-app/NQNfcNci 已经 bind-mount 过，跳过
ALREADY=$(mount | grep "priv-app/NQNfcNci" | wc -l)
if [ "$ALREADY" -gt 0 ]; then
    log "Already mounted, skipping"
    exit 0
fi

# 使用 KernelSU 模块已经 overlay 好的目录（若存在）
# KernelSU 在 post-fs-data 阶段会先挂载模块的 system/ overlay
# 我们的 system/priv-app/NQNfcNci/ 目录已通过模块 overlay 创建
# 这里只需确保 APK 文件指向正确位置

log "NFC priv-app directory ready via KernelSU module overlay"
log "Source: $SRC_APK"
log "Destination: $DEST_DIR/NQNfcNci.apk (via module symlink)"

# 验证 overlay 是否生效
if [ -f "$DEST_DIR/NQNfcNci.apk" ]; then
    log "priv-app APK accessible: $(ls -lh $DEST_DIR/NQNfcNci.apk)"
else
    log "WARNING: priv-app APK not found at $DEST_DIR"
fi

log "=== post-fs-data.sh done ==="
