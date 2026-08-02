plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.projectstride.stride"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.projectstride.stride"

        // Android 8.0. Set by the Health Connect client library's floor, not by
        // preference.
        //
        // Player consequence: devices below Android 8.0 cannot install Stride.
        // That is a 2017 cutoff and effectively no one in the owner-and-friends
        // audience.
        //
        // A softer consequence matters more and is NOT excluded here: Health
        // Connect is built into the platform from Android 14, and on Android 8
        // through 13 it needs the separate Health Connect app installed. Those
        // players can install and play Stride normally -- they simply get the
        // graceful no-health-service path until they add it. The game must stay
        // fully playable in that state (DECISIONS/0008), which is exactly what
        // the M-2 adapter shell exercises by reporting `unavailable`.
        //
        // See DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md.
        minSdk = 26

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
