# MIUI 主题最终生效组件清单

日期：`2026-04-02`

这份清单只记录当前国区主题主流程正常工作所需的最小组件、设置和回滚点。

## 1. 主题主包

当前主包路线：

- `com.android.thememanager`
- 生效版本：`4.0.1.4`
- 运行方式：`/data cover`

备份与元数据：

- [com.android.thememanager_current_cover.apk](/Users/saigyoujiyuko/Desktop/hacking-^_^/backups/thememanager-cover/com.android.thememanager_current_cover.apk)
- [com.android.thememanager_current_cover.apk.sha256](/Users/saigyoujiyuko/Desktop/hacking-^_^/backups/thememanager-cover/com.android.thememanager_current_cover.apk.sha256)
- [device_apk_path.txt](/Users/saigyoujiyuko/Desktop/hacking-^_^/backups/thememanager-cover/device_apk_path.txt)
- [package_dump.txt](/Users/saigyoujiyuko/Desktop/hacking-^_^/backups/thememanager-cover/package_dump.txt)

回滚：

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell su -c 'pm uninstall com.android.thememanager'
```

## 2. 注入框架

当前注入框架：

- `Vector`

关键设置：

- Zygisk 排除列表策略：`仅还原挂载变更`

如果改回 `强制`：

- `com.android.thememanager` 进程不会被正常注入
- `Theme CN Identity Hook` 不会执行

## 3. 运行时 hook 模块

当前生效模块：

- [theme-cn-identity-hook-1.1-legacyfix.apk](/Users/saigyoujiyuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/output/theme-cn-identity-hook-1.1-legacyfix.apk)

源码：

- [ThemeCnIdentityLegacyEntry.java](/Users/saigyoujiyuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/src/com/souleastforest/themecnidentity/ThemeCnIdentityLegacyEntry.java)
- [RewriteCore.java](/Users/saigyoujuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/src/com/souleastforest/themecnidentity/RewriteCore.java)

模块作用域：

- 只勾 `com.android.thememanager`

构建前置：

- [api-82.jar](/Users/saigyoujuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/api-82.jar)
- [debug.keystore](/Users/saigyoujuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/debug.keystore)
- [build.sh](/Users/saigyoujuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/build.sh)

## 4. ThemeStore 辅入口

当前主流程已经以 `ThemeManager` 为准，`ThemeStore` 只作为辅入口使用。

保留的备份：

- [com.miui.themestore_30.from-device.apk](/Users/saigyoujuko/Desktop/hacking-^_^/backups/themestore30-cover/com.miui.themestore_30.from-device.apk)
- [com.miui.themestore_30.from-device.apk.sha256](/Users/saigyoujuko/Desktop/hacking-^_^/backups/themestore30-cover/com.miui.themestore_30.from-device.apk.sha256)
- [device_apk_path.txt](/Users/saigyoujuko/Desktop/hacking-^_^/backups/themestore30-cover/device_apk_path.txt)
- [package_dump.txt](/Users/saigyoujuko/Desktop/hacking-^_^/backups/themestore30-cover/package_dump.txt)

## 5. 当前已打通的页面

- `首页`
- `分类`
- `每日精选`

对应已修通的请求链：

- `bullet`
- `relatemodule/hashpair`
- `checkupdate/hashpair`
- `themeActivity / h5config`
- `page/v3`
- `page/v3/classification`

## 6. 一次性恢复清单

如果之后要在同机上重新恢复当前状态，最小步骤是：

1. 安装并启用 `Vector`
2. 确认 Zygisk 排除列表策略为 `仅还原挂载变更`
3. 装回 `/data cover` 版 `com.android.thememanager 4.0.1.4`
4. 安装并启用 `Theme CN Identity Hook`
5. 作用域只勾 `com.android.thememanager`

## 7. 参考文档

- [MIUI 国区主题链路最终打通方案](/Users/saigyoujuko/Desktop/hacking-^_^/docs/miui-theme-cn-route-final-2026-04-02.md)
- [MIUI Theme cover 方案](/Users/saigyoujuko/Desktop/hacking-^_^/docs/miui-theme-cover-scheme-2026-04-01.md)
- [MIUI Theme API 研究](/Users/saigyoujuko/Desktop/hacking-^_^/docs/miui-theme-api-research-2026-04-01.md)
