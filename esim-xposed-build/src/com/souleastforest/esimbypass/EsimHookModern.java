package com.souleastforest.esimbypass;

import android.util.Log;

import java.lang.reflect.Method;

import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface;

public class EsimHookModern extends XposedModule {
    private static final String TAG = "eSIM Bypass";
    private static final String TARGET_PACKAGE_LEGACY = "com.giffgaffmobile.app";
    private static final String TARGET_PACKAGE_CURRENT = "com.giffgaffmobile.controller";
    private static final String FEATURE_EUICC = "android.hardware.telephony.euicc";
    private static final String FAKE_EID = "89049032000000000000000000000001";

    @Override
    public void onPackageReady(XposedModuleInterface.PackageReadyParam param) {
        String packageName = param.getPackageName();
        if (!TARGET_PACKAGE_LEGACY.equals(packageName) && !TARGET_PACKAGE_CURRENT.equals(packageName)) {
            return;
        }

        try {
            log(Log.INFO, TAG, "Modern API loaded in " + packageName);
            hookHasSystemFeature(param.getClassLoader());
            hookEuiccManager(param.getClassLoader());
        } catch (Throwable t) {
            log(Log.ERROR, TAG, "Modern API initialization failed", t);
        }
    }

    private void hookHasSystemFeature(ClassLoader classLoader) {
        try {
            Class<?> apmClass = Class.forName("android.app.ApplicationPackageManager", false, classLoader);
            Method hasSystemFeature = apmClass.getDeclaredMethod("hasSystemFeature", String.class);
            hook(hasSystemFeature).intercept(chain -> {
                Object arg = chain.getArg(0);
                if (FEATURE_EUICC.equals(arg)) {
                    log(Log.INFO, TAG, "Modern hook: hasSystemFeature(String) -> true");
                    return Boolean.TRUE;
                }
                return chain.proceed();
            });
        } catch (Throwable t) {
            log(Log.WARN, TAG, "Modern hook failed: hasSystemFeature(String)", t);
        }

        try {
            Class<?> apmClass = Class.forName("android.app.ApplicationPackageManager", false, classLoader);
            Method hasSystemFeatureWithVersion = apmClass.getDeclaredMethod(
                "hasSystemFeature",
                String.class,
                int.class
            );
            hook(hasSystemFeatureWithVersion).intercept(chain -> {
                Object arg = chain.getArg(0);
                if (FEATURE_EUICC.equals(arg)) {
                    log(Log.INFO, TAG, "Modern hook: hasSystemFeature(String,int) -> true");
                    return Boolean.TRUE;
                }
                return chain.proceed();
            });
        } catch (Throwable t) {
            log(Log.WARN, TAG, "Modern hook skipped: hasSystemFeature(String,int)", t);
        }
    }

    private void hookEuiccManager(ClassLoader classLoader) {
        try {
            Class<?> euiccClass = Class.forName("android.telephony.euicc.EuiccManager", false, classLoader);
            Method isEnabled = euiccClass.getDeclaredMethod("isEnabled");
            hook(isEnabled).intercept(chain -> {
                log(Log.INFO, TAG, "Modern hook: EuiccManager.isEnabled() -> true");
                return Boolean.TRUE;
            });
        } catch (Throwable t) {
            log(Log.WARN, TAG, "Modern hook failed: EuiccManager.isEnabled()", t);
        }

        try {
            Class<?> euiccClass = Class.forName("android.telephony.euicc.EuiccManager", false, classLoader);
            Method getEid = euiccClass.getDeclaredMethod("getEid");
            hook(getEid).intercept(chain -> {
                log(Log.INFO, TAG, "Modern hook: EuiccManager.getEid() -> fake");
                return FAKE_EID;
            });
        } catch (Throwable t) {
            log(Log.WARN, TAG, "Modern hook skipped: EuiccManager.getEid()", t);
        }
    }
}
