package com.souleastforest.themecnidentity;

import android.util.Pair;

import java.io.File;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage.LoadPackageParam;

public class ThemeCnIdentityLegacyEntry implements IXposedHookLoadPackage {
    @Override
    public void handleLoadPackage(final LoadPackageParam lpparam) throws Throwable {
        if (!RewriteCore.TARGET_PACKAGE.equals(lpparam.packageName)) {
            return;
        }

        RewriteCore.log("loaded in " + lpparam.packageName + " process=" + lpparam.processName);
        hookRequestClass(lpparam.classLoader);
        hookRetrofitRequestFactory(lpparam.classLoader);
        hookRetrofitOkHttpCall(lpparam.classLoader);
        hookObfuscatedOkHttpRequestBuilder(lpparam.classLoader);
        hookGenericRequestBuilders(lpparam.classLoader);
    }

    private void hookRequestClass(final ClassLoader classLoader) {
        final Class<?> requestClass;
        try {
            requestClass = XposedHelpers.findClass(RewriteCore.REQUEST_CLASS, classLoader);
        } catch (Throwable throwable) {
            RewriteCore.log("failed to resolve request class", throwable);
            return;
        }

        RewriteCore.dumpMethodSummaryOnce(requestClass);

        boolean hookedAny = false;
        try {
            XposedHelpers.findAndHookMethod(
                requestClass,
                "getFinalGetUrl",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        Object result = param.getResult();
                        if (!(result instanceof String)) {
                            return;
                        }
                        String original = (String) result;
                        String rewritten = RewriteCore.rewriteUrl(original);
                        if (!RewriteCore.safeEquals(original, rewritten)) {
                            RewriteCore.log("GET " + original + " => " + rewritten);
                            param.setResult(rewritten);
                        }
                    }
                }
            );
            hookedAny = true;
            RewriteCore.log("hooked zurt.getFinalGetUrl()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook getFinalGetUrl", throwable);
        }

        try {
            XposedHelpers.findAndHookMethod(
                requestClass,
                "getFinalPostUrl",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        Object result = param.getResult();
                        if (!(result instanceof Pair)) {
                            return;
                        }
                        Pair<?, ?> original = (Pair<?, ?>) result;
                        Pair<String, String> rewritten = RewriteCore.rewritePostResult(original);
                        String originalFirst =
                            original.first == null ? null : String.valueOf(original.first);
                        String originalSecond =
                            original.second == null ? null : String.valueOf(original.second);

                        String finalUrl = rewritten.first;
                        String finalBody = rewritten.second;
                        if (RewriteCore.isCheckUpdateUrl(finalUrl)) {
                            Pair<String, String> filtered =
                                RewriteCore.filterLocalOnlyFileshashForCheckUpdate(finalUrl, finalBody);
                            finalUrl = filtered.first;
                            finalBody = filtered.second;
                        }
                        if (RewriteCore.isCheckUpdateUrl(finalUrl)
                            && RewriteCore.hasNonEmptyFileshash(finalBody)
                            && !RewriteCore.containsUsedThemesHistory(finalBody)) {
                            try {
                                Class<?> helperClass = XposedHelpers.findClass(
                                    "com.android.thememanager.util.d",
                                    classLoader
                                );
                                String history = (String) XposedHelpers.callStaticMethod(helperClass, "bf2");
                                if (history != null && history.length() > 0) {
                                    String injectedBody = RewriteCore.appendEncodedFormField(
                                        finalBody,
                                        "usedThemesHistory",
                                        history
                                    );
                                    if (!RewriteCore.safeEquals(finalBody, injectedBody)) {
                                        RewriteCore.log(
                                            "Injected usedThemesHistory for checkupdate/hashpair: "
                                                + RewriteCore.summarizeBody(history)
                                        );
                                        finalBody = injectedBody;
                                    }
                                } else {
                                    RewriteCore.log(
                                        "usedThemesHistory probe: helper returned empty for checkupdate/hashpair"
                                    );
                                }
                            } catch (Throwable t) {
                                RewriteCore.log(
                                    "failed to inject usedThemesHistory for checkupdate/hashpair",
                                    t
                                );
                            }
                        } else if (RewriteCore.isCheckUpdateUrl(finalUrl)
                            && !RewriteCore.hasNonEmptyFileshash(finalBody)) {
                            RewriteCore.log(
                                "Skipped usedThemesHistory injection because filtered fileshash is empty"
                            );
                        }

                        if (!RewriteCore.safeEquals(originalFirst, finalUrl)
                            || !RewriteCore.safeEquals(originalSecond, finalBody)) {
                            RewriteCore.log(
                                "POST " + originalFirst + " | " + originalSecond + " => "
                                    + finalUrl + " | " + finalBody
                            );
                            param.setResult(new Pair<String, String>(finalUrl, finalBody));
                        }
                    }
                }
            );
            hookedAny = true;
            RewriteCore.log("hooked zurt.getFinalPostUrl()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook getFinalPostUrl", throwable);
        }

        try {
            XposedHelpers.findAndHookMethod(
                requestClass,
                "addRequestFlag",
                int.class,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) {
                        try {
                            String baseUrl = RewriteCore.safeToString(
                                XposedHelpers.callMethod(param.thisObject, "getBaseUrl")
                            );
                            RewriteCore.log(
                                "zurt.addRequestFlag("
                                    + param.args[0]
                                    + ") baseUrl="
                                    + baseUrl
                            );
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump addRequestFlag", t);
                        }
                    }
                }
            );
            hookedAny = true;
            RewriteCore.log("hooked zurt.addRequestFlag(int)");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook addRequestFlag", throwable);
        }

        try {
            XposedHelpers.findAndHookMethod(
                requestClass,
                "setRequestFlag",
                int.class,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) {
                        try {
                            String baseUrl = RewriteCore.safeToString(
                                XposedHelpers.callMethod(param.thisObject, "getBaseUrl")
                            );
                            RewriteCore.log(
                                "zurt.setRequestFlag("
                                    + param.args[0]
                                    + ") baseUrl="
                                    + baseUrl
                            );
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump setRequestFlag", t);
                        }
                    }
                }
            );
            hookedAny = true;
            RewriteCore.log("hooked zurt.setRequestFlag(int)");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook setRequestFlag", throwable);
        }

        try {
            XposedHelpers.findAndHookMethod(
                requestClass,
                "setUserPostBody",
                String.class,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) {
                        try {
                            String baseUrl = RewriteCore.safeToString(
                                XposedHelpers.callMethod(param.thisObject, "getBaseUrl")
                            );
                            String body = param.args[0] == null ? null : String.valueOf(param.args[0]);
                            RewriteCore.log(
                                "zurt.setUserPostBody baseUrl="
                                    + baseUrl
                                    + " body="
                                    + RewriteCore.summarizeBody(body)
                            );
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump setUserPostBody", t);
                        }
                    }
                }
            );
            hookedAny = true;
            RewriteCore.log("hooked zurt.setUserPostBody(String)");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook setUserPostBody", throwable);
        }

        try {
            final AtomicBoolean headersDumped = new AtomicBoolean(false);
            XposedHelpers.findAndHookMethod(
                requestClass,
                "getFinalHeaders",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        boolean firstDump = headersDumped.compareAndSet(false, true);
                        try {
                            Object result = param.getResult();
                            if (firstDump) {
                                RewriteCore.log("hooked zurt.getFinalHeaders()");
                            }
                            if (result instanceof Map) {
                                Map<?, ?> map = (Map<?, ?>) result;
                                if (firstDump) {
                                    RewriteCore.log("final headers size=" + map.size());
                                    for (Map.Entry<?, ?> entry : map.entrySet()) {
                                        RewriteCore.log(
                                            "header[" + String.valueOf(entry.getKey()) + "]="
                                                + String.valueOf(entry.getValue())
                                        );
                                    }
                                }
                                String baseUrl = RewriteCore.safeToString(
                                    XposedHelpers.callMethod(param.thisObject, "getBaseUrl")
                                );
                                if (RewriteCore.isCheckUpdateUrl(baseUrl)) {
                                    Map<Object, Object> rewritten = new LinkedHashMap<Object, Object>(map);
                                    Object removed = rewritten.remove("Cookie");
                                    if (removed != null) {
                                        RewriteCore.log(
                                            "stripped Cookie header for checkupdate/hashpair"
                                        );
                                        param.setResult(rewritten);
                                    }
                                }
                            } else if (firstDump) {
                                RewriteCore.log("final headers result=" + String.valueOf(result));
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump/rewrite getFinalHeaders result", t);
                        }
                    }
                }
            );
            hookedAny = true;
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook getFinalHeaders", throwable);
        }

        hookNetworkDiagnostics(classLoader, requestClass);

        if (!hookedAny) {
            RewriteCore.log("request class resolved but no primary hooks were installed");
        }
    }

    private void hookGenericRequestBuilders(final ClassLoader classLoader) {
        hookRequestBuilderBuild(
            classLoader,
            "okhttp3.Request$Builder",
            "okhttp3 generic"
        );
        hookRequestBuilderBuild(
            classLoader,
            "com.android.okhttp.Request$Builder",
            "android okhttp"
        );
    }

    private void hookObfuscatedOkHttpRequestBuilder(final ClassLoader classLoader) {
        try {
            final Class<?> builderClass = XposedHelpers.findClass("okhttp3.jp0y$k", classLoader);
            final Class<?> httpUrlClass = XposedHelpers.findClass("okhttp3.o1t", classLoader);
            XposedHelpers.findAndHookMethod(
                builderClass,
                "toq",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        try {
                            Object request = param.getResult();
                            if (request == null) {
                                return;
                            }
                            Object urlObj = XposedHelpers.callMethod(request, "ld6");
                            String originalUrl = RewriteCore.safeToString(urlObj);
                            String rewrittenUrl = RewriteCore.rewriteUrl(originalUrl);
                            if (RewriteCore.safeEquals(originalUrl, rewrittenUrl)) {
                                return;
                            }

                            Object newBuilder = XposedHelpers.callMethod(request, "y");
                            Object parsedUrl = XposedHelpers.callStaticMethod(
                                httpUrlClass,
                                "qrj",
                                rewrittenUrl
                            );
                            Object rewrittenRequest = XposedHelpers.callMethod(
                                XposedHelpers.callMethod(newBuilder, "t8r", parsedUrl),
                                "toq"
                            );
                            if (rewrittenRequest != null) {
                                param.setResult(rewrittenRequest);
                                if (originalUrl.contains("page/v3")
                                    || originalUrl.contains("classification")
                                    || originalUrl.contains("h5config")
                                    || originalUrl.contains("safe/auth/social/userInfo")
                                    || originalUrl.contains("themeActivity/views/activities/index.html")) {
                                    RewriteCore.log(
                                        "generic request rewrite [okhttp3.jp0y$k.toq] "
                                            + originalUrl + " => " + rewrittenUrl
                                    );
                                }
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed generic request rewrite for okhttp3.jp0y$k.toq()", t);
                        }
                    }
                }
            );
            RewriteCore.log("hooked okhttp3.jp0y$k.toq()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook okhttp3.jp0y$k.toq()", throwable);
        }
    }

    private void hookRetrofitOkHttpCall(final ClassLoader classLoader) {
        try {
            final Class<?> okHttpCallClass = XposedHelpers.findClass("retrofit2.n7h", classLoader);
            final Class<?> requestClass = XposedHelpers.findClass("okhttp3.jp0y", classLoader);
            final Class<?> httpUrlClass = XposedHelpers.findClass("okhttp3.o1t", classLoader);

            XposedHelpers.findAndHookMethod(
                okHttpCallClass,
                "zy",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        try {
                            Object request = param.getResult();
                            if (request == null || !requestClass.isInstance(request)) {
                                return;
                            }

                            Object urlObj = XposedHelpers.callMethod(request, "ld6");
                            String originalUrl = RewriteCore.safeToString(urlObj);
                            String rewrittenUrl = RewriteCore.rewriteUrl(originalUrl);
                            if (RewriteCore.safeEquals(originalUrl, rewrittenUrl)) {
                                return;
                            }

                            Object builder = XposedHelpers.callMethod(request, "y");
                            Object parsedUrl = XposedHelpers.callStaticMethod(
                                httpUrlClass,
                                "qrj",
                                rewrittenUrl
                            );
                            Object rewrittenRequest = XposedHelpers.callMethod(
                                XposedHelpers.callMethod(builder, "t8r", parsedUrl),
                                "toq"
                            );
                            if (rewrittenRequest != null && requestClass.isInstance(rewrittenRequest)) {
                                param.setResult(rewrittenRequest);
                                if (originalUrl.contains("page/v3")
                                    || originalUrl.contains("classification")
                                    || originalUrl.contains("h5config")
                                    || originalUrl.contains("safe/auth/social/userInfo")
                                    || originalUrl.contains("themeActivity/views/activities/index.html")) {
                                    RewriteCore.log(
                                        "retrofit request rewrite [n7h.zy] "
                                            + originalUrl + " => " + rewrittenUrl
                                    );
                                }
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed retrofit request rewrite for retrofit2.n7h.zy()", t);
                        }
                    }
                }
            );
            RewriteCore.log("hooked retrofit2.n7h.zy()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook retrofit2.n7h.zy()", throwable);
        }
    }

    private void hookRetrofitRequestFactory(final ClassLoader classLoader) {
        try {
            final Class<?> requestFactoryClass = XposedHelpers.findClass("retrofit2.t8r", classLoader);
            final Class<?> requestClass = XposedHelpers.findClass("okhttp3.jp0y", classLoader);
            final Class<?> httpUrlClass = XposedHelpers.findClass("okhttp3.o1t", classLoader);

            XposedHelpers.findAndHookMethod(
                requestFactoryClass,
                "k",
                Object[].class,
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        try {
                            Object request = param.getResult();
                            if (request == null || !requestClass.isInstance(request)) {
                                return;
                            }

                            Object urlObj = XposedHelpers.callMethod(request, "ld6");
                            String originalUrl = RewriteCore.safeToString(urlObj);
                            String rewrittenUrl = RewriteCore.rewriteUrl(originalUrl);
                            if (RewriteCore.safeEquals(originalUrl, rewrittenUrl)) {
                                return;
                            }

                            Object builder = XposedHelpers.callMethod(request, "y");
                            Object parsedUrl = XposedHelpers.callStaticMethod(
                                httpUrlClass,
                                "qrj",
                                rewrittenUrl
                            );
                            Object rewrittenRequest = XposedHelpers.callMethod(
                                XposedHelpers.callMethod(builder, "t8r", parsedUrl),
                                "toq"
                            );
                            if (rewrittenRequest != null && requestClass.isInstance(rewrittenRequest)) {
                                param.setResult(rewrittenRequest);
                                if (originalUrl.contains("page/v3")
                                    || originalUrl.contains("classification")
                                    || originalUrl.contains("h5config")
                                    || originalUrl.contains("safe/auth/social/userInfo")
                                    || originalUrl.contains("themeActivity/views/activities/index.html")) {
                                    RewriteCore.log(
                                        "retrofit request rewrite [t8r.k] "
                                            + originalUrl + " => " + rewrittenUrl
                                    );
                                }
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed retrofit request rewrite for retrofit2.t8r.k(Object[])", t);
                        }
                    }
                }
            );
            RewriteCore.log("hooked retrofit2.t8r.k(Object[])");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook retrofit2.t8r.k(Object[])", throwable);
        }
    }

    private void hookRequestBuilderBuild(
        final ClassLoader classLoader,
        final String builderClassName,
        final String label
    ) {
        try {
            final Class<?> builderClass = XposedHelpers.findClass(builderClassName, classLoader);
            XposedHelpers.findAndHookMethod(
                builderClass,
                "build",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        try {
                            Object request = param.getResult();
                            if (request == null) {
                                return;
                            }
                            Object urlObj = XposedHelpers.callMethod(request, "url");
                            String originalUrl = RewriteCore.safeToString(urlObj);
                            String rewrittenUrl = RewriteCore.rewriteUrl(originalUrl);
                            if (RewriteCore.safeEquals(originalUrl, rewrittenUrl)) {
                                return;
                            }
                            Object newBuilder = XposedHelpers.callMethod(request, "newBuilder");
                            XposedHelpers.callMethod(newBuilder, "url", rewrittenUrl);
                            Object rewrittenRequest = XposedHelpers.callMethod(newBuilder, "build");
                            param.setResult(rewrittenRequest);

                            if (originalUrl.contains("page/v3")
                                || originalUrl.contains("classification")
                                || originalUrl.contains("h5config")
                                || originalUrl.contains("themeActivity/views/activities/index.html")) {
                                RewriteCore.log(
                                    "generic request rewrite [" + label + "] "
                                        + originalUrl + " => " + rewrittenUrl
                                );
                            }
                        } catch (Throwable t) {
                            RewriteCore.log(
                                "failed generic request rewrite for " + builderClassName,
                                t
                            );
                        }
                    }
                }
            );
            RewriteCore.log("hooked " + builderClassName + ".build()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook " + builderClassName + ".build()", throwable);
        }
    }

    private void hookNetworkDiagnostics(final ClassLoader classLoader, final Class<?> requestClass) {
        try {
            final Class<?> requestorClass = XposedHelpers.findClass(
                "com.android.thememanager.controller.online.g",
                classLoader
            );
            final Class<?> connectionClass = XposedHelpers.findClass(
                "com.android.thememanager.controller.online.z",
                classLoader
            );
            final AtomicBoolean responseMethodsDumped = new AtomicBoolean(false);
            final AtomicBoolean requestMethodDumped = new AtomicBoolean(false);

            XposedHelpers.findAndHookMethod(
                requestorClass,
                "g",
                requestClass,
                File.class,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) {
                        try {
                            if (requestMethodDumped.compareAndSet(false, true)) {
                                RewriteCore.log("hooked controller.online.g.g(zurt, File)");
                            }
                            Object request = param.args[0];
                            Object outputFile = param.args[1];
                            boolean shouldEncrypt = ((Boolean) XposedHelpers.callMethod(
                                request,
                                "shouldEncryptParam"
                            )).booleanValue();
                            String baseUrl = RewriteCore.safeToString(XposedHelpers.callMethod(request, "getBaseUrl"));
                            String getUrl = RewriteCore.safeToString(XposedHelpers.callMethod(request, "getFinalGetUrl"));
                            Object post = XposedHelpers.callMethod(request, "getFinalPostUrl");
                            Pair<?, ?> pair = post instanceof Pair ? (Pair<?, ?>) post : null;
                            String postUrl = pair == null ? "null" : RewriteCore.safeToString(pair.first);
                            String postBody = pair == null ? "null" : RewriteCore.summarizeBody(
                                pair.second == null ? null : String.valueOf(pair.second)
                            );
                            RewriteCore.log(
                                "g.g request shouldEncrypt=" + shouldEncrypt
                                    + " baseUrl=" + baseUrl
                                    + " getUrl=" + getUrl
                                    + " postUrl=" + postUrl
                                    + " postBody=" + postBody
                                    + " outputFile=" + RewriteCore.describeFile(outputFile)
                            );
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump g.g request snapshot", t);
                        }
                    }
                }
            );

            XposedHelpers.findAndHookMethod(
                requestorClass,
                "y",
                connectionClass,
                new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) {
                        if (responseMethodsDumped.compareAndSet(false, true)) {
                            RewriteCore.log("hooked controller.online.g.y(z)");
                        }
                        try {
                            Object conn = param.args[0];
                            int code = ((Integer) XposedHelpers.callMethod(conn, "k")).intValue();
                            String reason = RewriteCore.safeToString(XposedHelpers.callMethod(conn, "q"));
                            String url = RewriteCore.safeToString(XposedHelpers.callMethod(conn, "n"));
                            String body = RewriteCore.summarizeBody(
                                RewriteCore.safeToString(XposedHelpers.callMethod(conn, "toq"))
                            );
                            int contentLength = ((Integer) XposedHelpers.callMethod(conn, "zy")).intValue();
                            RewriteCore.log(
                                "g.y response code=" + code
                                    + " reason=" + reason
                                    + " len=" + contentLength
                                    + " url=" + url
                                    + " body=" + body
                            );
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump g.y response snapshot", t);
                        }
                    }
                }
            );

            hookConnectionAccessors(connectionClass);
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook execution-layer diagnostics", throwable);
        }

        try {
            final Class<?> controllerClass = XposedHelpers.findClass(
                "com.android.thememanager.controller.s",
                classLoader
            );
            XposedHelpers.findAndHookMethod(
                controllerClass,
                "yz",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        try {
                            Object result = param.getResult();
                            if (!(result instanceof java.util.List)) {
                                RewriteCore.log("controller.s.yz() result=" + RewriteCore.safeToString(result));
                                return;
                            }
                            java.util.List<?> hashes = (java.util.List<?>) result;
                            RewriteCore.log(
                                "controller.s.yz() size=" + hashes.size()
                                    + " hashes=" + RewriteCore.summarizeList(hashes)
                            );
                            Object mapObj = XposedHelpers.getObjectField(param.thisObject, "t");
                            if (mapObj instanceof java.util.Map) {
                                java.util.Map<?, ?> map = (java.util.Map<?, ?>) mapObj;
                                int dumped = 0;
                                for (Object hash : hashes) {
                                    Object resource = map.get(hash);
                                    if (resource == null) {
                                        RewriteCore.log("yz resource[" + hash + "]=null");
                                    } else {
                                        String onlineId = RewriteCore.safeToString(
                                            XposedHelpers.callMethod(resource, "getOnlineId")
                                        );
                                        String title = RewriteCore.safeToString(
                                            XposedHelpers.callMethod(resource, "getTitle")
                                        );
                                        RewriteCore.registerResourceSnapshot(
                                            String.valueOf(hash),
                                            onlineId,
                                            title
                                        );
                                        RewriteCore.log(
                                            "yz resource[" + hash + "] onlineId=" + onlineId + " title=" + title
                                        );
                                    }
                                    dumped++;
                                    if (dumped >= 8) {
                                        break;
                                    }
                                }
                            } else {
                                RewriteCore.log("controller.s.t field=" + RewriteCore.safeToString(mapObj));
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump controller.s.yz()", t);
                        }
                    }
                }
            );
            RewriteCore.log("hooked controller.s.yz()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook controller.s.yz()", throwable);
        }

        try {
            final Class<?> helperClass = XposedHelpers.findClass(
                "com.android.thememanager.util.d",
                classLoader
            );
            XposedHelpers.findAndHookMethod(
                helperClass,
                "m",
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        RewriteCore.log(
                            "util.d.m()=" + RewriteCore.summarizeBody(
                                param.getResult() == null ? null : String.valueOf(param.getResult())
                            )
                        );
                    }
                }
            );
            RewriteCore.log("hooked util.d.m()");
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook util.d.m()", throwable);
        }

        try {
            final Class<?> exceptionClass = XposedHelpers.findClass(
                "com.android.thememanager.controller.online.n",
                classLoader
            );
            final AtomicBoolean exDumped = new AtomicBoolean(false);
            XposedBridge.hookAllConstructors(
                exceptionClass,
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        if (!exDumped.compareAndSet(false, true)) {
                            return;
                        }
                        try {
                            RewriteCore.log("constructed online exception class=" + exceptionClass.getName());
                            for (int i = 0; i < param.args.length; i++) {
                                RewriteCore.log("online exception arg[" + i + "]=" + String.valueOf(param.args[i]));
                            }
                            StackTraceElement[] stack = Thread.currentThread().getStackTrace();
                            for (int i = 0; i < stack.length && i < 24; i++) {
                                RewriteCore.log("online exception stack[" + i + "]=" + stack[i].toString());
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed to dump online exception", t);
                        }
                    }
                }
            );
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook online exception class", throwable);
        }
    }

    private void hookConnectionAccessors(final Class<?> connectionClass) {
        hookConnectionMethod(connectionClass, "k");
        hookConnectionMethod(connectionClass, "q");
        hookConnectionMethod(connectionClass, "toq");
        hookConnectionMethod(connectionClass, "n");
        hookConnectionMethod(connectionClass, "zy");
    }

    private void hookConnectionMethod(final Class<?> connectionClass, final String methodName) {
        try {
            XposedHelpers.findAndHookMethod(
                connectionClass,
                methodName,
                new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        try {
                            Object result = param.getResult();
                            if ("toq".equals(methodName)) {
                                RewriteCore.log("z." + methodName + "()=" + RewriteCore.summarizeBody(
                                    result == null ? null : String.valueOf(result)
                                ));
                            } else {
                                RewriteCore.log("z." + methodName + "()=" + RewriteCore.safeToString(result));
                            }
                        } catch (Throwable t) {
                            RewriteCore.log("failed to log z." + methodName + "()", t);
                        }
                    }
                }
            );
        } catch (Throwable throwable) {
            RewriteCore.log("failed to hook z." + methodName + "()", throwable);
        }
    }
}
