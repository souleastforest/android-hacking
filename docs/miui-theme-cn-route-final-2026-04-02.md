# MIUI 国区主题链路最终打通方案

日期：`2026-04-02`

## 结论

在这台设备上，国区主题主流程最终是通过下面这条链打通的：

1. 用 `/data` cover 让 `com.android.thememanager 4.0.1.4` 生效
2. 用 `Vector` 替代旧 `LSPosed`，并把 Zygisk 排除列表策略改成 `仅还原挂载变更`
3. 用自定义 `Theme CN Identity Hook` 运行时改写国区身份和请求
4. 分别修通两条不同的在线链路：
   - `zurt -> controller.online.g` 这条主题更新/关联链
   - `page/v3` / `page/v3/classification` 这条首页/分类内容链

结果是：

- `首页`、`分类`、`每日精选` 都能正常出内容
- `page/v3` / `classification` 请求已从原来的 `HK/global/TMREUXM + 404` 变成 `CN/non-global/TMRCNXM + 200`

## 设备与软件基线

- 设备：`POCO F5 / marble`
- ROM：`MIUI 14 Global / Android 13`
- Root：`KernelSU`
- 注入框架：`Vector`
- 主题主包：`com.android.thememanager 4.0.1.4`
- 当前自定义模块：
  - [theme-cn-identity-hook-1.1-legacyfix.apk](/Users/saigyoujiyuyuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/output/theme-cn-identity-hook-1.1-legacyfix.apk)

## 为什么前面的路线不稳定

### 1. 直接刷分区镜像风险高

真实替换 `product/system_ext` 虽然理论上最干净，但这台机器在重打镜像后出现过 bootloop，调试成本太高。

### 2. 纯 Hybrid Mount 不够

`Hybrid Mount` 在一部分链路上能让 shell/system_server 看到替换结果，但对主题 app 进程并不总是可靠，尤其是早期阶段会出现：

- shell 看到的是 China APK
- app 进程实际仍按 Global 资源视图运行

### 3. 只装国区 APK 不够

`ThemeManager` 和 `ThemeStore` 的问题不是单点安装，而是：

- 客户端身份不自洽
- 多条网络链路分别走不同构造层
- 部分接口会因为本地主题状态不合法而被服务端拒绝

## 最终有效方案

### Step 1: `/data` cover 国区 ThemeManager

不是去真实替换 `/product`，而是让系统主包仍保持同一包名：

- 包名：`com.android.thememanager`
- 生效版本：`4.0.1.4`
- 运行位置：`/data/app/.../base.apk`

这条路的价值是：

- 保持 Android 标准“系统 app 被 `/data` 更新包覆盖”模型
- 避开直接刷分区的风险
- 避开一部分 app namespace 可见性问题

### Step 2: 修正 Vector 注入条件

真正的转折点不是模块代码先变对，而是 `Vector` 终于真正注入了 `ThemeManager`。

关键设置：

- Zygisk 排除列表策略从 `强制` 改成 `仅还原挂载变更`

如果保持 `强制`：

- `com.android.thememanager` 不会真正被注入
- 自定义 hook 没有执行机会

### Step 3: 运行时改写国区身份

自定义模块会把主题请求身份从：

- `region=HK`
- `isGlobal=true`
- `version=13_V14.0.9.0.TMREUXM`

改成：

- `region=CN`
- `isGlobal=false`
- `version=13_V14.0.27.0.TMRCNXM`

相关源码：

- [ThemeCnIdentityLegacyEntry.java](/Users/saigyoujiyuyuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/src/com/souleastforest/themecnidentity/ThemeCnIdentityLegacyEntry.java)
- [RewriteCore.java](/Users/saigyoujiyuyuko/Desktop/hacking-^_^/thememanager-cn-identity-hook-build/src/com/souleastforest/themecnidentity/RewriteCore.java)

### Step 4: 修通 `checkupdate/hashpair`

这条接口之前一直是 `406 Not Acceptable`。

最终确认的根因不是：

- `Cookie`
- `usedThemesHistory` 缺失
- `currentTheme` 缺失
- `requestFlag`

而是：

- 它拿了纯本地主题去做在线更新检查
- 这些条目表现为：
  - `onlineId=null`
  - 或 `no_online_id`

修法：

- 对 `checkupdate/hashpair` 的 `fileshash` 只保留在线主题条目
- 过滤掉本地主题资源

这一步之后，`checkupdate/hashpair` 从 `406` 变成 `200`

### Step 5: 修通首页/分类的主内容链

`每日精选` 先能通，不代表首页和分类已经通。

原因是：

- `每日精选` 主要走 H5/活动页链
- `首页` / `分类` 走的是：
  - `thm/page/v3`
  - `thm/page/v3/classification`

前面修好的 `zurt -> controller.online.g` 不覆盖这条链。

最后真正命中的修法是：

- 在最终 OkHttp Request build 点统一重写 URL
- 关键 hook 点是混淆后的：
  - `okhttp3.jp0y$k.toq()`

在这个点统一把最终请求改成：

- `region=CN`
- `isGlobal=false`
- `version=13_V14.0.27.0.TMRCNXM`

这一步之后：

- `page/v3` 从 `404` 变成 `200`
- `classification` 从 `404` 变成 `200`

## 已修通的在线链路

1. `bullet`
2. `relatemodule/hashpair`
3. `checkupdate/hashpair`
4. `themeActivity / h5config`
5. `page/v3`
6. `page/v3/classification`

## 回滚点

### 回退 ThemeManager `/data` cover

```bash
~/Desktop/hacking-^_^/platform-tools/adb shell su -c 'pm uninstall com.android.thememanager'
```

### 停用运行时 hook

在 `Vector` 里禁用：

- `Theme CN Identity Hook`

## 当前判断

这条链当前的核心价值是：

- 不碰真实分区镜像
- 不依赖不稳定的系统级替换
- 在现有 Global ROM 上，把 China ThemeManager 主流程跑起来

这不是“只装了一个国区 APK”就成功，而是：

- `/data cover`
- 正确的 Vector 注入条件
- 两条不同请求链的逐层修补

共同作用的结果。
