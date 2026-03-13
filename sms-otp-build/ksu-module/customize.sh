#!/system/bin/sh
# customize.sh - KernelSU 模块安装脚本
# 在模块安装时执行（不是在启动时）

ui_print "- SMS OTP AutoFill Module"
ui_print "- by souleastforest"
ui_print ""
ui_print "- Installing Companion App to priv-app..."

# KernelSU 会自动处理 system/ 目录的 overlay，这里只做提示
if [ -f "$MODPATH/system/priv-app/SmsOtpCompanion/SmsOtpCompanion.apk" ]; then
    ui_print "  [OK] Companion APK found"
else
    ui_print "  [WARN] Companion APK NOT found in module package"
    ui_print "         Please build Companion App first: ./build.sh"
fi

ui_print ""
ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH/ksu-module" root root 0755 0644
set_perm "$MODPATH/ksu-module/service.sh" root root 0755
set_perm "$MODPATH/ksu-module/post-fs-data.sh" root root 0755

ui_print "- Done! Reboot to activate."
