# eSIM Hardware Bypass for POCO F5 marble (giffgaff + 9esim)

KernelSU 模块，让 giffgaff App 相信设备支持 eSIM，从而显示 eSIM 激活 UI，配合 9esim 外置 eUICC 卡完成 giffgaff eSIM 烧录。

## 原理

giffgaff App 通过两条路检测 eSIM 硬件：

| 检查方式 | 本模块的应对 |
|---|---|
| `PackageManager.hasSystemFeature("android.hardware.telephony.euicc")` | 注入 `system/etc/permissions/android.hardware.telephony.euicc.xml`（KernelSU overlay） |
| `ro.telephony.euicc` 系统属性 | `system.prop` + `service.sh` 中的 `resetprop` 双重写入 |
| `ro.telephony.sim_slots.count` | 同上，设置为 `2` |

## 构建

```bash
cd esim-bypass-build
bash build.sh
# → 输出: ../esim-bypass-output/esim-bypass-ksu-marble.zip
```

## 安装

```bash
# 推送 zip 到设备
./platform-tools/adb push ../esim-bypass-output/esim-bypass-ksu-marble.zip /data/local/tmp/

# 用 KernelSU Manager 安装（推荐）：
# KernelSU Manager → Modules → 从存储安装 → 选择 esim-bypass-ksu-marble.zip

# 或通过 ADB（需要 ksud）：
./platform-tools/adb shell su -c "ksud module install /data/local/tmp/esim-bypass-ksu-marble.zip"

# 重启
./platform-tools/adb reboot
```

## 验证

重启后执行：

```bash
# 确认 feature flag 已注入
./platform-tools/adb shell pm has-feature android.hardware.telephony.euicc
# 期望输出: feature: android.hardware.telephony.euicc

# 确认 ro.telephony.euicc = 1
./platform-tools/adb shell getprop ro.telephony.euicc

# 查看模块日志
./platform-tools/adb shell cat /data/local/tmp/esim-bypass.log
```

然后打开 giffgaff App → Order SIM → eSIM 选项应该出现了。

---

## 🔴 Strategy C：网络抓包后备方案

> 如果 giffgaff App 仍然报错（比如它调用了底层 eSIM API `EuiccManager.getEid()` 而系统驱动没有），则放弃 UI 欺骗，改为**抓包拿 LPA 激活码**。

### 步骤

1. **安装抓包工具**（二选一）：
   - **PCAPdroid**（推荐，Root 模式，无需证书）：Play Store 搜索 PCAPdroid
   - **HttpCanary**：需要通过 Magisk 把 Root CA 安装到 system 证书存储

2. **安装 giffgaff 服务端 CA**（HttpCanary 路线）：
   ```bash
   # HttpCanary 生成 CA 后，用 Magisk 模块方式安装到 /system/etc/security/cacerts/
   # 或用 MagiskTrustUserCerts 模块一键提权
   ```

3. **触发 giffgaff 激活流程**：
   - 打开 giffgaff App → Order SIM / Activate eSIM
   - 让 App 走完请求（即使最后报错也没关系，只要它发出了网络请求）

4. **在抓包工具里找 LPA 字符串**：
   - 过滤 Host: `*.giffgaff.com`
   - 在 HTTPS 响应的 JSON 里找类似：
     ```
     LPA:1$smdp.io$XXXXXXXXXXXXXXXX
     ```
   - 格式固定为 `LPA:1$<SM-DP+ 服务器地址>$<激活码>`

5. **复制 LPA 字符串，粘贴到 9esim App**：
   - 打开 9esim 管理 App → 添加 eSIM / 扫码激活 → 手动输入
   - 粘贴完整 LPA 字符串 → 开始烧录

> 📝 这条路完全绕过了 giffgaff App 的硬件检测，本质上只是拿服务端的激活码，烧录这步由 9esim 硬件自己完成。
