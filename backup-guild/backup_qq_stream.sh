#!/bin/bash

# ==========================================================
# QQ 流式备份脚本 (Neo Backup 兼容格式)
# ==========================================================

# 1. 配置参数
PKG="com.tencent.mobileqq"
TIMESTAMP="2026-03-11-21-30-00-000-user_0"
REMOTE_BASE="pc-sftp:D:/Backup/Mobilephone/POCO-F5/manual/app/$PKG"
REMOTE_SUBDIR="$REMOTE_BASE/$TIMESTAMP"

# 应用路径信息 (已通过 adb 确认)
APK_PATH="/data/app/~~ZFUHIkIm_6HRwoLSJRlGXg==/com.tencent.mobileqq-T0nv3ypadsjloISSSHduJg==/base.apk"
DATA_INTERNAL="/data/data/com.tencent.mobileqq"
DATA_DE="/data/user_de/0/com.tencent.mobileqq"
DATA_EXTERNAL="/sdcard/Android/data/com.tencent.mobileqq"

# Termux 环境路径
export HOME=/data/data/com.termux/files/home
export PATH=/data/data/com.termux/files/usr/bin:$PATH
RCLONE="rclone"

echo "[*] 开始 QQ 流式备份..."
echo "[*] 目标: $REMOTE_SUBDIR"

# 2. 检查连接
if ! $RCLONE lsd "$REMOTE_BASE" > /dev/null 2>&1; then
    echo "[!] 错误: 无法连接到 rclone 远程端，请检查网络和挂载状态。"
    exit 1
fi

# 3. 创建远程目录
$RCLONE mkdir "$REMOTE_SUBDIR"

# 4. 传输 APK (非流式，直接 copy)
echo "[*] 正在传输 APK..."
$RCLONE copyto "$APK_PATH" "$REMOTE_SUBDIR/base.apk"

# 5. 生成并传输 Metadata (properties)
echo "[*] 正在生成元数据..."
cat > /sdcard/qq_metadata.json <<EOF
{
    "backupVersionCode": 8003,
    "packageName": "$PKG",
    "packageLabel": "QQ",
    "versionName": "9.2.25",
    "versionCode": 11820,
    "sourceDir": "$APK_PATH",
    "splitSourceDirs": [],
    "backupDate": "2026-03-11T21:30:00.000000",
    "hasApk": true,
    "hasAppData": true,
    "hasDevicesProtectedData": true,
    "hasExternalData": true,
    "compressionType": "zst",
    "iv": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    "cpuArch": "arm64-v8a",
    "permissions": [],
    "size": 62000000000
}
EOF
$RCLONE copyto /sdcard/qq_metadata.json "$REMOTE_BASE/$TIMESTAMP.properties"

# 6. 流式备份：内部数据 (Data)
echo "[*] 正在流式备份内部数据 (11GB)... 请耐心等待"
tar -C /data/data -cf - "$PKG" | zstd -3 | $RCLONE rcat "$REMOTE_SUBDIR/data.tar.zst"

# 7. 流式备份：保护区数据 (Device Protected)
echo "[*] 正在流式备份保护区数据..."
tar -C /data/user_de/0 -cf - "$PKG" | zstd -3 | $RCLONE rcat "$REMOTE_SUBDIR/device_protected_files.tar.zst"

# 8. 流式备份：外部数据 (External)
echo "[*] 正在流式备份外部数据 (47GB)... 这可能需要较长时间"
tar -C /sdcard/Android/data -cf - "$PKG" | zstd -3 | $RCLONE rcat "$REMOTE_SUBDIR/external_files.tar.zst"

echo "[+] 备份完成！"
