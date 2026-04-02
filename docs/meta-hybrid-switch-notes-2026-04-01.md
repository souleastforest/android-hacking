# Meta-Hybrid Switch Notes (2026-04-01)

## Why This Path

Current failure mode for `miui_thememanager_cn_replace` under `meta-overlayfs` is namespace inconsistency:

- `system_server` / `dumpsys package` sees China ThemeManager `4.0.1.4`
- app process resource resolution still behaves like Global ThemeManager
- Frida confirmed `loadXmlResourceParser()` resolves `0x7f150008` as `res/xml/searchable.xml` inside app process, which matches Global resource mapping, not China APK mapping
- shell/root mount view contains `KSU on /product`, but app process mountinfo does not

Inference: current OverlayFS metamodule does not make the `/product` replacement consistently visible inside the target app namespace.

## Candidate Replacement

- Module: `meta-hybrid`
- Source: `https://modules.kernelsu.org/module/meta-hybrid/`
- Downloaded artifact: `downloads/Meta-Hybrid-3.0.2-1180.zip`
- SHA256: `be2f96135bf276c2f69e1c947273d8360554c2a8d8f9e1e82524c8bd03c32db9`

Meta-Hybrid advertises a hybrid strategy:

- OverlayFS by default
- Magic Mount fallback when OverlayFS is unavailable or fails
- per-module / per-partition strategy configuration via `/data/adb/meta-hybrid/config.toml`

## Current Device Risk Profile

Active regular modules at time of writing:

- `PreventSystemUpdateMiuiHyperOS`
- `miui14cloud`
- `scene_swap_controller`
- `scene_systemless`
- `esim_enabler`
- `nfc_fix_marble`
- `sms_otp_autofill`
- `openeuicc_ksu`
- `miui_themestore_libfix`
- `miui_thememanager_cn_replace`

Important non-mount modules also active:

- `zygisksu`
- `zygisk_lsposed`
- `playintegrityfix`
- `zygisk_shamiko`

Current metamodule:

- `meta-overlayfs`

## Why Not Hot-Switch Blindly

KernelSU metamodules are global. Switching them affects all mounted modules, not just ThemeManager replacement.

Given the current module set, a bad switch can break:

- eSIM / OpenEUICC path
- NFC fix
- theme shared-lib fix
- SMS OTP autofill
- current ThemeManager experiments

## Recommended Safe Procedure

1. Ensure both rollback assets are available on-device:
   - `meta-overlayfs` zip
   - `Meta-Hybrid-3.0.2-1180.zip`
   - custom local module zips (`openeuicc_ksu`, `esim_enabler`, `nfc_fix_marble`, `miui_themestore_libfix`, `miui_thememanager_cn_replace`, `sms_otp_autofill`)
2. Export the current module list.
3. Disable or remove regular mounted modules if following strict KernelSU guidance.
4. Remove `meta-overlayfs`.
5. Reboot.
6. Install `meta-hybrid`.
7. Reboot.
8. Reinstall required regular modules.
9. Reboot.
10. Force `miui_thememanager_cn_replace` to Magic Mount if supported by `meta-hybrid` config or WebUI.
11. Re-test ThemeManager app-process mount visibility.

## Minimum Validation After Switch

- `mount` shows `meta-hybrid` active
- target app process `/proc/self/mountinfo` includes the expected `/product` replacement path
- `sha256sum /product/app/MIUIThemeManagerGlobal/MIUIThemeManagerGlobal.apk` matches CN APK in both shell and app process
- ThemeManager no longer resolves `0x7f150008` to `searchable.xml`

## Current Reality After Local Debug Builds

With local `Hybrid-Mount 3.3.1-1377` debug builds:

- shell/root view does show the China APK hash at:
  - `/product/app/MIUIThemeManagerGlobal/MIUIThemeManagerGlobal.apk`
- shell/root view also shows:
  - `miui-uninstall-empty.jar`
  - corresponding permission XML
- but the `com.android.thememanager` app process still resolves:
  - `0x7f150008 -> res/xml/searchable.xml`
- and still crashes with:
  - `Unexpected start tag: found searchable, expected network-security-config`

Frida evidence from the app process confirms:

- `ResourcesImpl.loadXmlResourceParser()` is invoked with:
  - `file=res/xml/searchable.xml`
  - `id=0x7f150008`
- app-process mountinfo still shows only the base `/product` EROFS mount plus stock MIUI overlays
- no visible Hybrid Mount path is present in the app process namespace

Current inference:

- Hybrid Mount fixes shell/root visibility for `product/system_ext`
- but the ThemeManager app process still does not consume the same `product` replacement view
- the `4.0.1.4` crash remains a namespace / runtime resource-view mismatch, not a simple packaging failure

## Local Artifacts

- Frida hook: `tools/frida/theme_xml_hook.js`
- CN replacement module: `thememanager-cn-replace-build/miui-thememanager-cn-replace-ksu.zip`
- Global restore module: `thememanager-global-restore-build/miui-thememanager-global-restore-ksu.zip`
