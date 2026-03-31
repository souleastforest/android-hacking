# [SYSTEM HANDOFF CONTEXT]: Android eSIM Hardware Check Bypass for giffgaff

## 1. Environment & State
*   **Device:** Android smartphone with ROOT access (Magisk/KernelSU installed). Connected to PC via ADB (`adb devices` is authorized).
*   **Hardware:** A "9esim" (removable physical eSIM card / eUICC) is inserted into the physical SIM slot.
*   **Companion App:** The 9esim management app is installed, functioning, and able to read/write the eUICC. It is waiting for standard LPA inputs (SM-DP+ Address and Activation Code).
*   **Target App:** `com.giffgaffmobile.app` (giffgaff UK).
*   **The Blocker:** The user wants to provision a new giffgaff eSIM. However, the giffgaff app throws a "This phone doesn't support eSIM" error. It hides the eSIM provisioning flow because it performs a hardware capability check (likely checking `PackageManager.hasSystemFeature("android.hardware.telephony.euicc")` and `EuiccManager.isEnabled()`).

## 2. Objective
Your goal as the ADB Agent is to use `adb shell` and `su` privileges to spoof the Android system environment. You must trick the giffgaff app into believing the device has native eSIM hardware support. This will force the app to reveal the eSIM activation UI and either pass the LPA string to the 9esim app or allow network interception of the activation code.

## 3. Execution Strategies (Choose one or sequential fallback)

### 🔴 Strategy A: System Feature Flag Spoofing via Magisk CLI (Recommended & Safest)
Since the `/system` partition is likely read-only (EROFS/Dynamic partitions), directly modifying `/system/etc/permissions/` will fail. You must create a lightweight Magisk module via ADB to inject the `android.hardware.telephony.euicc` feature flag.

**Actionable ADB Commands you should generate/execute:**
1. Use `adb shell su -c` to create a temporary working directory (e.g., `/data/local/tmp/esim_spoof/system/etc/permissions/`).
2. Write an XML file named `android.hardware.telephony.euicc.xml` with the following content:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <permissions>
       <feature name="android.hardware.telephony.euicc" />
   </permissions>
   ```
3. Create a standard `module.prop` for Magisk (id=esim_enabler, name=eSIM Enabler, version=v1).
4. Zip the directory or place it directly into `/data/adb/modules/esim_spoof/`.
5. Reboot the device (`adb reboot`).
*Note: If the user is on KernelSU/APatch, ensure module format compatibility.*

### 🔴 Strategy B: Spoofing System Properties (resetprop)
The app might also check `ro.*` properties. You should use Magisk's `resetprop` tool to spoof device models or telephony flags.
**Commands to execute:**
*   `adb shell su -c "resetprop ro.telephony.euicc 1"`
*   `adb shell su -c "resetprop ro.telephony.sim_slots.count 2"`
*   (Optional) Spoof a known eSIM device model like Pixel 7: `adb shell su -c "resetprop ro.product.model Pixel 7"`

### 🔴 Strategy C: Network Interception / Packet Capture (The Ultimate Fallback)
If the giffgaff app still refuses (e.g., because it verifies `EuiccManager.getEid()` and fails to retrieve it from the Android System API before provisioning), we abandon UI spoofing and attack the network layer.
**Agent Action:**
1. Guide the user to install a Root-enabled packet capture tool (like HttpCanary or PCAPDroid with root CA installed in system via Magisk).
2. Instruct the user to click the standard "Order a SIM / Activate" flow in the app.
3. Monitor the HTTPS API requests to giffgaff servers.
4. Extract the JSON response containing the standard LPA string: `LPA:1$smdp.io$activation_code`.
5. Pass this string back to the user to manually paste into the 9esim App.

## 4. Agent Instructions
Please acknowledge this context. Begin by verifying the root state (`adb shell su -c "id"`) and the Magisk/KernelSU environment (`adb shell su -c "magisk -V"`). Then proceed with **Strategy A**. Output the exact scripts and wait for the user's execution feedback.

### 💡 给你（人类主管）的额外行动建议：

1. **为什么选用生成 Magisk 模块的方式（Strategy A）？**
   由于现在的安卓手机几乎全都启用了动态分区（Dynamic Partitions）且 `/system` 是只读的，如果你直接用 `mount -o rw` 强行修改系统文件，大概率会导致手机无限重启（Bootloop）。通过 ADB 自动写一个极简的 Magisk 模块来挂载那个 XML 文件，是最安全的伪装方法，不想用了随时可以在 Magisk 里删掉。
2. **抓包法（Strategy C）其实更爽快：**
   如果你的下一个 Agent 尝试修改系统参数后，giffgaff 依然闪退或报错（因为它可能不仅检查开关，还试图调用系统的底层 eSIM API，而你的原生系统没有这个驱动），**请直接让 Agent 教你抓包**。giffgaff 的 eSIM 激活本质上就是向服务器发个请求，服务器返回一段 `1$SM-DP+地址$激活码` 的字符串。只要抓到这串东西，直接复制粘贴到你的 9esim App 里，瞬间就能烧录成功，彻底绕过 giffgaff App 的任何硬件检测。

对于上述的补充：
- 我们已有 kernelsu 的相关开发经验，可以自己写对应的模块；