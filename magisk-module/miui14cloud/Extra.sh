#!/system/bin/sh

#Extra

lock_value() {
    if [ -f "$1" ]; then
        chown root:root "$1"
        chmod 0666 "$1"
        echo "$2" >"$1"
        chmod 0444 "$1"
    fi
}
powerkeeper(){
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.ThermalConfigActivity
pm disable com.miui.powerkeeper/com.miui.powerkeeper.thermalconfig.ThermalConfigReceiver
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.cpu.CpuFreqMinService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.cloudcontrol.CloudUpdateJobService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.processmem.ProcessMemService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.cloudcontrol.CloudUpdateReceiver
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.framerate.PowerToolsConfigActivity
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.CloudInfoActivity
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.gpumem.GpuMemService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.logsystem.LogSystemService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.thermal.BoardTempService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.cpu.TimeInStateService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.cpu.CpuFreqCurService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.ui.framerate.TopCmdService
pm disable com.miui.powerkeeper/com.miui.powerkeeper.PowerKeeperReceiver
pm disable com.miui.powerkeeper/com.miui.powerkeeper.statemachine.PowerStateMachineService
}

joyose(){
pm disable com.xiaomi.joyose/com.xiaomi.joyose.securitycenter.GPUTunerService
pm disable com.xiaomi.joyose/com.xiaomi.joyose.smartop.SmartOpService
pm disable com.xiaomi.joyose/com.xiaomi.joyose.cloud.LocalCtrlActivity
pm disable com.xiaomi.joyose/com.xiaomi.joyose.JoyoseBroadCastReceiver
pm disable com.xiaomi.joyose/com.xiaomi.joyose.cloud.CloudServerReceiver
pm disable com.xiaomi.joyose/com.xiaomi.joyose.smartop.gamebooster.receiver.BoostRequestReceiver
}

miui_daemon(){
pm disable com.miui.daemon/com.miui.daemon.performance.MiuiPerfService
pm disable com.miui.daemon/com.miui.daemon.performance.cloudcontrol.CloudControlSyncService
pm disable com.miui.daemon/com.miui.daemon.performance.mispeed.CloudServerReceiver
pm disable com.miui.daemon/com.miui.daemon.performance.server.ExecutorService
pm disable com.miui.daemon/com.miui.daemon.mqsas.jobs.HeartBeatUploadService
}

# disablecloud control
powerkeeper
joyose
miui_daemon

# fpsgo and ged
fpsgo_and_ged(){
fpsgo=/sys/kernel/fpsgo/common/fpsgo_enable
ged_kpi=/sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
lock_value $fpsgo 0
lock_value $gedkpi 0
}
# fpsgo_and_ged

# stop
stop mcd_service
stop miuibooster
stop mi_thermald
stop vendor.miperf
stop vendor_tcpdump

# extra
device_config put activity_manager max_cached_processes 2147483647
device_config put activity_manager max_phantom_processes 2147483647