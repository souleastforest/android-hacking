# Hybrid Mount Theme Action Guide (2026-04-01)

## Goal
Use Hybrid Mount 3.3.1 with clean module layouts so the theme replacement and shared-library fix target the correct partitions:
- `product/...` for China ThemeManager replacement
- `system_ext/...` for `miui-uninstall-empty.jar`

## Packages
Install from:
- `/storage/emulated/0/Download/magisk-module/miui-thememanager-cn-replace-hybrid-ksu.zip`
- `/storage/emulated/0/Download/magisk-module/miui-themestore-libfix-hybrid-ksu.zip`

## Important
Do not keep the old theme modules enabled at the same time.

Old modules to disable or remove first:
- `miui_thememanager_cn_replace`
- `miui_themestore_libfix`

New modules to enable:
- `miui_thememanager_cn_replace_hybrid`
- `miui_themestore_libfix_hybrid`

## Steps
1. Open KernelSU.
2. Disable the old modules:
   `MIUI Theme Manager CN Replace`
   `MIUI ThemeStore Shared-Lib Fix`
3. Install the new packages listed above.
4. Confirm `Hybrid Mount` is still using:
   `default_mode = magic`
   `partitions = product, system_ext`
5. Reboot the phone.

## Verify After Reboot
Run:

```bash
./platform-tools/adb shell 'su 0 sh -c "sha256sum /product/app/MIUIThemeManagerGlobal/MIUIThemeManagerGlobal.apk; echo ---; pm list libraries | grep -i miui-uninstall-empty || true; echo ---; ls -l /system_ext/framework/miui-uninstall-empty.jar /system_ext/etc/permissions/miui-uninstall-empty.xml 2>/dev/null || true; echo ---; dumpsys package com.android.thememanager | grep -E \"codePath=|versionName=|versionCode=\""'
```

Expected:
- ThemeManager APK hash becomes CN version:
  `1057a03f73a16c85e0dce4fe6cca7562d22aaabeeb7a1a7427879d7160ea4930`
- `pm list libraries` includes `miui-uninstall-empty.jar`
- `/system_ext/framework/miui-uninstall-empty.jar` exists

## Test
1. Launch `com.android.thememanager`.
2. If it still crashes, capture logs:

```bash
./platform-tools/adb shell 'su 0 sh -c "logcat -d -s Hybrid_Logger:* | tail -n 300"' > logs/hybrid-theme-after-clean-modules.log
./platform-tools/adb logcat -d | grep -Ei "com.android.thememanager|miui.themestore|AndroidRuntime|FATAL EXCEPTION|network-security-config|searchable" > logs/theme-after-clean-modules.log
```

## Rollback
If the new modules do not work:
1. Disable or remove:
   `miui_thememanager_cn_replace_hybrid`
   `miui_themestore_libfix_hybrid`
2. Reboot.
3. Optionally reinstall `com.android.thememanager 3.9.7.2` as the fallback route.

## Notes
- `Hybrid Mount` 3.3.1 is running and doing magic mounts.
- The earlier failure was caused by old module layouts using `system/product/...` and `system/system_ext/...`, which Hybrid Mount interpreted as `/system/...` targets.
- The clean modules remove that ambiguity.
