# 进阶指南：解决手机空间不足的“流式备份”方案

当备份像 QQ (60GB+) 这样的大型应用时，Neo Backup 会因为尝试在本地创建临时压缩包而导致手机存储空间耗尽。本方案通过脚本实现“边压缩边传输”，本地不留存文件。

## 场景描述
- **问题**：手机剩余空间不足 60GB，Neo Backup 备份失败。
- **方案**：手动模拟 Neo Backup 的备份结构，利用 Linux 管道将数据直接流向远程 PC。

---

## 操作步骤

### 1. 准备流式备份脚本
在手机上准备以下脚本（例如命名为 `backup_stream.sh`）：

```bash
#!/bin/bash
# 配置参数
PKG="com.tencent.mobileqq"
TIMESTAMP="$(date +%Y-%m-%d-%H-%M-%S-000)-user_0"
REMOTE_BASE="pc-sftp:D:/Backup/Mobilephone/POCO-F5/manual/app/$PKG"
REMOTE_SUBDIR="$REMOTE_BASE/$TIMESTAMP"

# 1. 创建远程目录
rclone mkdir "$REMOTE_SUBDIR"

# 2. 传输 APK
rclone copyto "/data/app/~~.../base.apk" "$REMOTE_SUBDIR/base.apk"

# 3. 生成元数据 (Neo Backup 识别的关键)
cat > /sdcard/metadata.json <<EOF
{
    "packageName": "$PKG",
    "backupDate": "$(date +%Y-%m-%dT%H:%M:%S.000000)",
    "compressionType": "zst",
    "hasApk": true,
    "hasAppData": true,
    "hasExternalData": true,
    "size": 62000000000
}
EOF
rclone copyto /sdcard/metadata.json "$REMOTE_BASE/$TIMESTAMP.properties"

# 4. 流式备份：内部数据 (Data)
tar -C /data/data -cf - "$PKG" | zstd -3 | rclone rcat "$REMOTE_SUBDIR/data.tar.zst"

# 5. 流式备份：外部数据 (External)
tar -C /sdcard/Android/data -cf - "$PKG" | zstd -3 | rclone rcat "$REMOTE_SUBDIR/external_files.tar.zst"
```

### 2. 执行备份
建议在后台运行并记录日志：
```bash
nohup sh backup_stream.sh > /sdcard/backup_status.log 2>&1 &
```

### 3. 如何让 Neo Backup 认领备份
备份完成后，虽然文件已经在 PC 上，但 Neo Backup 需要通过“挂载”才能看到它们。

1. **重新启动挂载** (如果挂载掉线了)：
   ```bash
   tsu -c "export HOME=$HOME && export PATH=$PATH && rclone mount \"pc-sftp:D:/Backup/Mobilephone/POCO-F5/manual/app\" /sdcard/pc-backup --allow-other --vfs-cache-mode writes --daemon"
   ```
2. **刷新列表**：
   - 打开 Neo Backup -> 还原。
   - 点击右上角**刷新**。
   - 如果没看到，进入设置重新选择一次备份文件夹 `/sdcard/pc-backup`。

---

## 核心原理解析
- **`tar -cf -`**：将文件打包成数据流输出到标准输出 (stdout)。
- **`zstd -3`**：接收数据流并实时压缩。
- **`rclone rcat`**：接收压缩后的流，并将其直接写入远程 SFTP 服务器，完全不写入手机本地磁盘。
- **`.properties` 文件**：这是 Neo Backup 的“户口本”，只有这个 JSON 文件内容正确，App 才会认为这是一个有效的备份。

---

## 避坑指南
1. **权限错误**：运行脚本必须使用 `tsu` 或 `su` 权限，否则无法读取 `/data/data`。
2. **挂载断开**：大型传输可能会导致 Android 杀掉 `rclone` 挂载进程，备份完成后如果 Neo Backup 找不到文件，先检查 `ls /sdcard/pc-backup` 是否还有内容。
3. **元数据匹配**：`packageName` 必须与 App 包名严格一致。
