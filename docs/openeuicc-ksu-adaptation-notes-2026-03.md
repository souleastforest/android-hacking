# OpenEUICC KernelSU Adaptation Notes (2026-03)

## Safety Rules

This device is running KernelSU on MIUI 14 / Android 13.

Do not use:

- tmpfs replacement of `/system/etc/permissions`
- bind-mount overlays over core permissions directories
- ad-hoc early-boot scripts that copy XML files without preserving SELinux labels

Reason:

- this can break `privapp-permissions-*.xml`
- PackageManager may lose access to privileged app whitelists
- the observed failure mode is launcher reset / apps disappearing / boot instability

The safe baseline is:

- standard KernelSU module layout under `/data/adb/modules/<id>/`
- rely on KernelSU official install path (`ksud module install <zip>`)
- keep `system/` subtree labeled `u:object_r:system_file:s0`

Reference:

- [kernelsu.md](/Users/saigyoujiyuyuko/Desktop/hacking-^_^/docs/kernelsu.md)

## What Was Tried

### 1. Raw OpenEUICC Magisk debug artifact

Artifact source:

- upstream debug artifact `magisk-debug.zip`

Observed structure:

- APK under `system/system_ext/priv-app/OpenEUICC/OpenEUICC.apk`
- whitelist under `system/system_ext/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml`

Result on this device:

- not suitable as-is for this MIUI / KernelSU environment
- live filesystem does not expose `system_ext` overlay from this module layout

### 2. Hand-created module under `/data/adb/modules`

Adaptation:

- moved files to `system/priv-app/OpenEUICC`
- moved whitelist to `system/etc/permissions`
- added `android.hardware.telephony.euicc.xml`
- added `system.prop` with `ro.telephony.euicc=1`

Result:

- `ro.telephony.euicc=1` applied successfully
- but live `/system/priv-app/OpenEUICC` and `/system/etc/permissions/android.hardware.telephony.euicc.xml` never appeared
- package remained a regular `/data/app` install, not a privileged system package

### 3. SELinux label fix

Observed problem:

- manually copied module subtree had label `u:object_r:adb_data_file:s0`
- working modules on device use `u:object_r:system_file:s0` for mounted `system/` subtree

Fix applied:

- `chcon -R u:object_r:system_file:s0 /data/adb/modules/<id>/system`

Result:

- labels corrected
- still insufficient by itself to make the module appear in live `/system`

### 4. Official KernelSU install path

Created a KernelSU-specific zip:

- output file: [openeuicc-ksu.zip](/Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-bypass-output/openeuicc-ksu.zip)

Changes in that zip:

- module id changed to `openeuicc_ksu`
- files placed under `system/priv-app` and `system/etc/permissions`
- added `android.hardware.telephony.euicc.xml`
- added `system.prop` with `ro.telephony.euicc=1`

Installed with:

- `ksud module install /data/local/tmp/openeuicc-ksu.zip`

Result:

- KernelSU lists the module as:
  - `id=openeuicc_ksu`
  - `enabled=true`
  - `mount=true`
  - `update=false`
- `ro.telephony.euicc=1` still applies
- but live `/system/priv-app/OpenEUICC` is still absent
- `pm list features` still does not show `android.hardware.telephony.euicc`
- `im.angry.openeuicc` still lacks:
  - `WRITE_EMBEDDED_SUBSCRIPTIONS`
  - `READ_PRIVILEGED_PHONE_STATE`
  - `MODIFY_PHONE_STATE`
  - `SECURE_ELEMENT_PRIVILEGED_OPERATION`

## Current Interpretation

The safe KernelSU adaptation work is complete enough to rule out the previous bootloop class of mistake.

The remaining blocker is no longer the module format itself.

Current evidence suggests one of the following:

1. This MIUI / KernelSU stack does not magic-mount newly installed `system/priv-app` and `system/etc/permissions` content the way we expect on this device.
2. There is an extra KernelSU / ROM constraint for privileged overlays on this ROM that is not satisfied yet.
3. OpenEUICC may need a different partition target or additional integration beyond a normal KernelSU module on this device.

## Important Observations

- `ro.telephony.euicc=1` can be applied safely through KernelSU module `system.prop`.
- The dangerous bootloop path was the old tmpfs/bind-mount approach, not the standard KernelSU module path.
- Standard KernelSU module installation is safe on this device, but not yet sufficient to promote OpenEUICC into a privileged system app.

## Recommended Next Step

Do not return to tmpfs/bind-mount tricks.

Next investigation should target KernelSU / ROM mount behavior directly, for example:

1. compare a known-working mounted module path against `openeuicc_ksu`
2. inspect KernelSU mount logs / debug output
3. verify whether this ROM allows new privileged overlays only on specific partitions
4. if needed, switch strategy from KernelSU magic mount to ROM-side prebuilt or recovery-flash style placement
