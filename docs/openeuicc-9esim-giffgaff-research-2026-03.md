# OpenEUICC + 9eSIM + giffgaff Research (2026-03)

## Conclusion

There is a plausible system-level path, but it is not a clean yes.

- `9eSIM` and `EasyEUICC` are suitable when you already have a standard eSIM profile source and want to write it to a removable eUICC.
- `OpenEUICC` is the only upstream project in the sources reviewed that explicitly targets **system-app / LPA** integration for Android and claims support for **external (removable) eSIM** when privileged.
- `giffgaff` still documents an **app-driven activation flow** and does not document a public QR / SM-DP+ handoff path.
- `OpenEUICC` upstream states that its **system integration is partial** and that the **Carrier Partner API is unimplemented**.

Practical inference: a KernelSU / Magisk based `OpenEUICC` system-LPA path is the only realistic route worth testing next, but it may still fail specifically for `giffgaff` if the app depends on the missing carrier-partner integration instead of a generic `EuiccManager` flow.

## What The Sources Say

### 1. 9eSIM is a card + LPA manager ecosystem, not proof of carrier-app compatibility

9eSIM's official software page distributes:

- `9eSIM nLPA`
- `9eSIM LPA (EasyEUICC)`
- desktop tools such as `MiniLPA`

This strongly indicates that 9eSIM expects profile management through its own LPA tooling rather than through every carrier app automatically.

Source:

- https://www.9esim.com/zh/%E7%94%9F%E6%80%81%E7%B3%BB%E7%BB%9F%E8%BD%AF%E4%BB%B6%E4%B8%8B%E8%BD%BD/

### 2. OpenEUICC explicitly targets system-app / LPA integration

OpenEUICC's homepage states:

- it is an open-source eSIM LPA for Android
- it can work as a **system app** on aftermarket firmware
- debug builds are published as a **Magisk module**
- it also supports an unprivileged mode (`EasyEUICC`) for compatible removable eSIM chips

Source:

- https://openeuicc.com/

### 3. OpenEUICC upstream supports external eSIM in privileged mode, but integration is incomplete

The upstream README says:

- `OpenEUICC` must be installed as a **system app**
- it supports **internal eSIM** and **external eSIM**
- `EasyEUICC` does not support internal eSIM
- `OpenEUICC` system integration is **Partial**
- note: **Carrier Partner API unimplemented yet**

This is the most important blocker discovered in the research.

Source:

- https://raw.githubusercontent.com/estkme-group/openeuicc/master/README.md

### 4. Android's official model requires a system LPA behind `EuiccManager`

AOSP states:

- carrier apps can use `EuiccManager`
- the LPA app needs to be a **system app**
- the LPA handles the actual eUICC communication and SM-DP+ interaction

Source:

- https://source.android.com/docs/core/connect/esim-euicc-api

### 5. giffgaff still documents an app-only activation flow

The official giffgaff help article says:

- first check whether the phone works with eSIM
- activate eSIM in the `giffgaff app`
- existing users switch through `Account > SIM > Replace my SIM > Switch to a new eSIM`

The article does not provide a public QR / SM-DP+ / activation-code export workflow.

Source:

- https://help.giffgaff.com/en/articles/261570-switching-to-an-esim-with-giffgaff

## Feasibility Assessment

### Path A: Keep spoofing app checks with LSPosed

Low probability.

Why:

- it may bypass UI feature checks
- it does not create a real system LPA path
- it does not solve downstream provisioning if the app expects Android eSIM plumbing to exist end-to-end

### Path B: Promote 9eSIM to system-visible eSIM via OpenEUICC

Medium probability and the only route worth serious effort.

Why:

- aligns with the Android architecture
- OpenEUICC is explicitly built for privileged LPA integration
- supports removable eSIM in privileged mode

Main risk:

- upstream says `Carrier Partner API` is not implemented, so a carrier app that relies on partner-specific flows may still fail

### Path C: Obtain giffgaff QR / SM-DP+ and import manually into 9eSIM

Unknown to low probability based on official documentation.

Why:

- giffgaff does not document a public manual import path
- if the service is app-only, there may be no reusable standard activation payload exposed to the user

## Recommended Next Step

Stop investing in the LSPosed-only path. Move to a system-LPA experiment.

The next technical milestone should be:

1. Install or integrate `OpenEUICC` as a privileged/system component using its Magisk-style path or equivalent KernelSU-compatible overlay.
2. Confirm Android exposes working `EuiccManager` / `Manage eSIM` behavior through the removable 9eSIM card.
3. Re-test the `giffgaff` app only after the system layer is real.

## Decision

There **is** a real方案可研究，而且不是空想:

- `OpenEUICC` + `9eSIM` + privileged/system-app integration

But there is also a concrete, sourced blocker:

- `OpenEUICC` upstream currently marks system integration as partial and says the carrier partner API is not implemented

So the right framing is:

- **有方案，值得做**
- **但不是高确定性方案**
- **成败关键在于 giffgaff app 是否只依赖标准 `EuiccManager`，还是还依赖 OpenEUICC 尚未实现的 carrier-partner integration**
