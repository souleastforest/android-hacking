# shellcheck disable=SC2034
SKIPUNZIP=1

MODULE_MIN_MAGISK_VERSION=27005
MODULE_MIN_MAGISK_VERSION_NAME="Canary"
MODULE_MIN_KSU_KERNEL_VERSION=10940
MODULE_MIN_KSUD_VERSION=11903
MODULE_MIN_ZYGISKSU_VERSION=497

enforce_install_from_app() {
  if $BOOTMODE; then
    ui_print "- Installing from Magisk / KernelSU app"
  else
    ui_print "*********************************************************"
    ui_print "! Install from recovery is NOT supported"
    ui_print "! Recovery sucks"
    ui_print "! Please install from Magisk / KernelSU app"
    abort "*********************************************************"
  fi
}

check_magisk_version() {
  ui_print "- Magisk version: $MAGISK_VER_CODE"
  if [ "$MAGISK_VER_CODE" -lt "$MODULE_MIN_MAGISK_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! Please install Magisk $MODULE_MIN_MAGISK_VERSION_NAME (>$MODULE_MIN_MAGISK_VERSION)"
    abort    "*********************************************************"
  fi
}

check_ksu_version() {
  ui_print "- KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
  if ! [ "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt "$MODULE_MIN_KSU_KERNEL_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! KernelSU version is too old!"
    ui_print "! Please update KernelSU to latest version"
    abort    "*********************************************************"
  elif false; then
    ui_print "*********************************************************"
    ui_print "! KernelSU version abnormal!"
    ui_print "! Please integrate KernelSU into your kernel"
    ui_print "  as submodule instead of copying the source code"
    # abort    "*********************************************************"
  fi
  if ! [ "$KSU_VER_CODE" ] || [ "$KSU_VER_CODE" -lt "$MODULE_MIN_KSUD_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! ksud version is too old!"
    ui_print "! Please update KernelSU Manager to latest version"
    abort    "*********************************************************"
  fi
}

check_zygisksu_version() {
  ZYGISKSU_VERSION=$(grep versionCode < /data/adb/modules/zygisksu/module.prop | sed 's/versionCode=//g')
  ui_print "- Zygisk Next version: $ZYGISKSU_VERSION"
  if ! [ "$ZYGISKSU_VERSION" ] || [ "$ZYGISKSU_VERSION" -lt "$MODULE_MIN_ZYGISKSU_VERSION" ]; then
    ui_print "*********************************************************"
    ui_print "! Zygisk Next version is too old!"
    ui_print "! Please update Zygisk Next to latest version"
    abort    "*********************************************************"
  fi
}

VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "- Shamiko version ${VERSION}"

# Extract verify.sh
ui_print "- Extracting verify.sh"
unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
if [ ! -f "$TMPDIR/verify.sh" ]; then
  ui_print "*********************************************************"
  ui_print "! Unable to extract verify.sh!"
  ui_print "! This zip may be corrupted, please try downloading again"
  abort    "*********************************************************"
fi
. "$TMPDIR/verify.sh"

extract "$ZIPFILE" 'customize.sh' "$TMPDIR"
extract "$ZIPFILE" 'verify.sh' "$TMPDIR"

enforce_install_from_app
if [ "$KSU" ]; then
  check_ksu_version
  check_zygisksu_version
else
  check_magisk_version
fi

# Check architecture
if [ "$ARCH" != "arm" ] && [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86" ] && [ "$ARCH" != "x64" ]; then
  abort "! Unsupported platform: $ARCH"
else
  ui_print "- Device platform: $ARCH"
fi

if [ "$API" -lt 27 ]; then
  abort "! Only support Android 8.1+ devices"
fi

extract "$ZIPFILE" 'module.prop'           "$MODPATH"
extract "$ZIPFILE" 'sepolicy.rule'         "$MODPATH"
extract "$ZIPFILE" 'post-fs-data.sh'       "$MODPATH"
extract "$ZIPFILE" 'uninstall.sh'          "$MODPATH"
extract "$ZIPFILE" 'service.sh'            "$MODPATH"
extract "$ZIPFILE" 'cleanup.sh'            "$MODPATH"

ui_print "- Extracting zygisk libraries"
if [ "$ARCH" = "arm" ] || [ "$ARCH" = "arm64" ] ; then
  extract "$ZIPFILE" 'zygisk/armeabi-v7a.so' "$MODPATH"
  extract "$ZIPFILE" 'zygisk/arm64-v8a.so'   "$MODPATH"
  extract "$ZIPFILE" 'machikado.arm'         "$MODPATH"
  mv "$MODPATH/machikado.arm" "$MODPATH/machikado"
elif [ "$ARCH" = "x86" ] || [ "$ARCH" = "x64" ]; then
  extract "$ZIPFILE" 'zygisk/x86.so'         "$MODPATH"
  extract "$ZIPFILE" 'zygisk/x86_64.so'      "$MODPATH"
  extract "$ZIPFILE" 'machikado.x86'         "$MODPATH"
  mv "$MODPATH/machikado.x86" "$MODPATH/machikado"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644

ui_print "- Install cleanup script"
mkdir -p /data/adb/post-fs-data.d
cat "$MODPATH/cleanup.sh" > /data/adb/post-fs-data.d/.shamiko_cleanup.sh
chmod +x /data/adb/post-fs-data.d/.shamiko_cleanup.sh

ui_print "- これで勝ったと思うなよ―――!!"
