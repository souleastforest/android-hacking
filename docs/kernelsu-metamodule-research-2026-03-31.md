## KernelSU Metamodule Research (2026-03-31)

### Scope

Research goal: understand how modern KernelSU mounts module `system/` content, and explain why `openeuicc_ksu` currently applies `system.prop` but does not surface `priv-app` or `permissions` files into live `/system`.

### Official Findings

1. KernelSU no longer guarantees built-in module mounting for `system/`.
   - KernelSU `Module guide` states that only modules touching `/system` need a metamodule, and that `system.prop`, scripts, and `sepolicy.rule` can work without one.
   - Source: <https://kernelsu.org/guide/module.html>

2. Without a metamodule, modules are not mounted.
   - KernelSU `Metamodule` guide says this explicitly: fresh KernelSU installs require a metamodule such as `meta-overlayfs` for mounted modules to function.
   - Source: <https://kernelsu.org/guide/metamodule.html>

3. Only one metamodule can be active at a time.
   - KernelSU documents a single-metamodule constraint and says the active one appears specially in the Manager module list.
   - Source: <https://kernelsu.org/guide/metamodule.html>

4. The metamodule is the component that runs the actual mount stage.
   - Official boot order:
     - regular modules `post-fs-data.sh`
     - load `system.prop`
     - metamodule `metamount.sh`
     - mounted module content then becomes visible
   - Source: <https://kernelsu.org/guide/module.html>

5. `meta-overlayfs` is the official reference implementation.
   - KernelSU documents it as the standard overlayfs-based metamodule.
   - Its documented architecture separates:
     - metadata in `/data/adb/modules/`
     - actual mounted content in `/data/adb/metamodule/mnt/`
   - Source: <https://kernelsu.org/guide/metamodule.html>

6. KernelSU and Magisk are no longer equivalent for mount behavior.
   - `Difference with Magisk` says KernelSU uses the metamodule system and requires a metamodule to enable module mounts.
   - Source: <https://kernelsu.org/guide/difference-with-magisk.html>

### Local Evidence From This Device

Device context:
- POCO F5 `marble`
- MIUI / Android 13
- KernelSU Manager `v3.1.0`

Observed behavior:

1. `ro.telephony.euicc=1` is applied successfully.
   - This matches official docs: `system.prop` does not require a metamodule.

2. Live `/system` does not contain any of the expected OpenEUICC overlay files.
   - Missing:
     - `/system/priv-app/OpenEUICC`
     - `/system/system_ext/priv-app/OpenEUICC`
     - `/system/etc/permissions/android.hardware.telephony.euicc.xml`
     - `/system/etc/permissions/privapp_whitelist_im.angry.openeuicc.xml`

3. `im.angry.openeuicc` remains installed as a normal `/data/app` package.
   - `dumpsys package im.angry.openeuicc` shows:
     - `codePath=/data/app/...`
     - privileged permissions requested but not granted:
       - `MODIFY_PHONE_STATE`
       - `READ_PRIVILEGED_PHONE_STATE`
       - `WRITE_EMBEDDED_SUBSCRIPTIONS`
       - `SECURE_ELEMENT_PRIVILEGED_OPERATION`

4. `pm list features` still does not expose an eUICC feature.
   - Again consistent with the missing permissions XML and missing mounted overlay.

5. `cmd package resolve-activity` can resolve the OpenEUICC UI entry point.
   - This only proves the app is installed and exported.
   - It does not prove privileged/system integration.

6. Mount inspection does not show any obvious metamodule/overlayfs activity for module content.
   - The current state is consistent with "regular modules present, no active metamodule providing `system/` mount behavior".

### Working Hypothesis

The current blocker is not OpenEUICC itself.

The blocker is that this KernelSU environment appears to be running without a working metamodule, or with a metamodule state that is not actually mounting module `system/` payloads on this ROM.

That hypothesis explains all current symptoms at once:

- `system.prop` works
- `system/` overlays do not work
- no `priv-app` path appears in live `/system`
- OpenEUICC remains a normal user app
- privileged permissions remain denied

### Practical Impact On OpenEUICC

OpenEUICC as a KernelSU module depends on mounted `system/` content for:

- `priv-app` placement
- `privapp_whitelist` XML
- `android.hardware.telephony.euicc.xml`

Without a metamodule-backed mount path, OpenEUICC cannot become a privileged LPA on this device, regardless of whether the APK itself is valid.

### Official `meta-overlayfs` Findings

I inspected the official `meta-overlayfs` reference implementation and its current release line.

Repository:
- <https://github.com/KernelSU-Modules-Repo/meta-overlayfs>

Latest release observed during research:
- `v1.3.1` released on `2025-12-02`

Local artifact saved at:
- [meta-overlayfs-v1.3.1.zip](/Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-bypass-output/meta-overlayfs-v1.3.1.zip)
- SHA-256: `279d85a6a35724dfcf8aa1137a9630c7e989e154b94543517c539ee70f9b8811`

Structure of the release ZIP:
- `module.prop`
- `customize.sh`
- `metainstall.sh`
- `metamount.sh`
- `metauninstall.sh`
- `post-mount.sh`
- `meta-overlayfs-aarch64`
- `meta-overlayfs-x86_64`

Important implementation details:

1. It is a real metamodule.
   - `module.prop` contains `metamodule=1`.

2. It is installed like a normal KernelSU module.
   - The project README documents:
     - `adb push meta-overlayfs-v1.0.0.zip /sdcard/`
     - `adb shell su -c 'ksud module install /sdcard/meta-overlayfs-v1.0.0.zip'`
     - `adb reboot`

3. It does not rely on the dangerous tmpfs/bind-mount approach that previously caused breakage on this device.
   - It creates an ext4 sparse image `modules.img`.
   - During boot, `metamount.sh` mounts that image at `/data/adb/metamodule/mnt`.
   - It then runs the `meta-overlayfs` binary to perform overlayfs mounts.

4. It uses the official KernelSU-required source tag.
   - The official docs require mount source/device name `KSU`.
   - `meta-overlayfs` is explicitly documented as doing that.

5. It supports the exact partition classes relevant to OpenEUICC.
   - supported: `system`, `vendor`, `product`, `system_ext`, `odm`, `oem`

6. Its installation hook moves module payloads into the ext4 image only when needed.
   - If a module has `system/` and no `skip_mount`, `metainstall.sh` copies partition trees into the image-backed content store.
   - That is consistent with KernelSU's dual-directory metamodule architecture.

### Safety Assessment

Compared with the previous failed approach on this device:

- previous dangerous approach:
  - tmpfs over `/system/etc/permissions`
  - ad-hoc copying of XML files
  - SELinux context loss
  - risk of launcher/app disappearance and boot instability

- `meta-overlayfs` approach:
  - standard KernelSU metamodule path
  - official reference implementation
  - overlayfs-based mount model
  - no manual replacement of `/system/etc/permissions` via tmpfs

This does not mean zero risk, because any broken boot-time mount layer can still create startup problems.
But it is materially safer than the old tmpfs/bind-mount method and matches KernelSU's current architecture.

### Safe Next Step

Do not keep modifying `openeuicc_ksu` blindly.

The next technical step should be:

1. determine whether a metamodule is installed and active in this KernelSU setup
2. if none is active, install the official `meta-overlayfs`
3. reboot and verify that a simple test overlay appears in live `/system`
4. only then retry OpenEUICC privileged integration

### Proposed Low-Risk Verification Sequence

1. In KernelSU Manager, check whether a metamodule is currently shown as active on the Modules page.
2. If none is active, install `meta-overlayfs-v1.3.1.zip`.
3. Reboot once.
4. Verify a harmless overlay test first, before touching OpenEUICC:
   - a test module that adds only a non-critical XML feature file
   - no tmpfs
   - no direct bind mount over a full permissions directory
5. If the test overlay appears in live `/system`, reinstall or refresh `openeuicc_ksu`.
6. Reboot again and re-check:
   - live `/system/.../OpenEUICC`
   - `pm list features | grep euicc`
   - `dumpsys package im.angry.openeuicc`

### Sources

- KernelSU What is KernelSU: <https://kernelsu.org/guide/what-is-kernelsu.html>
- KernelSU Module guide: <https://kernelsu.org/guide/module.html>
- KernelSU Metamodule guide: <https://kernelsu.org/guide/metamodule.html>
- KernelSU Difference with Magisk: <https://kernelsu.org/guide/difference-with-magisk.html>
