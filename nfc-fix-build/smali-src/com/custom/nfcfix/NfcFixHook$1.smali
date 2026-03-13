.class public Lcom/custom/nfcfix/NfcFixHook$1;
.super Lde/robv/android/xposed/XC_MethodHook;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Lde/robv/android/xposed/XC_MethodHook;-><init>()V
    return-void
.end method

.method protected beforeHookedMethod(Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;)V
    .registers 5
    .annotation system Ldalvik/annotation/Throws;
        value = { Ljava/lang/Throwable; }
    .end annotation

    # v0 = param.thisObject (the controller)
    iget-object v0, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->thisObject:Ljava/lang/Object;

    # try { backend = XposedHelpers.getObjectField(controller, "mPaymentBackend") }
    :try_start_backend
    const-string v1, "mPaymentBackend"
    invoke-static {v0, v1}, Lde/robv/android/xposed/XposedHelpers;->getObjectField(Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v0
    :try_end_backend
    .catch Ljava/lang/Throwable; {:try_start_backend .. :try_end_backend} :catch_backend

    # if (backend == null) -> safe exit
    if-nez v0, :check_app
    :backend_null
    const-string v1, "NfcFix: mPaymentBackend null, skip"
    invoke-static {v1}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    const/4 v1, 0x0
    invoke-virtual {p1, v1}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V
    return-void

    :check_app
    # try { defaultApp = backend.getDefaultApp() }
    :try_start_app
    const-string v1, "getDefaultApp"
    const/4 v2, 0x0
    new-array v2, v2, [Ljava/lang/Object;
    invoke-static {v0, v1, v2}, Lde/robv/android/xposed/XposedHelpers;->callMethod(Ljava/lang/Object;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v1
    :try_end_app
    .catch Ljava/lang/Throwable; {:try_start_app .. :try_end_app} :catch_app

    # if (defaultApp == null) -> safe exit
    if-nez v1, :all_ok
    :app_null
    const-string v2, "NfcFix: getDefaultApp null, skip"
    invoke-static {v2}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    const/4 v2, 0x0
    invoke-virtual {p1, v2}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V
    return-void

    :all_ok
    # defaultApp is valid, let original method run
    const-string v2, "NfcFix: all ok, proceeding"
    invoke-static {v2}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    return-void

    :catch_backend
    move-exception v1
    const-string v2, "NfcFix: backend field error"
    invoke-static {v2}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    const/4 v2, 0x0
    invoke-virtual {p1, v2}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V
    return-void

    :catch_app
    move-exception v2
    const-string v3, "NfcFix: getDefaultApp error"
    invoke-static {v3}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    const/4 v3, 0x0
    invoke-virtual {p1, v3}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V
    return-void
.end method
