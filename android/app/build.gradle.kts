plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.laxman_1"

    // 📍 FIX 1: Update to 36 as requested by your plugins
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 📍 FIX 2: Enable Core Desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.laxman_1"
        minSdk = flutter.minSdkVersion

        // 📍 FIX 3: targetSdk can stay 34 or move to 36
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // 📍 FIX 4: Add the desugaring library (Required for notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}

flutter {
    source = "../.."
}
