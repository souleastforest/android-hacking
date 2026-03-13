package com.custom.nfcfix;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.callbacks.XC_LoadPackage.LoadPackageParam;

public class NfcFixHook implements IXposedHookLoadPackage {

    private static final String TAG = "NfcFix";
    private static final String TARGET_PKG = "com.android.settings";
    private static final String TARGET_CLASS = "com.android.settings.nfc.MiuiNfcPayPreferenceController";

    @Override
    public void handleLoadPackage(LoadPackageParam lpparam) throws Throwable {
        if (!TARGET_PKG.equals(lpparam.packageName)) return;

        XposedBridge.log(TAG + ": loaded into " + lpparam.packageName);

        try {
            hookOnResume(lpparam.classLoader);
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": hook failed - " + t.getMessage());
        }
    }

    private void hookOnResume(ClassLoader classLoader) {
        XposedHelpers.findAndHookMethod(
            TARGET_CLASS,
            classLoader,
            "onResume",
            new XC_MethodHook() {
                @Override
                protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
                    try {
                        Object controller = param.thisObject;

                        // 检查 mPaymentBackend 字段
                        Object backend = null;
                        try {
                            backend = XposedHelpers.getObjectField(controller, "mPaymentBackend");
                        } catch (Throwable t) {
                            XposedBridge.log(TAG + ": cannot get mPaymentBackend, skipping safely");
                            param.setResult(null);
                            return;
                        }

                        if (backend == null) {
                            XposedBridge.log(TAG + ": mPaymentBackend is null, skipping onResume safely");
                            param.setResult(null);
                            return;
                        }

                        // 检查 getDefaultApp() 的返回值
                        Object defaultApp = null;
                        try {
                            defaultApp = XposedHelpers.callMethod(backend, "getDefaultApp");
                        } catch (Throwable t) {
                            XposedBridge.log(TAG + ": getDefaultApp() threw: " + t.getMessage());
                            param.setResult(null);
                            return;
                        }

                        if (defaultApp == null) {
                            XposedBridge.log(TAG + ": getDefaultApp() returned null, skipping onResume safely");
                            param.setResult(null);
                            return;
                        }

                        // defaultApp 不为 null，放行正常执行
                        XposedBridge.log(TAG + ": defaultApp ok, proceeding normally");

                    } catch (Throwable t) {
                        XposedBridge.log(TAG + ": unexpected error in beforeHookedMethod: " + t.getMessage());
                        param.setResult(null);
                    }
                }
            }
        );

        XposedBridge.log(TAG + ": hooked MiuiNfcPayPreferenceController.onResume() successfully");
    }
}
