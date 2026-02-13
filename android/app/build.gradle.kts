plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin, Android ve Kotlin pluginlerinden sonra gelmeli
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.merge_blocks"
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
        // Kendi package id'n neyse onu yaz
        applicationId = "com.example.merge_blocks"

        // shared_preferences_android için güvenli alt sınır
        minSdk = 21

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Şimdilik debug signing (CI/build için yeterli)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
