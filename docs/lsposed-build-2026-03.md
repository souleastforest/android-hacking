# LSPosed 模块构建调研总结（2026-03）

## 结论（当前时间点）

1. **新项目优先使用 Modern Xposed API（libxposed）**，而不是只靠 legacy `assets/xposed_init` 方案。
2. Modern API 的模块入口和配置不再依赖旧 manifest meta-data，而是走：
   - `META-INF/xposed/java_init.list`
   - `META-INF/xposed/module.prop`
   - `META-INF/xposed/scope.list`
3. 截至 2026-03-31，`libxposed/api` 最新版本为 **101.0.1**（发布于 2026-03-31）。
4. 在 LSPosed 生态里，legacy 模块仍兼容，但建议采用 **Modern + Legacy 双轨兼容**，降低 ROM/框架差异风险。

## 关键来源（官方/一手）

1. LSPosed Wiki（Modern API 开发）  
   <https://github.com/LSPosed/LSPosed/wiki/Develop-Xposed-Modules-Using-Modern-Xposed-API>
2. libxposed/api README  
   <https://github.com/libxposed/api>
3. libxposed/api Releases（101.0.1）  
   <https://github.com/libxposed/api/releases>
4. libxposed/example（官方示例工程）  
   <https://github.com/libxposed/example>
5. rovo89 Xposed legacy 教程（用于兼容路径参考）  
   <https://github.com/rovo89/XposedBridge/wiki/Development-tutorial>

## 对本项目的落地策略

### A. 结构策略：Modern + Legacy 双轨

1. **Modern 入口**  
   `src/main/resources/META-INF/xposed/java_init.list`
2. **Modern 配置**  
   `src/main/resources/META-INF/xposed/module.prop`
3. **Modern 作用域**  
   `src/main/resources/META-INF/xposed/scope.list`
4. **Legacy 入口保留**  
   `assets/xposed_init`

### B. 构建策略

1. 构建脚本同时准备：
   - legacy API jar（用于 `IXposedHookLoadPackage` 兼容）
   - modern API aar（提取 `classes.jar` 用于 `XposedModule` 编译）
2. APK 打包后，额外注入 `META-INF/xposed/*` 到最终产物。
3. 保留 `d8 -> dx` 回退，规避当前机器上的 `d8` 内部异常导致构建中断。

## 风险与验证

1. 某些 ROM/框架组合下，单纯 legacy 或单纯 modern 可能出现识别差异。
2. 双轨后验证要点：
   - LSPosed 是否识别模块并加载入口类
   - 目标作用域（`com.giffgaffmobile.controller` / `com.giffgaffmobile.app`）是否命中
   - Hook 日志是否出现 `hasSystemFeature` / `EuiccManager` 相关命中

## 当前改进结果摘要

1. 已补充 Modern API 配置文件与入口类。
2. 已将构建脚本升级为 dual-mode 构建，且将 `META-INF/xposed/*` 注入 APK。
3. 已保留 legacy 兼容路径，避免直接切换导致不可用。
