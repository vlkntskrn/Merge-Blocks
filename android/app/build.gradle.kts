plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin, Android ve Kotlin pluginlerinden sonra gelmeli
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Teknik package name (kalıcı kimlik)
    namespace = "com.vlkntskrn.mergeblocksneonchain"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Google Play'de uygulamanın teknik kimliği (AAB'den okunur)
        applicationId = "com.vlkntskrn.mergeblocksneonchain"

        // shared_preferences / ads / billing için güvenli alt sınır
        minSdk = 21

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Şimdilik debug signing (test/internal build için)
            // Production'a geçerken gerçek release keystore bağlayacağız
            signingConfig = signingConfigs.getByName("debug")

            // İstersen şimdilik kapalı bırak
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
