# MIUI Theme Cover Scheme on MIUI 14 Global

## Conclusion

A workable non-partition-flash scheme exists:

- Keep the system base package in `/product/app/MIUIThemeManagerGlobal`
- Install the China `com.android.thememanager 4.0.1.4` APK as a `/data` update package over the system app
- Keep `Hybrid Mount` only for the `system_ext` shared-library side (`miui-uninstall-empty.jar`) when needed by `com.miui.themestore`

This avoids the namespace mismatch that broke the pure `/product` magic-mount replacement path.

## Why pure Hybrid Mount replacement failed

When only `/product` was replaced systemlessly, shell/root saw the China APK, but the app process still resolved resources like the Global package. That produced the startup crash:

- `Unexpected start tag: found searchable, expected network-security-config`

The root issue was runtime view mismatch between shell/system namespace and the app process namespace.

## Why the /data cover works

Installing the China `com.android.thememanager 4.0.1.4` APK as a normal update package moves the running code path to `/data/app/.../base.apk` while keeping the package name and signature aligned with the system app.

Observed result:

- `pm path com.android.thememanager` -> `/data/app/.../base.apk`
- launch succeeds
- the previous resource-table crash disappears

This works because Android's standard system-app-update mechanism is used instead of relying on systemless `/product` replacement being visible inside the app process.

## Recommended stack

1. `com.android.thememanager 4.0.1.4` installed as `/data` update package
2. optional: `miui-themestore-props-ksu.zip` to set `ro.miui.support.system.app.uninstall.v2=true`
3. optional: `miui_themestore_libfix_hybrid` for `miui-uninstall-empty.jar`

## Limits

- `com.miui.themestore 14.0` is only a trampoline shell
- it expects `com.miui.theme.action.VIEW_HOME` in `com.android.thememanager`
- current `ThemeManager` package line does not expose that action on this ROM, so ThemeStore still needs separate adaptation
- online APIs may still be partially degraded (`404`, null objects, empty arrays)

## Core commands

Install CN ThemeManager as /data cover:

```bash
~/Desktop/hacking-^_^/platform-tools/adb push <cn-apk> /data/local/tmp/com.android.thememanager-cn.apk
~/Desktop/hacking-^_^/platform-tools/adb shell su -c 'pm install -r -d /data/local/tmp/com.android.thememanager-cn.apk'
```

Verify:

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell 'pm path com.android.thememanager'
~/Desktop/hacking-^_^/platform-tools/adb shell 'dumpsys package com.android.thememanager | grep -E "codePath=|versionName=|versionCode="'
```

Launch:

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell am start -W -n com.android.thememanager/com.android.thememanager.ThemeResourceTabActivity
```

Rollback to the stock system version:

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell su -c 'pm uninstall com.android.thememanager'
```

That removes only the `/data` update package and reverts to the system copy in `/product`.
