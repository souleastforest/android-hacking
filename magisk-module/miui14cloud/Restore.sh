# powerkeeper
pm enable com.miui.powerkeeper/com.xiaomi.mipush.sdk.PushMessageHandler
pm enable com.miui.powerkeeper/com.xiaomi.push.service.receivers.PingReceiver
pm enable com.miui.powerkeeper/com.xiaomi.mipush.sdk.MessageHandleService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.interrupt.InterruptsActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.ThermalConfigActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.current.CurrentService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.perfengine.PerfAccessibilityService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.thermal.ThermalDetailActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.thermalconfig.ThermalConfigReceiver
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.PowerToolsActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ai.AIEventReceiver
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.cpu.CpuFreqMinService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.ScenarioPowerSavingActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.cloudcontrol.CloudUpdateJobService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.processmem.ProcessMemService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.powerchecker.PowerCheckerService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.framerate.FrameRateSecretCodeReceiver
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.batterylife.BatteryStatusActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.CommonService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.HiddenAppsConfigActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.top.TopCmdService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.HiddenAppsContainerManagementActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.cloudcontrol.CloudUpdateReceiver
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.framerate.PowerToolsConfigActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.CloudInfoActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.PowerKeeperBackgroundService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.frame.FrameRate2Service
pm enable com.miui.powerkeeper/com.miui.powerkeeper.feedbackcontrol.abnormallog.ThermalLogService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.gpumem.GpuMemService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.logsystem.LogSystemService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.floating.MiFloatingService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.thermal.BoardTempService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.interrupt.InterruptsService
pm enable com.miui.powerkeeper/com.xiaomi.push.service.receivers.NetworkStatusReceiver
pm enable com.miui.powerkeeper/com.miui.powerkeeper.WakelockManagerService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.cpu.TimeInStateService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.provider.PowerKeeperConfigureProvider
pm enable com.miui.powerkeeper/com.miui.powerkeeper.resource.bigdata.resourcelight.GreenifyService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.cpu.CpuFreqCurService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.framerate.TopCmdService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.ui.powertools.module.batterydry.DryService
pm enable com.miui.powerkeeper/com.miui.powerkeeper.PowerKeeperReceiver
pm enable com.miui.powerkeeper/com.miui.powerkeeper.feedbackcontrol.FeedbackControlService
pm enable com.miui.securityadd/com.miui.gamebooster.pannel.PannelControlActivity
pm enable com.miui.powerkeeper/com.miui.powerkeeper.statemachine.PowerStateMachineService

# joyose
pm enable com.xiaomi.joyose/com.xiaomi.joyose.securitycenter.GPUTunerService
pm enable com.xiaomi.joyose/com.xiaomi.joyose.smartop.SmartOpService
pm enable com.xiaomi.joyose/com.xiaomi.joyose.cloud.LocalCtrlActivity
pm enable com.xiaomi.joyose/com.xiaomi.joyose.JoyoseBroadCastReceiver
pm enable com.xiaomi.joyose/com.xiaomi.joyose.cloud.CloudServerReceiver
pm enable com.xiaomi.joyose/com.xiaomi.joyose.smartop.gamebooster.receiver.BoostRequestReceiver

# miui daemon
pm enable com.miui.daemon/com.miui.daemon.performance.MiuiPerfService
pm enable com.miui.daemon/com.miui.daemon.performance.cloudcontrol.CloudControlSyncService
pm enable com.miui.daemon/com.miui.daemon.performance.mispeed.CloudServerReceiver
pm enable com.miui.daemon/com.miui.daemon.performance.server.ExecutorService
pm enable com.miui.daemon/com.miui.daemon.mqsas.jobs.HeartBeatUploadService

# thermal config
chattr -i -R /data/vendor/thermal/config/*
chmod 644 /data/vendor/thermal/config/*
rm -rf /data/vendor/thermal/config/*
chattr -Ri /data/system/mcd
mkdir /data/system/mcd
chmod 755 /data/system/mcd