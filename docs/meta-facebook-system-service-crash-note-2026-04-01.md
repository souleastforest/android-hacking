# Meta 预装系统服务循环崩溃记录（2026-04-01）

## 结论

周期性弹出的“发送报告给系统”并不是 `KernelSU`、`LSPosed` 或主题实验直接引起的。

根因是 MIUI 预装的 Meta/Facebook 系统组件循环崩溃，主要是：

- `com.facebook.services`
- `com.facebook.system`

其中实际最频繁触发弹窗的是：

- `com.facebook.services`
- 服务：`com.facebook.oxygen.services.fbns.PreloadedFbnsService`

## 现场证据

### 包信息

- `com.facebook.services`
  - codePath: `/system/priv-app/facebook-services`
  - versionName: `94.0.26`
- `com.facebook.system`
  - codePath: `/system/priv-app/facebook-installer`
  - versionName: `94.0.26`

### 崩溃堆栈

`dropbox` 与 `logcat` 中重复出现同一异常：

```text
java.lang.NullPointerException: Attempt to invoke virtual method
'android.content.res.Configuration android.content.res.Resources.getConfiguration()'
on a null object reference
    at android.app.ConfigurationController.updateLocaleListFromAppContext(ConfigurationController.java:275)
    at android.app.ActivityThread.handleBindApplication(ActivityThread.java:7091)
```

### 触发链路

日志显示：

- `com.instagram.android` 会拉起 `com.facebook.services`
- 系统随后启动 `com.facebook.oxygen.services.fbns.PreloadedFbnsService`
- 进程在 `handleBindApplication()` 阶段直接崩溃
- ActivityManager 再次调度重启服务
- 系统弹出 crash dialog

这解释了为什么该弹窗会“隔一阵就自己弹出来”。

## 处理结果

已对当前用户禁用以下包：

- `com.facebook.services`
- `com.facebook.appmanager`
- `com.facebook.system`
- `com.facebook.katana`

禁用命令：

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell su -c 'pm disable-user --user 0 com.facebook.services; pm disable-user --user 0 com.facebook.appmanager; pm disable-user --user 0 com.facebook.system; pm disable-user --user 0 com.facebook.katana'
```

禁用后状态为：

- `enabled=3`
- 即 `disabled-user`

## 影响

如果当前不依赖 Facebook / Instagram 相关后台联动，这个处理是合理的。

可能影响：

- Meta 相关后台推送
- 预装 Meta 组件的静默更新或联动
- 部分 Facebook/Instagram 深层系统集成

通常不影响设备本身稳定性，反而能阻止反复出现的 crash dialog。

## 恢复命令

如需恢复：

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell su -c 'pm enable com.facebook.services; pm enable com.facebook.appmanager; pm enable com.facebook.system; pm enable com.facebook.katana'
```

## 备注

同时间段内还观察到一次独立的 `org.lsposed.manager` 资源异常记录，但它与该截图所示的反复弹窗不是同一根因。
