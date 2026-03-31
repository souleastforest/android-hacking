package com.souleastforest.esimbypass;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage.LoadPackageParam;

public class EsimHook implements IXposedHookLoadPackage {
    private static final String TAG = "eSIM Bypass";
    private static final String TARGET_PACKAGE_LEGACY = "com.giffgaffmobile.app";
    private static final String TARGET_PACKAGE_CURRENT = "com.giffgaffmobile.controller";
    private static final String FEATURE_EUICC = "android.hardware.telephony.euicc";
    private static final String FAKE_EID = "89049032000000000000000000000001";

    @Override
    public void handleLoadPackage(final LoadPackageParam lpparam) throws Throwable {
        // Keep blast radius small: only hook in known giffgaff app processes.
        if (!TARGET_PACKAGE_LEGACY.equals(lpparam.packageName)
            && !TARGET_PACKAGE_CURRENT.equals(lpparam.packageName)) {
            return;
        }

        XposedBridge.log(TAG + ": loaded in " + lpparam.packageName);

        hookHasSystemFeature(lpparam);
        hookEuiccManager(lpparam);
    }

    private void hookHasSystemFeature(final LoadPackageParam lpparam) {
        // Hook ApplicationPackageManager.hasSystemFeature(String)
        try {
            XposedHelpers.findAndHookMethod(
                "android.app.ApplicationPackageManager",
                lpparam.classLoader,
                "hasSystemFeature",
                String.class,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
                        String feature = (String) param.args[0];
                        if (FEATURE_EUICC.equals(feature)) {
                            XposedBridge.log(TAG + ": hasSystemFeature(String) -> true for " + feature);
                            param.setResult(true);
                        }
                    }
                }
            );
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": failed to hook hasSystemFeature(String): " + t);
        }

        // Hook ApplicationPackageManager.hasSystemFeature(String, int) - Android 7+
        try {
            XposedHelpers.findAndHookMethod(
                "android.app.ApplicationPackageManager",
                lpparam.classLoader,
                "hasSystemFeature",
                String.class,
                int.class,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
                        String feature = (String) param.args[0];
                        if (FEATURE_EUICC.equals(feature)) {
                            XposedBridge.log(TAG + ": hasSystemFeature(String, int) -> true for " + feature);
                            param.setResult(true);
                        }
                    }
                }
            );
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": hasSystemFeature(String, int) not hooked: " + t);
        }
    }

    private void hookEuiccManager(final LoadPackageParam lpparam) {
        // Hook EuiccManager.isEnabled()
        try {
            XposedHelpers.findAndHookMethod(
                "android.telephony.euicc.EuiccManager",
                lpparam.classLoader,
                "isEnabled",
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
                        XposedBridge.log(TAG + ": EuiccManager.isEnabled() -> true");
                        param.setResult(true);
                    }
                }
            );
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": failed to hook EuiccManager.isEnabled(): " + t);
        }

        // Some builds gate on a non-empty EID value.
        try {
            XposedHelpers.findAndHookMethod(
                "android.telephony.euicc.EuiccManager",
                lpparam.classLoader,
                "getEid",
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) throws Throwable {
                        XposedBridge.log(TAG + ": EuiccManager.getEid() -> fake eid");
                        param.setResult(FAKE_EID);
                    }
                }
            );
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": getEid() not hooked: " + t);
        }

        // Some apps treat null EuiccInfo as "unsupported"; preserve original if non-null.
        try {
            XposedHelpers.findAndHookMethod(
                "android.telephony.euicc.EuiccManager",
                lpparam.classLoader,
                "getEuiccInfo",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) throws Throwable {
                        if (param.getResult() == null) {
                            try {
                                param.setResult(XposedHelpers.newInstance(
                                    XposedHelpers.findClass(
                                        "android.telephony.euicc.EuiccInfo",
                                        lpparam.classLoader
                                    ),
                                    "9esim"
                                ));
                                XposedBridge.log(TAG + ": EuiccManager.getEuiccInfo() -> synthetic info");
                            } catch (Throwable inner) {
                                XposedBridge.log(TAG + ": getEuiccInfo() synthetic build failed: " + inner);
                            }
                        }
                    }
                }
            );
        } catch (Throwable t) {
            XposedBridge.log(TAG + ": getEuiccInfo() not hooked: " + t);
        }
    }
}
