# POCO F5 (marble) MIUI 14 Global NFC 修复历程

> **作者**：souleastforest  
> **设备**：POCO F5 (marble) | MIUI 14.0.9 Global | KernelSU + LSPosed  
> **日期**：2026-02-26  
> **结果**：✅ NFC 完全修复（开关恢复、默认付款应用显示、一键修复可用）

---

## 一、问题现象

| 现象 | 描述 |
|------|------|
| 「连接与共享」无 NFC 入口 | NFC 选项完全不出现在设置页面 |
| 点击快捷开关崩溃 | 跳转到「连接与共享」后立即闪退 |
| 一键修复 NFC 失败 | 点击修复后弹出「修复失败」提示 |

---

## 二、根因分析（层层递进）

### 第一层：Java 崩溃（表象）

**崩溃位置**：`com.android.settings.nfc.MiuiNfcPayPreferenceController.onResume()`

```
NullPointerException: Attempt to read from field
  'android.content.ComponentName
   com.android.settings.nfc.PaymentBackend$PaymentAppInfo.componentName'
  on a null object reference
  at MiuiNfcPayPreferenceController.java:113
```

**原因**：`PaymentBackend.getDefaultApp()` 返回 null，Settings 没有做 null 检查直接访问字段。

---

### 第二层：NFC 服务未运行（深层）

检查 props 和进程：

```
[ro.vendor.nfc.disable.i2c]: [true]   ← 系统默认禁用 I2C 总线
[vendor.qti.nfc.chipid]: [0xa4]       ← 芯片存在
[init.svc.nqnfc_2_0_hal_service]: [running]  ← HAL 在跑

ps -A | grep nfc
# 只有 vendor.nxp.hardware.nfc@2.0-service
# com.android.nfc 进程不存在！
```

**原因**：`ro.vendor.nfc.disable.i2c=true` 禁用了 HAL 与 NFC 芯片之间的 I2C 通信，导致 `com.android.nfc` 无法正常启动。

---

### 第三层：NFC 包从未被注册（根本原因）

```bash
pm list packages -s | grep nfc    # 空
pm path com.android.nfc           # 空
pm list packages -u | grep nfc    # 也没有 com.android.nfc
```

但 APK 文件实际存在：

```
/system/app/NQNfcNci/NQNfcNci.apk
/product/pangu/system/app/NQNfcNci/NQNfcNci.apk
```

**根本原因**：MIUI 14 Global ROM 在 `/product/pangu/` overlay 层对 `NQNfcNci` 包进行了过滤/排除，PackageManager 启动时从不扫描该包，导致 `com.android.nfc` 在系统中完全不存在。`pangu` 是 MIUI 国行版专属 overlay，在 Global ROM 上该包被意外排除。

---

## 三、修复方案

### 模块 1：KernelSU Systemless 模块（`nfc-fix-ksu-marble.zip`）

**作用**：覆盖关键系统 prop，补全 NFC feature 声明，开机后自动注册 NFC 包。

**文件结构**：
```
ksu-module/
├── module.prop               # 模块元信息
├── system.prop               # 覆盖 NFC 相关 prop
├── service.sh                # 开机自动注册 com.android.nfc
└── system/etc/permissions/
    └── android.hardware.nfc.xml  # 补全 NFC feature 声明
```

**关键 `system.prop` 内容**：
```properties
persist.nfc.enable=1
ro.nfc.port=I2C
ro.vendor.nfc.disable.i2c=false   # ← 核心修复：重新启用 I2C
ro.vendor.nfc.repair=1
ro.vendor.nfc.wallet_fusion=1
```

**关键 `service.sh` 逻辑**：
1. 等待 PackageManager 就绪（最多 60 秒）
2. 检查 `com.android.nfc` 是否已注册
3. 若未注册，执行 `pm install -r /system/app/NQNfcNci/NQNfcNci.apk`
4. 日志写入 `/data/local/tmp/nfc-fix-service.log`

---

### 模块 2：LSPosed Xposed 模块（`nfc-fix-lsposed.apk`）

**作用**：Hook `MiuiNfcPayPreferenceController.onResume()`，防止 `getDefaultApp()` 返回 null 时崩溃。

**技术细节**：
- 使用 smali 汇编手写字节码（绕过 d8 与 Java 21 的不兼容问题）
- hook 逻辑：在 `onResume` 前检查 `mPaymentBackend` 和 `getDefaultApp()` 返回值，为 null 时直接 `setResult(null)` 跳过执行

**Scope**：`com.android.settings`

---

## 四、调试历程时间线

| 阶段 | 问题 | 发现 | 解决 |
|------|------|------|------|
| 1 | LSPosed 模块灰色不可用 | `xposed_init` 路径错误（在 APK 根目录而非 `assets/`） | aapt 加 `-A` 参数正确打包 |
| 2 | hook 未生效，仍然崩溃 | `findAndHookMethod` smali 返回类型写成 `void`，实际返回 `XC_MethodHook$Unhook` → `NoSuchMethodError` | 修正 smali 方法描述符 |
| 3 | hook 生效但一键修复失败 | `ro.vendor.nfc.disable.i2c=true` 禁用 I2C | KSU 模块覆盖为 `false` |
| 4 | `com.android.nfc` 进程仍不存在 | MIUI pangu overlay 将 `NQNfcNci` 包从 PM 扫描中排除 | `pm install -r` 手动注册 + `service.sh` 持久化 |
| 5 | ✅ 修复完成 | `com.android.nfc` 进程正常运行，NFC 开关可用 | — |

---

## 五、关键调试命令参考

```bash
# 查看 NFC 相关 prop
getprop | grep -i nfc

# 查看 NFC 进程
ps -A | grep nfc

# 查看 NFC 包注册状态
pm list packages | grep nfc
pm path com.android.nfc

# 手动注册 NFC 包（需要 root）
tsu
pm install -r /system/app/NQNfcNci/NQNfcNci.apk

# 查看 service.sh 运行日志
cat /data/local/tmp/nfc-fix-service.log

# 验证 I2C 是否已启用
getprop ro.vendor.nfc.disable.i2c
# 期望输出：false
```

---

## 六、最终验证结果

```
[07:20:17] === NFC Fix service.sh started ===
[07:20:17] Waiting for PM... (1/30)
...
[07:20:26] PackageManager ready (packages: 569)
[07:20:26] com.android.nfc already registered, skipping install
[07:20:26] === NFC Fix service.sh done ===

$ ps -A | grep nfc
 1048 ?  vendor.nxp.hardware.nfc@2.0-service
14347 ?  com.android.nfc           ← ✅ NFC 服务进程正常
14451 ?  com.google.android.apps.walletnfcrel
```

**NFC 设置页面恢复正常**：
- ✅ NFC 开关（已启用）
- ✅ 默认付款应用：支付宝
- ✅ NFC 读写勿扰选项
- ✅ 一键修复 NFC 选项

---

## 七、构建说明

### 环境依赖

| 工具 | 版本 | 用途 |
|------|------|------|
| Java JDK | 21 | 编译 Xposed stubs |
| Android SDK build-tools | 30.0.2 | aapt 资源打包 |
| android.jar | android-29 | 编译期依赖 |
| smali.jar | 2.5.2 | smali → dex 汇编 |

> 注：d8（30.0.2）与 Java 21 有兼容性问题（内部 NPE），改用 smali 手写字节码绕过。

### 一键构建

```bash
cd nfc-fix-build
bash build.sh
# 输出到 ../nfc-fix-output/
#   nfc-fix-ksu-marble.zip   ← 刷入 KernelSU
#   nfc-fix-lsposed.apk      ← 安装到 LSPosed
```

---

## 八、Git 历史

```
03afc58 feat: add service.sh to auto-register com.android.nfc on boot
39ebac6 fix: override ro.vendor.nfc.disable.i2c=false in system.prop
8204730 fix: correct findAndHookMethod return type in smali
d7fac04 feat: update author to souleastforest, add build.sh
771698c fix: correct assets/xposed_init path in APK
6715057 chore: add .gitignore
7d2f6b6 feat: initial commit - NFC fix modules for marble MIUI14 Global
```
