#!/system/bin/sh

set -u

OUT_DIR="${1:-/data/local/tmp/runtime-forensics-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/commands"
mkdir -p "$OUT_DIR/files"
mkdir -p "$OUT_DIR/meta"

write_text() {
  rel="$1"
  shift
  mkdir -p "$(dirname "$OUT_DIR/$rel")"
  {
    "$@"
  } > "$OUT_DIR/$rel" 2>&1
}

run_cmd() {
  name="$1"
  shift
  write_text "commands/${name}.txt" sh -c "$*"
}

append_line() {
  rel="$1"
  shift
  mkdir -p "$(dirname "$OUT_DIR/$rel")"
  printf '%s\n' "$*" >> "$OUT_DIR/$rel"
}

capture_file_head() {
  src="$1"
  rel="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$OUT_DIR/$rel")"
    {
      echo "# FILE: $src"
      ls -ld "$src" 2>/dev/null
      if command -v stat >/dev/null 2>&1; then
        stat "$src" 2>/dev/null
      fi
      if command -v sha1sum >/dev/null 2>&1; then
        sha1sum "$src" 2>/dev/null
      fi
      echo
      if [ -f "$src" ]; then
        sed -n '1,200p' "$src" 2>/dev/null
      fi
    } > "$OUT_DIR/$rel" 2>&1
  fi
}

capture_tree_listing() {
  src="$1"
  rel="$2"
  if [ -e "$src" ]; then
    run_cmd "$rel" "ls -laR '$src'"
  fi
}

append_line "meta/summary.txt" "captured_at=$(date '+%Y-%m-%d %H:%M:%S %z')"
append_line "meta/summary.txt" "out_dir=$OUT_DIR"
append_line "meta/summary.txt" "user=$(id 2>/dev/null)"
append_line "meta/summary.txt" "uname=$(uname -a 2>/dev/null)"
append_line "meta/summary.txt" "android_id=$(getprop ro.build.id)"
append_line "meta/summary.txt" "fingerprint=$(getprop ro.build.fingerprint)"
append_line "meta/summary.txt" "device=$(getprop ro.product.device)"
append_line "meta/summary.txt" "model=$(getprop ro.product.model)"

run_cmd "getprop-all" "getprop"
run_cmd "getprop-filtered" "getprop | grep -Ei 'thermal|scene|joyose|powerkeeper|daemon|mcd|miuibooster|perf|sched|cpuset|uclamp|doze|idle|cached|phantom|low_power|fps|pangu|cloud'"
run_cmd "modules-list" "ls -la /data/adb/modules /data/adb/modules_update 2>/dev/null"
run_cmd "modules-interesting" "find /data/adb/modules -maxdepth 2 \\( -type f -o -type d \\) 2>/dev/null | grep -Ei 'miui14cloud|scene|thermal|power|joyose|daemon|mcd|booster|perf' | sort"

run_cmd "package-scene" "dumpsys package com.omarea.vtools"
run_cmd "package-powerkeeper" "dumpsys package com.miui.powerkeeper"
run_cmd "package-joyose" "dumpsys package com.xiaomi.joyose"
run_cmd "package-miui-daemon" "dumpsys package com.miui.daemon"

run_cmd "pm-scene-path" "pm path com.omarea.vtools"
run_cmd "pm-scene-components" "cmd package dump com.omarea.vtools | grep -Ei 'enabled=|versionName|versionCode|ActivityMiuiCloudProfile|ReceiverBoot|AccessibilitySceneMode|SceneTileService|scene_mode'"

run_cmd "settings-global-filtered" "settings list global | grep -Ei 'power|idle|doze|cached|phantom|thermal|scene|joyose|anim|job|alarm|standby|wifi|mobile|boost'"
run_cmd "settings-system-filtered" "settings list system | grep -Ei 'power|thermal|scene|fps|refresh|speed|battery|miui|joyose'"
run_cmd "settings-secure-filtered" "settings list secure | grep -Ei 'power|idle|doze|scene|battery|thermal|refresh|miui'"

run_cmd "device-config-activity-manager" "cmd device_config list activity_manager"
run_cmd "device-config-device-idle" "cmd device_config list device_idle 2>/dev/null || true"
run_cmd "deviceidle" "dumpsys deviceidle"
run_cmd "batterystats-filtered" "dumpsys batterystats | grep -Ei 'omarea|scene|joyose|powerkeeper|miui.daemon|therm|miuibooster|mcd' -C 2"
run_cmd "alarm-filtered" "dumpsys alarm | grep -Ei 'omarea|scene|joyose|powerkeeper|miui.daemon|therm|miuibooster|mcd' -C 2"
run_cmd "jobscheduler-scene" "dumpsys jobscheduler com.omarea.vtools"

run_cmd "processes-interesting" "ps -A | grep -Ei 'omarea|scene|therm|joyose|powerkeeper|miui.daemon|miuibooster|mcd|perfd|perf|surfaceflinger'"
run_cmd "service-states" "getprop | grep -Ei 'init.svc.(mi_thermald|thermal-engine|mcd|miuibooster|vendor.miperf|vendor_tcpdump|perfd|perf-hal|joyose|powerkeeper)'"
run_cmd "logcat-filtered" "logcat -d -b all | grep -Ei 'omarea|scene|therm|joyose|powerkeeper|miui.daemon|miuibooster|mcd|pangu|perf' | tail -n 4000"

run_cmd "thermal-dir-ls" "ls -laR /data/vendor/thermal /data/thermal 2>/dev/null"
run_cmd "thermal-dir-content" "find /data/vendor/thermal -maxdepth 3 -type f 2>/dev/null | sort | while read f; do echo \"===== \$f =====\"; ls -l \"\$f\"; if command -v sha1sum >/dev/null 2>&1; then sha1sum \"\$f\"; fi; sed -n '1,120p' \"\$f\" 2>/dev/null; echo; done"
run_cmd "mcd-state" "ls -ld /data/system/mcd 2>/dev/null; if command -v lsattr >/dev/null 2>&1; then lsattr -d /data/system/mcd 2>/dev/null; fi; find /data/system/mcd -maxdepth 2 \\( -type f -o -type d \\) 2>/dev/null | sort"

run_cmd "cpuset-state" "find /dev/cpuset -maxdepth 2 -type f 2>/dev/null | sort | while read f; do echo \"===== \$f =====\"; cat \"\$f\" 2>/dev/null; echo; done"
run_cmd "stune-state" "find /dev/stune -maxdepth 2 -type f 2>/dev/null | sort | while read f; do echo \"===== \$f =====\"; cat \"\$f\" 2>/dev/null; echo; done"
run_cmd "sched-nodes" "for f in /proc/sys/kernel/sched_* /sys/devices/system/cpu/cpufreq/policy*/scaling_governor /sys/devices/system/cpu/cpufreq/policy*/scaling_min_freq /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq /sys/module/*/parameters/*sched* /sys/module/*/parameters/*uclamp*; do if [ -e \"\$f\" ]; then echo \"===== \$f =====\"; cat \"\$f\" 2>/dev/null; echo; fi; done"

capture_file_head "/data/adb/modules/miui14cloud/module.prop" "files/miui14cloud/module.prop.txt"
capture_file_head "/data/adb/modules/miui14cloud/service.sh" "files/miui14cloud/service.sh.txt"
capture_file_head "/data/adb/modules/miui14cloud/Restore.sh" "files/miui14cloud/Restore.sh.txt"
capture_file_head "/data/adb/modules/miui14cloud/Extra.sh" "files/miui14cloud/Extra.sh.txt"
capture_file_head "/data/adb/modules/miui14cloud/Flashrate.sh" "files/miui14cloud/Flashrate.sh.txt"
capture_file_head "/data/adb/modules/miui14cloud/system.prop" "files/miui14cloud/system.prop.txt"
capture_tree_listing "/data/adb/modules/miui14cloud" "miui14cloud-tree"

capture_file_head "/data/adb/modules/scene_systemless/module.prop" "files/scene_systemless/module.prop.txt"
capture_file_head "/data/adb/modules/scene_systemless/service.sh" "files/scene_systemless/service.sh.txt"
capture_file_head "/data/adb/modules/scene_systemless/post-fs-data.sh" "files/scene_systemless/post-fs-data.sh.txt"
capture_tree_listing "/data/adb/modules/scene_systemless" "scene_systemless-tree"

capture_file_head "/data/adb/modules/scene_swap_controller/module.prop" "files/scene_swap_controller/module.prop.txt"
capture_file_head "/data/adb/modules/scene_swap_controller/service.sh" "files/scene_swap_controller/service.sh.txt"
capture_tree_listing "/data/adb/modules/scene_swap_controller" "scene_swap_controller-tree"

run_cmd "scene-module-markers" "find /data/adb/modules -maxdepth 3 -type f \\( -name disable -o -name remove -o -name update -o -name module.prop -o -name service.sh -o -name post-fs-data.sh \\) 2>/dev/null | grep -Ei 'scene|miui14cloud'"

run_cmd "done-marker" "echo collection_complete"
echo "$OUT_DIR"
