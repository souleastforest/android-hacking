# giffgaff eSIM Extractor

一个面向 `giffgaff eSIM` 的最小化提取工具目录，用来：

- 在 Android 设备上通过 `Frida` hook `giffgaff app`
- 捕获 `publicapi.giffgaff.com/gateway/graphql` 返回的 `eSimDownloadToken`
- 提取标准 eSIM 安装参数：
  - `host`
  - `matchingId`
  - `lpaString`

这套目录已经按“可独立仓库”组织。你后续可以直接把整个目录拷出去单独 `git init`。

## 目录结构

```text
giffgaff-esim-extractor/
  hooks/
    giffgaff_esim_token_hook.js
  scripts/
    start_frida_server.sh
    extract_giffgaff_lpa.sh
    parse_lpa_from_log.sh
  output/
  README.md
```

## 前提

### 主机端

- `adb` 可用，或者通过 `ADB=/path/to/adb` 指定
- `frida-tools` 已安装
- 建议 `frida-tools` 运行在 `Python 3.12` 环境，避免此前遇到的 `Python 3.13` 退出期崩溃问题

### 手机端

- 已 root
- 已推送并启动匹配版本的 `frida-server`
- 已安装并登录 `giffgaff app`

## 快速开始

### 1. 启动 frida-server

```bash
FRIDA_SERVER_BIN=/absolute/path/to/frida-server-android-arm64 \
ADB=/absolute/path/to/adb \
./scripts/start_frida_server.sh
```

### 2. 挂到 giffgaff 并开始抓取

```bash
ADB=/absolute/path/to/adb ./scripts/extract_giffgaff_lpa.sh
```

脚本会：

1. 冷启动 `giffgaff`
2. 找到进程 PID
3. 用 Frida attach
4. 把 hook 输出写到 `output/giffgaff-frida.log`

之后你在手机上手动走一遍：

- 打开 eSIM 流程
- 下单 / 安装
- 走到 app 失败页或 token 下发阶段

如果命中，日志里会出现一行：

```text
[LPA_RESULT] { ... }
```

### 3. 解析结果

```bash
./scripts/parse_lpa_from_log.sh
```

默认会从：

- `output/giffgaff-frida.log`

提取结果并写到：

- `output/extracted-esim.txt`

## 输出格式

成功时会得到：

```text
host=cel.prod.ondemandconnectivity.com
matchingId=...
lpaString=LPA:1$cel.prod.ondemandconnectivity.com$...
```

## 当前验证结论

这套流程已经在当前设备环境验证通过，关键结论是：

- `giffgaff` 后端确实会返回标准 eSIM 安装参数
- `giffgaff app` 失败点主要在“原生 setUp / 系统安装”那一跳
- 可以绕过 app 的最后一步，直接把提取出的 `LPA:1$...` 导入 `OpenEUICC` 或 `9eSIM`

## 备注

- 脚本默认只盯 `publicapi.giffgaff.com/gateway/graphql`
- 目前主 hook 依赖 `okhttp3.Response$Builder.build()`，这是这次验证命中的路径
- 如果 `giffgaff` 后续改网络栈，需要补 hook 点
