MODDIR=${0%/*}
MODULE_MIN_MAGISK_VERSION=27005
MODULE_MIN_ZYGISKSU_VERSION=497
MAGISK_VERSION="$(magisk -V)"
# shellcheck disable=SC2117
KSU_VERSION="$(su -V)"
if [ -z "$MAGISK_VERSION" ]; then
  ZYGISKSU_VERSION=$(grep versionCode < /data/adb/modules/zygisksu/module.prop | sed 's/versionCode=//g')
  if [ "$KSU_VERSION" -lt "$MODULE_MIN_KSUD_VERSION" ] || [ -z "$ZYGISKSU_VERSION" ] || [ "$ZYGISKSU_VERSION" -lt "$MODULE_MIN_ZYGISKSU_VERSION" ]; then
   touch "$MODDIR/disable"
  fi
elif [ "$MAGISK_VERSION" -lt "$MODULE_MIN_MAGISK_VERSION" ]; then
  touch "$MODDIR/disable"
fi

if [ -d /data/adb/modules/zygisksu ]; then
  mkdir -p /data/adb/zygisksu
  touch /data/adb/zygisksu/no_mount_znctl
fi

if [ ! -f /data/adb/post-fs-data.d/.shamiko_cleanup.sh ]; then
  mkdir -p /data/adb/post-fs-data.d
  cat "$MODDIR/cleanup.sh" > /data/adb/post-fs-data.d/.shamiko_cleanup.sh
  chmod +x /data/adb/post-fs-data.d/.shamiko_cleanup.sh
fi
