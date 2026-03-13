.class public Lcom/custom/nfcfix/NfcFixHook;
.super Ljava/lang/Object;
.implements Lde/robv/android/xposed/IXposedHookLoadPackage;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public handleLoadPackage(Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;)V
    .registers 5
    .annotation system Ldalvik/annotation/Throws;
        value = { Ljava/lang/Throwable; }
    .end annotation

    # if (!pkg.equals("com.android.settings")) return
    iget-object v0, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->packageName:Ljava/lang/String;
    const-string v1, "com.android.settings"
    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :return

    const-string v0, "NfcFix: hooking com.android.settings"
    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    iget-object v0, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->classLoader:Ljava/lang/ClassLoader;
    invoke-direct {p0, v0}, Lcom/custom/nfcfix/NfcFixHook;->hookOnResume(Ljava/lang/ClassLoader;)V

    :return
    return-void
.end method

.method private hookOnResume(Ljava/lang/ClassLoader;)V
    .registers 6

    # XposedHelpers.findAndHookMethod(className, classLoader, methodName, new Callback())
    # Build the varargs Object[] = { our XC_MethodHook instance }
    const/4 v0, 0x1
    new-array v0, v0, [Ljava/lang/Object;

    new-instance v1, Lcom/custom/nfcfix/NfcFixHook$1;
    invoke-direct {v1}, Lcom/custom/nfcfix/NfcFixHook$1;-><init>()V
    const/4 v2, 0x0
    aput-object v1, v0, v2

    const-string v1, "com.android.settings.nfc.MiuiNfcPayPreferenceController"
    const-string v2, "onResume"
    invoke-static {v1, p1, v2, v0}, Lde/robv/android/xposed/XposedHelpers;->findAndHookMethod(Ljava/lang/String;Ljava/lang/ClassLoader;Ljava/lang/String;[Ljava/lang/Object;)Lde/robv/android/xposed/XC_MethodHook$Unhook;
    move-result-object v1

    const-string v0, "NfcFix: hooked onResume ok"
    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    return-void
.end method
