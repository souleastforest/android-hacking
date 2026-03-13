package de.robv.android.xposed;

import java.lang.reflect.Method;
import java.lang.reflect.Field;

public class XposedHelpers {
    public static Object getObjectField(Object obj, String fieldName) throws NoSuchFieldException {
        return null;
    }

    public static Object callMethod(Object obj, String methodName, Object... args) throws NoSuchMethodException {
        return null;
    }

    public static void findAndHookMethod(String className, ClassLoader classLoader,
            String methodName, Object... parameterTypesAndCallback) {
    }

    public static void findAndHookMethod(Class<?> clazz, String methodName,
            Object... parameterTypesAndCallback) {
    }

    public static Field findField(Class<?> clazz, String fieldName) throws NoSuchFieldException {
        return null;
    }

    public static Class<?> findClass(String className, ClassLoader classLoader)
            throws ClassNotFoundException {
        return null;
    }
}
