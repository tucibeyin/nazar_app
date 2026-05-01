plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.nazar_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Play Store'a çıkmadan önce benzersiz bir applicationId ver.
        // Örn: "com.tucibeyin.nazarapp"  — mevcut kurulumları kırar, önceden yap.
        applicationId = "com.example.nazar_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Yayın öncesi gerçek bir keystore ile imzalama konfigürasyonu ekle.
            // Şimdilik debug key kullanılıyor (Play Store'a bu key ile yüklenirse
            // sonradan değiştirilemez — keystore dosyasını güvenli sakla).
            signingConfig = signingConfigs.getByName("debug")

            // R8 ile kod küçültme + kaynak küçültme
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
