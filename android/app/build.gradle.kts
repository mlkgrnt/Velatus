plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.velatus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        // Committed on purpose. Every machine and CI runner generates its own
        // debug key by default, which means two builds of the same version have
        // different signatures and Android refuses to upgrade in place. This
        // key only signs sideload builds — it is the standard, public Android
        // debug key, not a secret. Swap in a real release key before publishing
        // to a store.
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.velatus"
        // ML Kit's bundled text recognition model needs API 21+, and the
        // photo picker path is cleanest on 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with the committed debug key so sideloaded builds can be
            // upgraded in place. Replace it with a private release key before
            // shipping through a store.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // google_mlkit_text_recognition declares every script — Chinese, Devanagari,
    // Japanese, Korean — as `compileOnly`, so the app has to pull in the model it
    // actually uses. Without this the Chinese recogniser is absent at runtime
    // (NoClassDefFoundError) and R8 fails on the dangling reference.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
