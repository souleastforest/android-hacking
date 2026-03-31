# giffgaff eSIM 调试总结（2026-03-31）

## 背景

目标是在一台不原生支持内建 eUICC 的 `Xiaomi / POCO F5 (marble)` 设备上，通过：

- `KernelSU`
- `9eSIM` 可移除 eUICC 卡
- `OpenEUICC`
- `giffgaff app`

完成 `giffgaff eSIM` 的识别、下单、写卡和激活。

## 环境信息

- 设备：`Xiaomi 23049PCD8G / marble`
- 系统：`MIUI 14 / Android 13`
- Root：`KernelSU`
- eSIM 卡：`9eSIM`
- LPA 方案：`OpenEUICC`
- 目标运营商：`giffgaff`

## 问题演进

### 1. 初始状态

最开始 `giffgaff app` 直接提示：

- `This phone doesn't support eSIM`

此时说明应用前置能力检查未通过，`EuiccManager` / 系统 eSIM 能力未真正暴露给应用。

### 2. 早期尝试

做过两类尝试：

1. `LSPosed/Xposed` 路线
   - 通过兼容旧 API 的 `legacy` 模块绕过 `minApiVersion=101`
   - 让 `giffgaff` 前端页面能够继续往下走
   - 但这条线只能骗过部分 capability gate，不能补出系统级 eSIM 栈

2. 直接手搓 `/data/adb/modules` 的系统挂载
   - 风险很高
   - 之前已造成过无限重启
   - 结论是不再继续走这条路

### 3. KernelSU 系统挂载问题定位

排查后确认：

- 现代 `KernelSU` 的 `/system` 覆盖依赖 `metamodule`
- 仅有 `system.prop` 生效，不代表 `system/priv-app` 与 `system/etc/permissions` 已真正挂入 live `/system`

因此引入官方参考 `metamodule`：

- `meta-overlayfs`

安装后验证：

- `OpenEUICC.apk` 已进入 `/system/priv-app/OpenEUICC/OpenEUICC.apk`
- `/system/etc/permissions/android.hardware.telephony.euicc.xml` 已存在
- `pm list features` 出现：`android.hardware.telephony.euicc`
- `OpenEUICC` 获得关键特权权限：
  - `WRITE_EMBEDDED_SUBSCRIPTIONS`
  - `READ_PRIVILEGED_PHONE_STATE`
  - `MODIFY_PHONE_STATE`
  - `SECURE_ELEMENT_PRIVILEGED_OPERATION`

到这一步，系统级 eSIM 集成链路打通。

## 验证阶段

### 4. OpenEUICC / 9eSIM 验证

验证结果：

- `OpenEUICC` 能读取 `9eSIM` 卡与 `EID`
- `9eSIM` 官方 App 能成功写入标准 eSIM profile
- `OpenEUICC` 也能成功写入标准 eSIM profile
- `Nomad` 测试 profile 可通过标准 `LPA:1$...` 方式安装

这一步说明：

- 卡没问题
- `OpenEUICC` 没问题
- 标准 `SM-DP+ / Matching ID / LPA` 下载安装链路没问题

### 5. giffgaff 进入下一阶段

在 `OpenEUICC` 集成成功后，`giffgaff app` 不再停留在：

- `This phone doesn't support eSIM`

而是能：

- 识别 eSIM 能力
- 进入 eSIM 购买/安装路径
- 触发系统 `EuiccManager / OpenEuiccService`

但最终仍在 app 内失败，提示类似：

- `You can't get an eSIM on this phone right now`

这说明前置 capability gate 已突破，但 app 的原生安装流程仍未成功。

## 抓取与分析

### 6. 先用 tcpdump 确认域名

通过 ADB + root + `tcpdump` 抓 TLS SNI，确认关键域名：

- `publicapi.giffgaff.com`
- `static.giffgaff.com`

结论：

- 关键业务接口走 `publicapi.giffgaff.com/gateway/graphql`
- 纯 pcap 只能定位域名，拿不到 HTTPS 明文 payload

### 7. 用 Frida 动态抓应用内明文

在 macOS 本机安装：

- `frida-tools 17.9.1`
- `frida-server 17.9.1 android-arm64`

并将 `frida-server` 推送到设备：

- `/data/local/tmp/frida-server`

随后对 `giffgaff` 进行动态 hook，覆盖三套网络栈：

- `okhttp3`
- `com.android.okhttp`
- `Cronet`

最终成功抓到 `giffgaff` 的 GraphQL 响应。

## 关键结论

### 8. 成功提取到 giffgaff 的标准 eSIM 安装参数

从：

- `https://publicapi.giffgaff.com/gateway/graphql`

的响应中，成功拿到：

- `host=cel.prod.ondemandconnectivity.com`
- `matchingId=401565D0369E5FD98EEF3DA746C6DD6A3E08B2F8F572E948BB7C913E3695D3B9`
- `lpaString=LPA:1$cel.prod.ondemandconnectivity.com$401565D0369E5FD98EEF3DA746C6DD6A3E08B2F8F572E948BB7C913E3695D3B9`

### 9. 最终结论

`giffgaff` 并不是“完全黑盒、只能靠 app 写卡”。

它后端最终还是下发了标准 eSIM 安装参数，只是：

- `giffgaff app -> 原生 setUp -> 系统安装` 这条最后一跳在当前设备/环境里不稳定或不兼容

但由于标准 `LPA` 参数已经提取出来，因此可以：

- 绕开 `giffgaff app` 的最后一步
- 直接将 `LPA:1$...` 导入 `OpenEUICC` 或 `9eSIM`
- 成功完成安装

## 当前状态

截至本次调试结束：

- `giffgaff eSIM` 已成功安装
- `giffgaff` 的标准下载参数已可重复提取
- 主链路已经从“修 app 内原生安装”转为“提取参数后手工导入”

## 后续建议

### 可重复流程

后续若再次遇到 `giffgaff app` 安装失败，可按以下流程复用：

1. 在 `giffgaff app` 内走到 eSIM 安装流程
2. 用 Frida hook `publicapi.giffgaff.com/gateway/graphql`
3. 提取：
   - `host`
   - `matchingId`
   - `lpaString`
4. 将 `lpaString` 直接导入 `OpenEUICC` / `9eSIM`

### 如果要进一步自动化

后续可做两件事：

1. 把 Frida 提取流程固化成脚本
2. 直接从 GraphQL 响应里自动输出 `LPA:1$...`，减少手工步骤
