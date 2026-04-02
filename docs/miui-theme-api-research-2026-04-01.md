# MIUI / HyperOS Theme Store API Research

Date: 2026-04-01

## TL;DR

- 2026-04 看到的“半残、404、空数组、null object”更像是 **Xiaomi 主题生态的服务端退化 + 客户端分裂**，而不是单纯的本地系统故障。
- 官方现在公开的稳定入口不是“通用 API”，而是：
  - Theme App / ThemeStore 的**应用内流程**
  - Xiaomi 账号区域 / 系统区域
  - 官方 Theme Designer 审核门户
- 可验证的社区 workaround 主要是：
  - 切换区域（尤其 India）
  - 通过浏览器/creator profile 的 `theme://` 链接打开
  - 使用带“Import themes”的改版 Theme Manager
  - Android 13 上配合关闭签名校验 / Core Patch LSPosed
- 对当前 **MIUI 14 Global + cover 方案** 的实际意义：
  - **保留 `com.android.thememanager 4.0.1.4` 的 `/data` cover 路线**
  - **把 `com.miui.themestore` 当 trampoline/壳，不当完整商店**
  - 在线 catalog 不要再当作稳定依赖，只把它当“best effort”

## Why the store looks half-dead

### 1) Xiaomi 已经把“主题”拆成了壳 + 主程序 + 区域化服务

我们本地抓到的行为和公开文档对得上：

- `com.miui.themestore` 更像跳板壳，启动后会转到 `com.android.thememanager`
- `com.android.thememanager` 才是实际主题能力的主体

官方支持文档也说明，Themes 的内容和货币/可见性取决于：

- Xiaomi 账号区域
- 设备系统区域

来源：
- Xiaomi support: [Why does the Themes App on my Xiaomi phone show a different currency from my region?](https://www.mi.com/global/support/article/KA-608592/)

### 2) 服务端 / 内容层明显在收缩

我们在本地设备上看到的现象包括：

- `Http response: code=404`
- `ThemeCommonCallback`
- 空数组 / null object 风格返回

这更像是后端接口或 catalog 项目被逐步下线、区域化、或按兼容性过滤后的结果。

**推断**：旧版 / 中国版主题客户端仍然能打到部分 endpoint，但服务器返回已经不稳定，很多页面只能拿到空数据或 404。

### 3) 官方公开面向用户的入口，不是公共 API 文档

我没有找到可公开、稳定、长期维护的“主题 API 文档”。公开可访问的官方 surface 更像：

- Themes App 里的用户流程
- 购买/下载/安装的账户区域校验
- Theme Designer 审核门户

Theme Designer 官方审核页显示的是内容审核规范，而不是公共开发 API：

- [Theme Designer Review Portal](https://in.zhuti.designer.intl.xiaomi.com/tutorial/audit/)

公开页面强调了主题名、描述、包大小、关键词、内容合规等审核规则，说明官方更偏“受审查的内容分发”，不是开放 API。

## Still-accessible / compatible surfaces

### Official

- Xiaomi support 确认 Themes 的货币和内容跟 Xiaomi 账号区域 / 设备区域绑定。
- 购买后的主题/字体只有在 Themes App 内完成购买才被官方支持。

来源：
- [Why does the Themes App show a different currency from my region?](https://www.mi.com/global/support/article/KA-608592/)
- [What to do if the purchased theme or font can't be installed or used?](https://www.mi.com/pk/support/faq/details/KA-643447/)

### Compatible / community-known

1. `theme://URL`

   社区反复提到，主题链接可以用 `theme://URL` 这类 deeplink 打开，再由 Themes App 接管。

   来源：
   - [Reddit: Theme link starts with `theme://URL`](https://www.reddit.com/r/HyperOS/comments/1ga9w8u/)
   - [Reddit: old MIUI/HyperOS themes can still be reached via creator profile / browser link](https://www.reddit.com/r/HyperOS/comments/1kuy39w)

2. 浏览器“Open in app”

   社区常见流程是先在浏览器里找到主题页面，再交给 Xiaomi Themes App 打开。

3. 修改版 Theme Manager / Global server / Import themes

   一个长期被社区引用的改版 Theme Manager 仓库写明：

   - `Global server by default`
   - `Import Themes option`
   - `English themes`
   - Android 13 上建议关闭签名验证并用 Core Patch LSPosed

   来源：
   - [Mods-Center/Theme-Manager](https://github.com/Mods-Center/Theme-Manager)

4. 区域切换

   社区经常建议切换到 `India`，让某些 Theme/Font/Import 入口出现。

   来源：
   - [Reddit: change region to India to access Themes/Fonts](https://www.reddit.com/r/Xiaomi/comments/fsatto/)
   - [Reddit: if you can't find the Themes app, change region to India](https://www.reddit.com/r/miui/comments/1da7sni)

5. HyperOS / MIUI 兼容性逐步放开，但只对部分新主题有效

   社区 2026 年的帖子显示，Xiaomi 会逐步发布 HyperOS 3 主题，但不是所有设备都立刻可见。

   来源：
   - [Reddit: HYPEROS 3 themes...](https://www.reddit.com/r/HyperOS/comments/1ry1jss)

## Workarounds that appear to work

### Verified in community sources

- 切 `Region = India`
- 用 `theme://URL` 或 creator profile 进入主题
- 用带 Import 的改版 Theme Manager
- Android 13 上关闭签名验证 / Core Patch LSPosed
- 用已知可导入的老版本主题页面 / 老主题包

### Not verified / no stable recipe found

- Host mapping
- DNS rewrite
- 把旧 API 域名 hardcode 到新域名

我没有找到一个可重复、可推广的“改 hosts 就恢复完整主题商店”的稳定方案。

## What the current MIUI 14 Global + cover setup can do

当前这套方案的最佳定位是：

1. `com.android.thememanager 4.0.1.4` 作为 `/data` cover，负责本地主题核心能力。
2. `com.miui.themestore 30.0` 或 `14.0` 作为 trampoline / 入口壳，必要时重定向到 `ThemeManager`。
3. `miui-uninstall-empty.jar` 已经进入 live `system_ext`，所以独立包和旧路径能被装起来。
4. 在线主题 catalog 只能当“尽力可用”，不要再把它当稳定契约。

### 实操建议

- 继续保留当前 cover 方案，不要回到分区镜像刷写。
- `.mtz` / browser theme link 适合做“拿资源、导入资源”。
- 如果某个页面继续返回 404 / 空数组 / null object，默认当作服务端退化，而不是本地环境没配好。

## Bottom line

对现在这台 `MIUI 14 Global` 机器来说，最现实的组合是：

- **本地主题能力**：`com.android.thememanager 4.0.1.4` cover
- **入口兼容**：patched `com.miui.themestore`
- **在线能力**：不稳定、只按 best effort 使用

不要再把“恢复完整中国版主题商店”当成短期目标；当前更稳的是把“本地导入 + 局部在线能力”跑顺。
