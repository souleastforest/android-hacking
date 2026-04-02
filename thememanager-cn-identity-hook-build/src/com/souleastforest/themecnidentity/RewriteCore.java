package com.souleastforest.themecnidentity;

import android.net.Uri;
import android.util.Log;
import android.util.Pair;

import java.io.File;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Pattern;

import de.robv.android.xposed.XposedBridge;

final class RewriteCore {
    static final String LOG_TAG = "ThemeCnIdentity";
    static final String XPOSED_TAG = "Theme CN Identity";
    static final String TARGET_PACKAGE = "com.android.thememanager";
    static final String REQUEST_CLASS = "com.android.thememanager.controller.online.zurt";

    private static final Pattern REGION_PARAM = Pattern.compile("region=HK");
    private static final Pattern GLOBAL_PARAM = Pattern.compile("isGlobal=true");
    private static final Pattern VERSION_PARAM =
        Pattern.compile("version=13_V14\\.0\\.9\\.0\\.TMREUXM");
    private static final String CN_VERSION = "version=13_V14.0.27.0.TMRCNXM";
    private static final AtomicBoolean METHOD_DUMPED = new AtomicBoolean(false);
    private static final Map<String, ResourceSnapshot> RESOURCE_SNAPSHOTS =
        new ConcurrentHashMap<String, ResourceSnapshot>();

    static final class ResourceSnapshot {
        final String onlineId;
        final String title;

        ResourceSnapshot(String onlineId, String title) {
            this.onlineId = onlineId;
            this.title = title;
        }

        boolean isLocalOnly() {
            return onlineId == null
                || onlineId.length() == 0
                || "null".equalsIgnoreCase(onlineId)
                || "no_online_id".equalsIgnoreCase(onlineId);
        }
    }

    private RewriteCore() {}

    static void log(String message) {
        XposedBridge.log(XPOSED_TAG + ": " + message);
        Log.i(LOG_TAG, message);
    }

    static void log(String message, Throwable throwable) {
        XposedBridge.log(XPOSED_TAG + ": " + message + ": " + throwable);
        Log.e(LOG_TAG, message, throwable);
    }

    static String rewriteUrl(String input) {
        if (input == null) {
            return null;
        }
        String output = input;
        output = REGION_PARAM.matcher(output).replaceAll("region=CN");
        output = GLOBAL_PARAM.matcher(output).replaceAll("isGlobal=false");
        output = VERSION_PARAM.matcher(output).replaceAll(CN_VERSION);
        return output;
    }

    static Pair<String, String> rewritePostResult(Pair<?, ?> pair) {
        String first = pair.first == null ? null : String.valueOf(pair.first);
        String second = pair.second == null ? null : String.valueOf(pair.second);
        return new Pair<String, String>(rewriteUrl(first), rewriteUrl(second));
    }

    static boolean isCheckUpdateUrl(String url) {
        return url != null && url.contains("checkupdate/hashpair");
    }

    static boolean containsUsedThemesHistory(String body) {
        return body != null && body.contains("usedThemesHistory=");
    }

    static void registerResourceSnapshot(String hash, String onlineId, String title) {
        if (hash == null || hash.length() == 0) {
            return;
        }
        RESOURCE_SNAPSHOTS.put(hash, new ResourceSnapshot(onlineId, title));
    }

    static boolean hasNonEmptyFileshash(String raw) {
        String fileshash = extractFormParam(raw, "fileshash");
        return fileshash != null && fileshash.length() > 0;
    }

    static Pair<String, String> filterLocalOnlyFileshashForCheckUpdate(String url, String body) {
        String fileshash = extractFormParam(body, "fileshash");
        if (fileshash == null || fileshash.length() == 0) {
            fileshash = extractFormParam(url, "fileshash");
        }
        if (fileshash == null || fileshash.length() == 0) {
            return new Pair<String, String>(url, body);
        }

        String[] pieces = fileshash.split(",");
        List<String> kept = new ArrayList<String>();
        List<String> dropped = new ArrayList<String>();
        for (int i = 0; i < pieces.length; i++) {
            String piece = pieces[i];
            ResourceSnapshot snapshot = RESOURCE_SNAPSHOTS.get(piece);
            if (snapshot != null && snapshot.isLocalOnly()) {
                dropped.add(piece + " [" + safeToString(snapshot.title) + "]");
            } else {
                kept.add(piece);
            }
        }

        if (dropped.isEmpty()) {
            return new Pair<String, String>(url, body);
        }

        String replacement = joinCsv(kept);
        log(
            "Filtered local-only fileshash for checkupdate/hashpair kept="
                + summarizeList(kept)
                + " dropped="
                + summarizeList(dropped)
        );
        return new Pair<String, String>(
            replaceOrRemoveFormParam(url, "fileshash", replacement),
            replaceOrRemoveFormParam(body, "fileshash", replacement)
        );
    }

    static String appendEncodedFormField(String body, String key, String value) {
        if (value == null || value.length() == 0) {
            return body;
        }
        String encoded = Uri.encode(value);
        String suffix = key + "=" + encoded;
        if (body == null || body.length() == 0) {
            return suffix;
        }
        return body + "&" + suffix;
    }

    static String extractFormParam(String raw, String key) {
        if (raw == null || key == null || key.length() == 0) {
            return null;
        }
        int queryIndex = raw.indexOf('?');
        String query = queryIndex >= 0 ? raw.substring(queryIndex + 1) : raw;
        if (query.length() == 0) {
            return null;
        }
        String[] pairs = query.split("&");
        for (int i = 0; i < pairs.length; i++) {
            String pair = pairs[i];
            int eq = pair.indexOf('=');
            String candidateKey = eq >= 0 ? pair.substring(0, eq) : pair;
            if (key.equals(candidateKey)) {
                String value = eq >= 0 ? pair.substring(eq + 1) : "";
                return Uri.decode(value);
            }
        }
        return null;
    }

    static String replaceOrRemoveFormParam(String raw, String key, String newValue) {
        if (raw == null || key == null || key.length() == 0) {
            return raw;
        }
        int queryIndex = raw.indexOf('?');
        String prefix = queryIndex >= 0 ? raw.substring(0, queryIndex + 1) : "";
        String query = queryIndex >= 0 ? raw.substring(queryIndex + 1) : raw;
        if (query.length() == 0) {
            return raw;
        }
        String[] pairs = query.split("&");
        List<String> rebuilt = new ArrayList<String>();
        boolean replaced = false;
        for (int i = 0; i < pairs.length; i++) {
            String pair = pairs[i];
            int eq = pair.indexOf('=');
            String candidateKey = eq >= 0 ? pair.substring(0, eq) : pair;
            if (key.equals(candidateKey)) {
                replaced = true;
                if (newValue != null && newValue.length() > 0) {
                    rebuilt.add(key + "=" + Uri.encode(newValue));
                }
            } else if (pair.length() > 0) {
                rebuilt.add(pair);
            }
        }
        if (!replaced) {
            return raw;
        }
        String joined = joinAmp(rebuilt);
        if (queryIndex >= 0) {
            return prefix + joined;
        }
        return joined;
    }

    static boolean safeEquals(String a, String b) {
        return a == null ? b == null : a.equals(b);
    }

    static String safeToString(Object value) {
        return value == null ? "null" : String.valueOf(value);
    }

    static String summarizeBody(String body) {
        if (body == null) {
            return "null";
        }
        String normalized = body.replace('\n', ' ').replace('\r', ' ');
        if (normalized.length() <= 160) {
            return normalized;
        }
        return normalized.substring(0, 160) + "...";
    }

    static String describeFile(Object maybeFile) {
        if (!(maybeFile instanceof File)) {
            return safeToString(maybeFile);
        }
        File file = (File) maybeFile;
        return file.getAbsolutePath() + " (exists=" + file.exists() + ", len=" + file.length() + ")";
    }

    static String summarizeList(List<?> values) {
        if (values == null) {
            return "null";
        }
        StringBuilder sb = new StringBuilder();
        sb.append("[");
        int limit = Math.min(values.size(), 8);
        for (int i = 0; i < limit; i++) {
            if (i > 0) {
                sb.append(", ");
            }
            sb.append(safeToString(values.get(i)));
        }
        if (values.size() > limit) {
            sb.append(", ... total=").append(values.size());
        }
        sb.append("]");
        return sb.toString();
    }

    static String joinCsv(List<String> values) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < values.size(); i++) {
            if (i > 0) {
                sb.append(",");
            }
            sb.append(values.get(i));
        }
        return sb.toString();
    }

    static String joinAmp(List<String> values) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < values.size(); i++) {
            if (i > 0) {
                sb.append("&");
            }
            sb.append(values.get(i));
        }
        return sb.toString();
    }

    static void dumpMethodSummaryOnce(Class<?> requestClazz) {
        if (!METHOD_DUMPED.compareAndSet(false, true)) {
            return;
        }
        try {
            Method[] methods = requestClazz.getDeclaredMethods();
            Arrays.sort(methods, new java.util.Comparator<Method>() {
                @Override
                public int compare(Method left, Method right) {
                    return left.getName().compareTo(right.getName());
                }
            });
            StringBuilder sb = new StringBuilder();
            sb.append("method summary for ").append(requestClazz.getName()).append(": ");
            for (int i = 0; i < methods.length; i++) {
                Method method = methods[i];
                sb.append(method.getReturnType().getSimpleName())
                    .append(" ")
                    .append(method.getName())
                    .append("(");
                Class<?>[] params = method.getParameterTypes();
                for (int j = 0; j < params.length; j++) {
                    if (j > 0) {
                        sb.append(", ");
                    }
                    sb.append(params[j].getSimpleName());
                }
                sb.append(")");
                if (i < methods.length - 1) {
                    sb.append("; ");
                }
            }
            log(sb.toString());
        } catch (Throwable throwable) {
            log("failed to dump method summary", throwable);
        }
    }
}
