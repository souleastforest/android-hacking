# MIUI Theme Package Lineage (2026-04-01)

## Scope

This note documents the package split observed on `marble` while testing MIUI 14 China/Global theme components.

## Package Roles

### `com.android.thememanager`

This is the actual system ThemeManager package line.

- Global system package on device:
  - package: `com.android.thememanager`
  - path: `/product/app/MIUIThemeManagerGlobal/MIUIThemeManagerGlobal.apk`
- China ROM system package:
  - package: `com.android.thememanager`
  - path in extracted ROM: `product/app/MIUIThemeManager/MIUIThemeManager.apk`

For the `marble` MIUI 14 China stable package we inspected, the China ThemeManager version is:

- `versionName=4.0.1.4`

This is the package line that owns the real theme/wallpaper/settings UI.

### `com.miui.themestore`

This is not the primary ThemeManager package line. It behaves like a storefront / trampoline shell.

Observed version used in experiments:

- `versionName=14.0`

Its launcher activity is:

- `com.miui.thememanagerstore.ThemeResourceTabActivity`

Reverse engineering of `ThemeResourceTabActivity.onCreate()` shows:

1. It checks `ro.miui.support.system.app.uninstall.v2`
2. If false/missing, it immediately calls `finish()`
3. If true, it sends:
   - action: `com.miui.theme.action.VIEW_HOME`
   - package: `com.android.thememanager`

So `com.miui.themestore` is only useful if the target `ThemeManager` package can resolve that action.

## Known Version Behavior

### `com.android.thememanager 3.9.7.2`

- Can be installed as a `/data/app` update over the system package
- Useful as a compatibility fallback
- Does not provide the `com.miui.theme.action.VIEW_HOME` action
- Older online functionality is degraded / partially dead

### `com.android.thememanager 4.0.1.4`

- This is the MIUI 14 China system ThemeManager line we validated for `marble`
- Still does not provide the `com.miui.theme.action.VIEW_HOME` action
- Under current Hybrid Mount experiments, app-process resource resolution still crashes with:
  - `Unexpected start tag: found searchable, expected network-security-config`

### `com.miui.themestore 14.0`

- Requires `miui-uninstall-empty.jar`
- Requires `ro.miui.support.system.app.uninstall.v2=true`
- After that property is enabled, startup still depends on `com.android.thememanager` resolving:
  - `com.miui.theme.action.VIEW_HOME`
- On current device state, that action is unresolved, so the shell package cannot continue

## Operational Conclusion

The MIUI 14 theme stack is split into:

1. `com.android.thememanager`
   - real ThemeManager
2. `com.miui.themestore`
   - trampoline/storefront shell

For this device and ROM mix, the real blocker remains `com.android.thememanager 4.0.1.4` runtime compatibility, not APK installation.
