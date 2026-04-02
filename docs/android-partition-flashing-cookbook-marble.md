# Android Partition Flashing Cookbook for `marble`

This document is a practical guide for flashing partition images on the `marble` device class from the perspective of an engineer who already understands `adb`, TWRP/ROM flashing, A/B slots, CI/CD style rollout thinking, and general Linux filesystem concepts.

It focuses on the current device state we observed locally:

- device: `marble`
- active slot: `_a`
- update model: `A/B` + `virtual A/B`
- dynamic partitions: enabled
- `product` and `system_ext` are mounted from `erofs`
- current theme replacement target: `product_a`

## 1. What Happens If You Flash `product_a`

Short version:

- You are **not** touching the bootloader.
- You are **not** touching `boot_a`, `vbmeta_a`, `dtbo_a`, or recovery-related partitions.
- You **are** replacing the logical partition contents for `product_a` inside `super`.
- The change affects files mounted at `/product` for the current slot.

In this project, flashing `product_a` changes app/framework payloads stored on `/product`, such as:

- `/product/app/MIUIThemeManagerGlobal/MIUIThemeManagerGlobal.apk`

That means the expected impact is at the Android userspace layer:

- system apps on `/product`
- framework resources on `/product`
- preinstalled app payloads and product-specific configs

It does **not** directly rewrite:

- boot chain
- kernel
- ramdisk
- bootloader stages
- modem firmware

## 2. Why This Is Still High Risk

Even though `product_a` is not a bootloader partition, flashing the wrong image can still soft-brick the ROM.

Typical failure modes:

1. Android boots but a system app or framework component crashes early.
2. PackageManager metadata and filesystem contents no longer match.
3. Verified boot or mount-time integrity checks reject the partition contents.
4. You flash an image built for the wrong slot, wrong device, or wrong partition size.
5. The filesystem image is valid, but the ROM expects resources or shared libraries that are missing.

So the risk profile is:

- lower than touching `boot`/`vbmeta`
- higher than installing a normal APK
- closer to “surgical ROM modification” than “app installation”

## 3. Why a Module Was Not Enough Here

A KernelSU/Magisk-style module is a **systemless overlay**. It tries to make the runtime *see* replacement files without rewriting the underlying partition.

That is useful when:

- the mount layer actually propagates into the namespaces that matter
- the app/framework only needs file replacement visibility

It failed here because:

- `meta-overlayfs` and then `meta-hybrid` did not produce a real `/product` replacement visible in the live partition view we needed
- `PackageManager` ended up with CN metadata while runtime still saw the Global APK bytes
- that mismatch caused the `network-security-config` vs `searchable` resource-ID crash

So we moved from:

- simulated replacement

to:

- real logical partition replacement

## 4. What `fastbootd` Actually Means

You likely already know bootloader fastboot and recovery workflows. The extra concept you need here is:

- **bootloader fastboot** is not the same thing as **userspace fastbootd**

For dynamic partitions on modern Android:

- many logical partitions inside `super` are flashed through `fastbootd`
- `fastbootd` runs in userspace and understands dynamic partition management better than classic bootloader fastboot for these cases

For this project, `product_a` flashing should be treated as a `fastbootd` operation.

## 5. Dynamic Partitions: The Mental Model You Need

On older devices, partitions were more static and directly mapped one-to-one to block devices.

On this device, the important model is:

- `super` is the large physical container
- `product_a`, `system_a`, `system_ext_a`, `vendor_a`, etc. are **logical partitions** carved out of `super`
- Android then exposes them as device-mapper nodes like:
  - `/dev/block/mapper/product_a`
  - `/dev/block/mapper/system_ext_a`

What we observed locally:

- `/product` comes from `product-verity` / `product_a`
- `/system_ext` comes from `system_ext-verity` / `system_ext_a`
- slot `_a` is active
- virtual A/B is enabled

So when you flash `product_a`, you are replacing one logical partition inside the `super` layout for the active slot.

## 6. Virtual A/B and COW: Why You Should Care

The local `lpdump` shows:

- `product_a`
- `product_a-cow`
- `system_a-cow`
- `odm_a-cow`

That means the device uses snapshot/cow mechanics for OTA-style updates.

Practical implications:

- the storage topology is more complex than classic A/B
- OTA machinery may expect partition contents to align with metadata/snapshots
- ad-hoc flashing is still possible, but you should think of it as operating beneath the normal OTA orchestration layer

This matters because a partition flash can leave the device bootable but in a state the next OTA does not like.

## 7. EROFS: Why the Filesystem Type Matters

`/product` on this device is mounted as `erofs`.

Practical consequences:

- read-only at runtime
- you cannot just `cp` over files in place on a booted system
- “real replacement” means building a new EROFS image and flashing that image

This is why the workflow became:

1. dump current `product_a`
2. extract filesystem contents
3. replace target APK
4. rebuild an EROFS image
5. flash `product_a`

## 8. What You Already Know vs What You Still Need

Given your background, you already have enough intuition for:

- `adb`
- recovery/ROM flashing
- A/B slots
- operational rollback thinking
- scripting and automation
- testing after deploy-like changes

What you still need for this class of Android work is mainly this extra layer:

1. **dynamic partitions / `super`**
   - logical partitions instead of only physical ones
2. **fastbootd vs bootloader fastboot**
   - not all partitions are best handled the same way
3. **AVB / verity awareness**
   - even if you are not modifying `vbmeta`, the system still has integrity expectations
4. **filesystem type awareness**
   - `erofs` vs `ext4` changes whether online mutation is realistic
5. **namespace/runtime mismatch debugging**
   - systemless modules can fool one process view but not another
6. **PackageManager cache vs on-disk bytes mismatch**
   - Android can fail in ways that look like app bugs but are actually package/resource inconsistency

## 9. What Flashing `product_a` Should Not Change

Under a correct flash, these should remain unchanged:

- bootloader lock state
- boot partition contents
- kernel image
- ramdisk
- modem/baseband partitions
- NFC firmware partitions
- eSIM card content
- user data partition contents

That said, a bad `product_a` can still make the phone effectively unusable if SystemUI or critical system apps stop working.

## 10. What Flashing `product_a` Can Indirectly Break

Even though it is “just product”, it can still break:

- theme manager
- package scans for product apps
- product-shipped shared libraries/resources
- settings or MIUI integrations that depend on product-side XML/JAR/APK assets
- OTA assumptions for the current slot

In other words, this is still production-grade surgery.

## 11. Safety Rules Before You Flash

Minimum checklist:

1. Confirm active slot.
2. Confirm target partition name matches the active slot.
3. Keep a byte-for-byte backup of the original partition image.
4. Keep a tested rollback command ready before flashing.
5. Verify the rebuilt image size does not exceed the logical partition size.
6. Verify the target file inside the rebuilt image has the intended hash.
7. Use `fastbootd` for dynamic partition flashing.
8. Do not mix “module overlay state” assumptions with “real partition state”.

## 12. The Specific Assets Prepared in This Project

Prepared locally:

- original backup image:
  - `runtime-forensics/theme-real-replace/product_a.from-device.img`
- patched image:
  - `runtime-forensics/theme-real-replace/product_a.thememanager-cn.img`
- flash script:
  - `runtime-forensics/theme-real-replace/flash_product_cn.sh`
- rollback script:
  - `runtime-forensics/theme-real-replace/flash_product_restore.sh`

This gives you a reversible path:

- flash patched `product_a`
- test boot + ThemeManager behavior
- revert immediately if the ROM shows instability

## 13. The Most Important Operational Mindset

Treat this exactly like an infra rollout against a stateful target:

- current live state must be backed up first
- patch must be reproducible
- rollback must be prepared before deployment
- validation criteria must be decided before flashing

For this theme-manager change, validation should be:

1. device boots normally
2. `com.android.thememanager` launches
3. no early `AndroidRuntime` crash for `network-security-config` parsing
4. other product-side services still behave normally

## 14. What I Would Learn Next If I Were You

If you want to go one level deeper after this project, these are the most leverage-heavy topics:

1. `lpdump`, `lpunpack`, and super metadata layout
2. AVB / dm-verity / `vbmeta` interaction model
3. `erofs` build and extraction tooling
4. fastboot vs fastbootd partition flashing semantics
5. how PackageManager scans system apps across `/system`, `/system_ext`, `/product`, `/vendor`

That is the difference between “I can flash Android things” and “I can debug Android partition-state problems with confidence”.
