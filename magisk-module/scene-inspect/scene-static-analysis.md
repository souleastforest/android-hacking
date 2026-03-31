# Scene Static Analysis (from connected device)

Date: 2026-03-17

## 1) App identity and package path

- Package: `com.omarea.vtools`
- App label: `Scene`
- Version: `8.0.15` (`versionCode=820241117`)
- APK path on device: `/data/app/~~0_iA3Do5DNcT_dlp8BdLDA==/com.omarea.vtools-jJTjHUPEcyfrc-3P2SsRBw==/base.apk`
- Local pulled APK: `apk/scene-base.apk`

Evidence: `reports/device-package-info.txt`, `reports/aapt-badging.txt`

## 2) Confirmed static traces related to scheduling/thermal/power management

### 2.1 Direct thermal config operations exist

- MIUI thermal page explicitly says replacing to `/data/vendor/thermal` without reboot:
  - `assets/kr-script/miui/miui-thermal.xml` line 7
- Thermal config script targets `/data/vendor/thermal`, and restarts thermal daemons:
  - `assets/kr-script/miui/thermal_conf3/config.sh` line 9
  - `assets/kr-script/miui/thermal_conf3/config.sh` line 197
  - `assets/kr-script/miui/thermal_conf3/config.sh` lines 199-200
- Another thermal script directly removes thermal config directories:
  - `assets/kr-script/other/thermal/service.sh` lines 1-2, 6

### 2.2 cpuset/cgroup/scheduler/CPU governor traces are extensive

- Assets include many per-app/per-scene cpuset policies:
  - `assets/threads/44.json` lines 15-22, 27-38
  - `assets/threads/62.json`, `62h.json`, `341.json`, `431.json`, `611.json`, `2321.json`
- DEX strings contain scheduling/control model terms:
  - `reports/high-signal-dex.txt` line 156 (`scene-scheduler`)
  - `reports/high-signal-dex.txt` lines 61-63 (`schedule_ep/fas/hp`)
  - `reports/high-signal-dex.txt` lines 97-113 (`cpuset*`)
  - `reports/high-signal-dex.txt` lines 132-139 (`governor*`)
  - `reports/high-signal-dex.txt` lines 71-83 (`scene_config3` with `fg_cgroup_mem/bg_cgroup_mem`)

### 2.3 sysfs/proc/property/service-control traces exist

- Memory compaction/cgroup memory operations:
  - `assets/addin/force_compact.sh` line 14 (`drop_caches`)
  - `assets/addin/force_compact.sh` lines 21-22 (`/sys/fs/cgroup/memory`)
  - `assets/addin/force_compact.sh` lines 133, 135 (`cgroup.procs`)
  - `assets/addin/force_compact.sh` lines 225, 283 (`setprop vtools.state.force_compact`)
  - `assets/addin/force_compact.sh` lines 308-309 (`compact_memory`)
- ZRAM/swap/sysfs/property operations:
  - `assets/addin/zram_control.sh` lines 30-33, 76-79 (`setprop`)
  - `assets/addin/zram_control.sh` lines 18, 20-21, 62, 64-65 (`/sys/block/...`)
  - `assets/addin/zram_control.sh` lines 34-36, 80 (`/proc/sys/vm/...`)
- Device config and settings mutations:
  - `assets/kr-script/battery/battery.xml` lines 22, 34 (`device_config ... use_freezer`)
  - Widespread `settings put ...` and `service call SurfaceFlinger ...` in assets (see `reports/high-signal-assets.txt`)
- DEX strings also include:
  - `reports/high-signal-dex.txt` line 2 (`am force-stop com.xiaomi.joyose`)
  - `reports/high-signal-dex.txt` line 151 (`... am start-service ... com.xiaomi.joyose ...`)
  - `reports/high-signal-dex.txt` line 154 (`resetprop`)
  - `reports/high-signal-dex.txt` line 140 (`init.svc.mi_thermald`)
  - `reports/high-signal-dex.txt` line 165 (`service call SurfaceFlinger 1013`)

### 2.4 Scene systemless-module linkage exists

- Assets include mount/helper scripts for module `scene_systemless`:
  - `assets/addin/magisk_mount.sh` line 4 (`target_module="scene_systemless"`)
- Thermal-remover module generator exists:
  - `assets/kr-script/other/thermal/set.sh` lines 1, 22 (`scene_thermal_remover`)

## 3) Potential conflict with `miui14cloud` (high-confidence hypothesis)

`miui14cloud` and Scene both touch overlapping control planes:

- Thermal config and thermal daemon lifecycle
- cpuset/cgroup/scheduler/governor policy
- sysfs/proc runtime tuning
- service state and package/service force-stop/start (including Joyose traces)

This overlap is sufficient to produce policy contention and post-disable residual-state behavior on MIUI.

## 4) What static analysis cannot prove yet

- It does not prove which specific Scene feature is currently active on your phone at runtime.
- It does not prove execution order/timing between Scene actions and `miui14cloud` service scripts.
- It does not prove whether current battery drain is caused by active Scene profile, stale module side effects, or both.

Runtime state capture is still required to conclude causality.
