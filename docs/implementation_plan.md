# eSIM Hardware Bypass for giffgaff (Strategy D: Xposed Module, 2026-03 Upgrade)

## 背景
前置尝试的 KernelSU system/ overlay 方法受到 MIUI 底层 `/system/etc/permissions/` OverlayFS 挂载的遮蔽，导致 `PackageManager` 无法读到注入的 [android.hardware.telephony.euicc.xml](file:///Users/saigyoujiyuyuko/Desktop/hacking-%5E_%5E/esim-bypass-build/ksu-module/system/etc/permissions/android.hardware.telephony.euicc.xml)。
同时，由于 giffgaff App 强行屏蔽了不具备该 Feature 设备的 eSIM 激活入口 UI，导致无法抓取后端 API 包（网络侧请求未发出）。

**最终破局点：** 用户设备安装了 LSPosed。通过 Xposed 模块，可以直接在内存中 Hook `PackageManager` 和 `EuiccManager` 的 API 并篡改返回值，绕过所有文件系统限制。

## Proposed Changes

> 2026-03 更新：按 LSPosed Modern API 现状，采用 **Modern + Legacy 双轨兼容** 构建。

创建一个极简的 Xposed 模块 `esim-xposed-build/`，通过 `javac` 和 `d8` 直接将 Java 代码编译为 `classes.dex`，无需经过 Gradle 的复杂编译环节。

### [UPDATED] [build.sh](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/build.sh)
1. 自动探测本机 Android SDK、最新 `build-tools` 和可用 `android.jar`。
2. 准备 legacy API 依赖（`api-82.jar`）用于旧接口兼容。
3. 准备 modern API 依赖（`api-101.0.1.aar`，提取 `classes.jar`）用于 `XposedModule` 编译。
4. 使用 `javac` 编译 `src/com/**`（或 fallback `src/**`）源码到 `.class`。
5. 优先使用 `d8` 将 `.class` 转为 `classes.dex`；若遇到本机 `d8` 内部异常则自动回退 `dx`。
6. 使用 `aapt` 打包 [AndroidManifest.xml](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/AndroidManifest.xml) 与 `assets` 生成基础 APK。
7. 注入 `classes.dex` 与 `META-INF/xposed/*`（modern 模块配置）。
8. 优先使用 `apksigner` 签名（不可用时回退 `jarsigner`）。

### [NEW] [AndroidManifest.xml](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/AndroidManifest.xml)
声明 Xposed 模块的 Meta-data：
- `xposedmodule`, `xposeddescription`, `xposedminversion`

### [NEW] [assets/xposed_init](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/assets/xposed_init)
legacy 入口：`com.souleastforest.esimbypass.EsimHook`

### [NEW] [META-INF/xposed/java_init.list](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/src/main/resources/META-INF/xposed/java_init.list)
modern 入口：`com.souleastforest.esimbypass.EsimHookModern`

### [NEW] [META-INF/xposed/module.prop](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/src/main/resources/META-INF/xposed/module.prop)
modern API 声明：`minApiVersion=101`, `targetApiVersion=101`, `staticScope=true`

### [NEW] [META-INF/xposed/scope.list](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/src/main/resources/META-INF/xposed/scope.list)
默认作用域：`com.giffgaffmobile.controller` 与 `com.giffgaffmobile.app`

### [NEW] [EsimHook.java](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/src/com/souleastforest/esimbypass/EsimHook.java)
- Hook 目标包名：`com.giffgaffmobile.controller`（兼容旧包 `com.giffgaffmobile.app`），避免全局污染。
- Hook `android.app.ApplicationPackageManager.hasSystemFeature(String)` 与重载 `hasSystemFeature(String, int)`，如果入参为 `android.hardware.telephony.euicc` 则返回 `true`。
- Hook `android.telephony.euicc.EuiccManager.isEnabled()`，返回 `true`。
- Hook `android.telephony.euicc.EuiccManager.getEid()`，返回固定 fake EID，避免因空 EID 被判定不支持。
- Hook `android.telephony.euicc.EuiccManager.getEuiccInfo()`，当原始结果为 `null` 时返回 synthetic `EuiccInfo`。

### [NEW] [EsimHookModern.java](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/src/com/souleastforest/esimbypass/EsimHookModern.java)
- 实现 `io.github.libxposed.api.XposedModule`。
- 在 `onPackageReady` 按包名筛选后进行 Method Hook。
- 覆盖 `hasSystemFeature` / `isEnabled` / `getEid` 核心路径，实现 Modern API 等效能力。

## Risk Controls

1. 模块默认只在 giffgaff 进程生效，不 Hook 全局框架。
2. 每个 Hook 都有异常捕获并写 Xposed log，避免单点失败导致进程崩溃。
3. 若目标 App 升级导致调用路径变化，优先通过日志确认命中，再决定是否补 Hook。

## Verification Plan

1. 执行 [build.sh](file:///Users/saigyoujiyuyuko/Desktop/hacking-^_^/esim-xposed-build/build.sh) 构建 `esim-bypass-xposed.apk`。
2. 通过 ADB 安装该 APK：`./platform-tools/adb install -r ./esim-bypass-output/esim-bypass-xposed.apk`。
3. 在 LSPosed 中启用模块，作用域勾选当前 giffgaff 包（`com.giffgaffmobile.controller`；旧版可能为 `com.giffgaffmobile.app`）。
4. 打开 giffgaff，观察是否进入 eSIM 订购/激活流程。
5. 检查 Xposed 日志是否出现以下关键命中：
   - `hasSystemFeature(...)-> true`
   - `EuiccManager.isEnabled() -> true`
   - `EuiccManager.getEid() -> fake eid`
6. 检查模块加载日志中是否出现 modern/legacy 任一路径加载成功（dual-mode）。
7. 若 UI 已放行但下发失败，则回到 PCAPdroid 抓取 LPA 字符串并手动写入 9esim。
