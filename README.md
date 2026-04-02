# hacking-^_^

本仓库记录一台 `POCO F5 / marble / MIUI 14 Global / Android 13 / KernelSU` 设备上的实际调试与改造工作。

当前主要主题：

- `giffgaff eSIM + 9eSIM + OpenEUICC` 集成
- `MIUI ThemeManager / ThemeStore` 在 Global ROM 上的可用化
- `KernelSU / Hybrid Mount / LSPosed / Vector` 相关实验与复盘
- 设备侧异常与系统服务冲突排查

## 当前结论

### eSIM

`giffgaff eSIM` 已打通可用路径：

- 设备通过 `KernelSU + OpenEUICC + 9eSIM` 暴露 eSIM 能力
- `giffgaff app` 可走到购买/激活链路
- 最终通过抓取标准 `LPA:1$...` 参数并导入 `OpenEUICC/9eSIM` 完成安装

核心文档：

- [giffgaff eSIM 调试总结](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/giffgaff-esim-debug-summary-2026-03-31.md)
- [OpenEUICC + 9eSIM + giffgaff 研究](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/openeuicc-9esim-giffgaff-research-2026-03.md)
- [KernelSU 适配记录](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/openeuicc-ksu-adaptation-notes-2026-03.md)

### 主题系统

当前主题实验的可用主线是：

- `com.android.thememanager 4.0.1.4` 走 `/data` cover
- `Vector` 负责注入 `Theme CN Identity Hook`
- `ThemeManager` 的国区在线主流程已打通
- `com.miui.themestore` 可以继续作为辅入口，但主能力现在以 `ThemeManager` 为准

核心文档：

- [MIUI 国区主题链路最终打通方案](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/miui-theme-cn-route-final-2026-04-02.md)
- [MIUI Theme cover 方案](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/miui-theme-cover-scheme-2026-04-01.md)
- [MIUI Theme API 研究](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/miui-theme-api-research-2026-04-01.md)
- [MIUI Theme 包线关系](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/miui-theme-package-lineage-2026-04-01.md)
- [Theme cover 调研](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/miui-theme-cover-research-2026-04-01.md)

### 系统异常排查

已确认一类会周期性弹出“发送报告给系统”的异常并非来自 KernelSU，而是 Meta 预装系统服务循环崩溃：

- [Meta 预装系统服务循环崩溃记录](/Users/saigyoujiyuko/Desktop/hacking-^_^/docs/meta-facebook-system-service-crash-note-2026-04-01.md)

## 当前目录说明

- `docs/`: 结论型文档、调试复盘、研究报告
- `backups/`: 当前有效 APK 或关键状态备份
- `downloads/`: 临时下载产物
- `theme-store-patched-output/`: 当前 ThemeStore patched 产物
- `thememanager-cn-identity-hook-build/`: 当前 ThemeManager 国区身份重写模块
- `giffgaff-esim-extractor/`: giffgaff LPA 参数提取工具
- `logs/`: 抓取的设备日志与分析输出
- `platform-tools/`: 本地 adb / fastboot 工具

## 备注

这个仓库是工作目录，不是一个干净发布仓库。里面会保留：

- 可复盘的文档
- 当前仍可能回滚或复用的 APK/patch/backups
- 少量调试日志

已经确认无效的大体积实验产物会定期清理。
