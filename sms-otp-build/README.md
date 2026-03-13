# SMS OTP AutoFill KernelSU Module

## 项目概述

短信验证码**自动检测 + 自动注入**的 KernelSU 模块，**不依赖 LSPosed**。

### 架构

```
KernelSU Module (service.sh 守护进程)
  └── 轮询 content://sms/inbox → 正则提取 OTP → 写入 FIFO
        ↓ IPC (named pipe)
  Companion App (priv-app)
    └── OtpForegroundService 读 FIFO
        └── 广播 → OtpAccessibilityService → 填入焦点 EditText
```

### 设备环境

- POCO F5 (marble) | MIUI 14.0.9 Global | KernelSU

## 目录结构

```
sms-otp-build/
├── ksu-module/          # KernelSU 模块文件
│   ├── module.prop
│   ├── service.sh       # 短信监听守护进程（root shell）
│   ├── post-fs-data.sh  # priv-app overlay 验证
│   ├── customize.sh     # 安装时脚本
│   └── system/priv-app/SmsOtpCompanion/  # Companion APK 位置
├── companion-app/       # Android Kotlin 项目
│   └── app/src/main/kotlin/.../
│       ├── MainActivity.kt
│       ├── accessibility/OtpAccessibilityService.kt
│       └── pipe/OtpForegroundService.kt
├── build.sh             # 一键打包
└── docs/
```

## 快速开始

### 前置条件

- Android SDK（`ANDROID_HOME` 或 `ANDROID_SDK_ROOT` 已设置）
- Java 11+

### 构建

```bash
# Debug 构建（默认）
./build.sh

# Release 构建
./build.sh --release
```

### 安装

```bash
adb push build/sms_otp_autofill_v1.zip /sdcard/
# 在 KernelSU Manager → 模块 → 安装，选择该 zip
# 重启设备
```

### 激活 AccessibilityService

重启后打开「SMS OTP AutoFill」App → 点击「前往无障碍设置」→ 启用「SMS OTP 自动填写」。

## 工作原理

| 层 | 组件 | 职责 |
|---|---|---|
| KernelSU root | `service.sh` | 轮询短信 inbox，正则提取 OTP，写入 `/data/local/tmp/sms_otp.fifo` |
| priv-app | `OtpForegroundService` | 阻塞读 FIFO，发本地广播 |
| priv-app | `OtpAccessibilityService` | 收广播，`ACTION_SET_TEXT` 填入焦点 EditText |

## 调试

```bash
# 查看守护进程日志
adb shell cat /data/local/tmp/sms-otp-service.log

# 查看 post-fs-data 日志
adb shell cat /data/local/tmp/sms-otp-postfs.log

# 查看 AccessibilityService 日志
adb logcat -s OtpA11yService OtpFifoService
```

## 注意事项

- **priv-app 签名**：Companion App 需要以平台签名安装才能获得 `BIND_ACCESSIBILITY_SERVICE` 权限。开发阶段可先通过无障碍设置手动授权（debug APK）。
- **MIUI 无障碍限制**：MIUI 可能在后台杀死无障碍服务，需在「省电策略」中将 App 设为不限制。
