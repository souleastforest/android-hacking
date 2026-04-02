# MIUI Theme / ThemeStore Cover Research (2026-04-01)

## Question

On `MIUI 14 Global + KernelSU + Hybrid Mount`, is there a mature non-partition "cover" path that can make the China theme stack work without flashing whole partition images?

## Short Answer

Yes, but only in one narrow form: **a `/data/app` update package over the same package name** can sometimes work as a cover path.

For the MIUI theme stack on this device, there is **no mature, general-purpose cover solution** that reliably replaces the China `ThemeManager` stack in the app-process namespace without touching partitions. The remaining approaches are either:

- partial and version-bound,
- trampoline-style but dependent on missing intent wiring,
- or systemless mount implementations that still fail to propagate into the target app process.

## Evidence Base

### Upstream / official

- KernelSU metamodule documentation says modules are only mounted when a metamodule is installed, and the official reference implementation is `meta-overlayfs`.
- KernelSU documents `Magic Mount` as a possible metamodule strategy, but it is not the official reference implementation.
- Hybrid Mount README describes itself as a hybrid orchestrator that uses OverlayFS or Magic Mount.
- AOSP dynamic partitions documentation shows `product`, `system_ext`, etc. are logical partitions inside `super`, and bootloader-invisible partitions require userspace/fastbootd or flashing the logical image.
- Android permission docs state that signature and privileged permissions are constrained by signature/allowlist rules.

### Local experiments

- `com.miui.themestore 14.0` is a trampoline shell, not the real theme manager.
- `com.android.thememanager 4.0.1.4` is the real MIUI 14 China ThemeManager line on `marble`.
- On this device, Hybrid Mount can make shell/root see the China `/product` replacement, but the `com.android.thememanager` process still resolves the Global resource table.
- `com.miui.themestore 14.0` also depends on `ro.miui.support.system.app.uninstall.v2=true`, and then expects `com.miui.theme.action.VIEW_HOME` to resolve on `com.android.thememanager`. That action is not present in the tested package lines.

## Ranked Options

### 1. `/data/app` update package over the same package name

**Success probability:** Highest among non-partition cover paths

**What it is**

- Install a newer or older APK as a `/data/app` update over the existing system package with the same package name.
- This is the classic Android system-app update model.

**Why it works here**

- `com.android.thememanager` can be updated this way.
- On this device, `com.android.thememanager 3.9.7.2` installed successfully as a data update package.

**Technical prerequisites**

- Same package name.
- Compatible signature relationship for the package line.
- Runtime resources must still line up with the system app expectations.

**Risks**

- Version drift can still crash at runtime.
- Update package may not expose the actions expected by companion shells like `com.miui.themestore`.

**Does it require system partition modification?**

- No.

**Fit for the MIUI theme stack**

- Best for `com.android.thememanager` downgrade/compatibility testing.
- Not a universal replacement for China ROM behavior.

### 2. Trampoline shell / intent bridge

**Success probability:** Medium to low for this specific stack

**What it is**

- Keep `com.miui.themestore` as a shell.
- Route it to the real `com.android.thememanager` via an intent action.

**Why it is only partial here**

- `com.miui.themestore 14.0` already behaves this way.
- It checks `ro.miui.support.system.app.uninstall.v2`.
- If true, it tries to launch `com.miui.theme.action.VIEW_HOME` on `com.android.thememanager`.
- On this device, `com.android.thememanager` does not declare that action.

**Technical prerequisites**

- The target package must export the expected action.
- The shell must pass all its own property checks.

**Risks**

- A missing intent-filter makes the shell dead-end.
- Even if the bridge is fixed, the target package may still crash on resource mismatch.

**Does it require system partition modification?**

- Not necessarily, but in practice the target system app still has to be compatible.

**Fit for the MIUI theme stack**

- Useful as a compatibility layer.
- Not enough by itself on this device.

### 3. Manifest patch + resign

**Success probability:** Low

**What it is**

- Modify the APK manifest, re-sign it, and install the patched APK without changing partitions.

**Why it is weak here**

- Android signature permissions and platform-signed shared UID flows are constrained by allowlist rules.
- MIUI theme packages in this stack rely on system-app behavior and compatibility with privileged/signature contexts.
- Re-signing breaks the original package identity unless you control the platform signing / shared UID allowlist situation.

**Technical prerequisites**

- Control of signing/allowlist relationships.
- The package must not depend on the original platform signing identity.

**Risks**

- Privileged permissions can silently disappear.
- shared UID / signature-dependent flows can fail install-time or runtime.
- This does not fix app-process mount visibility.

**Does it require system partition modification?**

- Not directly, but it usually cannot preserve the needed system-app identity without deeper system changes.

**Fit for the MIUI theme stack**

- Not a good primary path.

### 4. LSPosed / Frida / proxy Activity

**Success probability:** Low for a durable fix; medium as a diagnostic or very narrow shim

**What it is**

- Hook the app, intercept intent launch or property checks, and redirect flow.

**What we proved**

- Frida is very effective for diagnosis:
  - it showed `com.miui.themestore` finishing because of the property gate,
  - and later showed the `VIEW_HOME` handoff failing because the target action was unresolved.
- For `com.android.thememanager`, Frida also proved the app process still sees the wrong resource mapping.

**Why it is not a mature cover solution**

- It is brittle.
- It does not fix the underlying mount/resource mismatch.
- It becomes a maintenance burden across app updates.

**Technical prerequisites**

- Root or equivalent injection path.
- Stable target method names and call paths.

**Risks**

- High breakage rate across app versions.
- Easy to create partial success that still fails in the real UI flow.

**Does it require system partition modification?**

- No, but it is not a real replacement strategy.

**Fit for the MIUI theme stack**

- Good for reversing / proving a hypothesis.
- Not a long-term user-facing solution.

### 5. Systemless mount cover via KernelSU metamodule / Hybrid Mount

**Success probability:** Medium in general, low-to-medium for this exact app-process case

**What it is**

- Use KernelSU metamodule mounting to present replacement files without flashing partitions.

**Why it looked promising**

- KernelSU docs explicitly support metamodules.
- Hybrid Mount supports OverlayFS and Magic Mount.
- In shell/root view, this can expose the China `/product` and `system_ext` files.

**Why it still fails here**

- In this device state, the `com.android.thememanager` app process still resolves the wrong XML resource.
- The current Hybrid Mount path does not provide app-namespace propagation strong enough for this package line.

**Technical prerequisites**

- A metamodule installed.
- Correct module layout and config.
- The target app process must actually observe the same mount view.

**Risks**

- Bootloops if the runtime config is wrong.
- A solution that works in shell may still fail in app namespace.

**Does it require system partition modification?**

- No, but it depends on mount-layer behavior being sufficient.

**Fit for the MIUI theme stack**

- Good as a lab tool.
- Not yet a durable production cover for this device.

## What We Learned About MIUI Theme Package Lineage

- `com.android.thememanager` is the real system ThemeManager package line.
- `com.miui.themestore` is a trampoline/storefront shell.
- `com.miui.themestore 14.0` depends on:
  - `miui-uninstall-empty.jar`
  - `ro.miui.support.system.app.uninstall.v2=true`
  - a resolvable `com.miui.theme.action.VIEW_HOME` on the target `ThemeManager`
- `com.android.thememanager 4.0.1.4` is the China MIUI 14 ThemeManager line validated on `marble`.
- `com.android.thememanager 3.9.7.2` is useful as a `/data` update fallback, but it is not a full China ROM replacement.

## Best Minimal Experiment Path

If the goal is to avoid flashing partition images, the lowest-risk validation order is:

1. Keep the working KernelSU + Hybrid Mount baseline only as a lab environment.
2. Test `/data/app` update packages on `com.android.thememanager` first.
3. Use `com.miui.themestore` only as a trampoline shell and verify whether the expected intent action exists.
4. Use Frida/LSPosed only to confirm the exact gating condition or launch failure.
5. Stop if the target app-process still resolves the wrong resource table; that means systemless cover is not enough.

## Recommendation

For this device and ROM mix, there is **no mature, universal cover solution** that replaces China MIUI Theme/ThemeStore without touching partitions.

The best non-partition route is:

1. Try a `/data/app` update package over `com.android.thememanager`.
2. Keep `com.miui.themestore` only as a trampoline.
3. Use Hybrid Mount/Frida as diagnostics, not as the primary fix.

If you need a durable China ROM-equivalent theme stack, partition-level replacement remains the reliable path.

## Sources

- KernelSU metamodule: https://kernelsu.org/guide/metamodule.html
- KernelSU vs Magisk differences: https://kernelsu.org/guide/difference-with-magisk.html
- KernelSU Magic Mount community repo placeholder: https://github.com/KernelSU-Modules-Repo/meta-mm
- Hybrid Mount README: https://raw.githubusercontent.com/Hybrid-Mount/meta-hybrid_mount/v3.3.1/README.md
- AOSP dynamic partitions: https://source.android.com/docs/core/ota/dynamic_partitions/implement
- Android signature permissions: https://developer.android.com/guide/topics/manifest/permission-element
- Android permissions overview: https://developer.android.com/guide/topics/permissions/overview
- AOSP signature permission allowlist: https://source.android.com/docs/core/permissions/signature-permission-allowlist
- AOSP platform-signed shared UID allowlist: https://source.android.com/docs/core/permissions/platform-signed-shared-uid-allowlist
- HyperOS Themes global package line: https://hyperosupdates.com/apps/com.android.thememanager
- HyperOS Theme Manager 14.0 package line: https://hyperosupdates.com/apps/com.miui.themestore/14
