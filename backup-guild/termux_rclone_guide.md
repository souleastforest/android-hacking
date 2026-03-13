# 手机 QQ 备份到 PC 操作手册

## 环境信息
| 项目 | 值 |
|------|-----|
| PC 局域网 IP | `192.168.110.202` |
| Windows 用户名 | `ludwig` |
| PC 备份目录 | `D:\Backup\Mobilephone\POCO-F5\manual\app` |
| 手机挂载点 | `/sdcard/pc-backup` |

---

## 第一步：Termux 环境准备

```bash
# 安装核心组件
pkg update
pkg install rclone tsu libfuse3
```

---

## 第二步：配置 rclone SFTP 连接（一次性）

```bash
rclone config
```

按提示操作：
1. `n) New remote` → 输入名称: `pc-sftp`
2. 选择类型: `sftp`
3. `host`: `192.168.110.202`
4. `user`: `ludwig`
5. `port`: `22`（回车默认）
6. `password`: 选 `y` → 输入你的 Windows 账户密码
7. 其余选项全部**直接回车**跳过（不要开启 SSH Agent）
8. 最后选 `y` 确认保存

**验证连接：**
```bash
# 如果能看到 123.txt 说明连通了
rclone ls "pc-sftp:D:/Backup/Mobilephone/POCO-F5/manual/app"
```

---

## 第三步：挂载 PC 目录到手机

```bash
# 1. 创建并清理挂载点
mkdir -p /sdcard/pc-backup
rm -rf /sdcard/pc-backup/*

# 2. 执行 root 挂载（核心命令）
# 注意：必须以 root 权限运行才能让系统其他 App (如 Neo Backup) 看到文件
tsu -c "export HOME=$HOME && export PATH=$PATH && rclone mount \
  \"pc-sftp:D:/Backup/Mobilephone/POCO-F5/manual/app\" \
  /sdcard/pc-backup \
  --allow-other \
  --vfs-cache-mode writes \
  --vfs-cache-max-age 24h \
  --vfs-write-back 5s \
  --daemon"

# 3. 验证挂载是否出现在文件系统
ls /sdcard/pc-backup
```

> ⚠️ **挂载期间请保持 Wi-Fi 连接**，手机与 PC 在同一局域网内。

---

## 第四步：Neo Backup 切换备份路径

1. 打开 Neo Backup → **偏好设置** → **备份文件夹**
2. 点击当前路径 → 系统文件选择器弹出
3. 导航到 `/sdcard/pc-backup`，选择该文件夹
4. 授权 Neo Backup 访问

---

## 第五步：执行 QQ 备份

1. Neo Backup 主界面 → 搜索 `qq`
2. 点击 QQ → **备份**
3. 勾选需要的内容（APK + 数据 + 外部数据）
4. 确认执行

> 💡 63 GB 数据通过 Wi-Fi 传输预计需要 **1~3 小时**，请保持手机充电和屏幕常亮（或关闭屏幕休眠）。

---

## 备份完成后：卸载挂载点

```bash
tsu -c "umount /sdcard/pc-backup"
```

---

## 常见问题排查

**1. rclone 报错 `permission denied` (打开 config 失败)**
说明配置文件权限被 root 占用了，在 Termux 里修正：
```bash
sudo chown -R $(whoami):$(whoami) ~/.config/rclone/
```

**2. 挂载点为空或看不到文件**
- 确认 rclone 进程是否还在：`ps -A | grep rclone`
- 检查 `nohup.out` 日志看报错
- 确认是否安装了 `libfuse3`

**3. 权限提示 `fusermount: signal: bad system call`**
通常是内核或权限限制，尝试使用 `tsu -c "..."` 包装命令并在 `rclone mount` 中显式指定相关环境变量。

**4. Windows 端连接问题**
确认 PC 上 OpenSSH 服务已开启，且防火墙允许 22 端口：
```powershell
# Windows PowerShell 执行
Start-Service sshd
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```
