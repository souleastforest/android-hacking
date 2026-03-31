# Runtime Forensics

这是一个只读取证工具，用来采集 `Scene LP`、`miui14cloud`、MIUI 热控/调度/待机相关的运行态信息。

## 为什么先用脚本，不先做 KSU 模块

- 取证阶段优先避免再引入新的开机时序变量。
- `adb + su` 脚本可以在你当前真实状态下立即抓取快照。
- 如果后续需要“睡前自动采集一次，醒来再采集一次”，再把同一套采集逻辑封装成 KSU 模块更稳。

## 会采集什么

- `getprop` 全量和热控/调度相关过滤项
- `Scene`、`powerkeeper`、`joyose`、`miui.daemon` 的 `dumpsys package`
- `settings` / `device_config` / `deviceidle` / `jobscheduler` / `alarm` 相关状态
- 关键进程与 `init.svc.*` 服务状态
- `/data/vendor/thermal`、`/data/system/mcd`、`/dev/cpuset`、`/dev/stune`、部分 `sched/cpufreq` 节点
- `miui14cloud`、`scene_systemless`、`scene_swap_controller` 模块脚本和目录信息
- 关键关键词过滤后的 `logcat`

## 用法

```bash
cd /Users/saigyoujiyuyuko/Desktop/hacking-^_^/runtime-forensics
./collect-runtime-forensics.sh --label sleep-before
```

输出目录默认在：

```text
/Users/saigyoujiyuyuko/Desktop/hacking-^_^/logs/runtime-forensics/<timestamp>-sleep-before
```

## 建议取证顺序

1. 在“`miui14cloud` 已禁用，`Scene LP` 保持开启”的当前状态下执行一次：
   `./collect-runtime-forensics.sh --label current`
2. 睡前再执行一次：
   `./collect-runtime-forensics.sh --label sleep-before`
3. 第二天醒来立刻执行一次：
   `./collect-runtime-forensics.sh --label sleep-after`
4. 对比三个快照里的：
   - `thermal-dir-content`
   - `mcd-state`
   - `service-states`
   - `settings-global-filtered`
   - `device-config-activity-manager`
   - `alarm-filtered`
   - `batterystats-filtered`

## 风险

- 设计目标是只读采集，不主动修改系统状态。
- 但 `dumpsys` / `logcat` 输出量较大，第一次运行可能需要几十秒。
