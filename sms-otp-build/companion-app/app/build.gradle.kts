plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.souleastforest.smsotp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.souleastforest.smsotp"
        minSdk = 30          // Android 11+（KernelSU 主流支持范围）
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false     // priv-app 不需要混淆，避免 AccessibilityService 类名被改变
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    // 使用平台签名（开发阶段用 debug keystore，生产需平台签名）
    signingConfigs {
        getByName("debug") {
            // debug 用于本机测试，正式部署需使用 platform key
            storeFile = file("../../debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.kotlinx.coroutines.android)
}
