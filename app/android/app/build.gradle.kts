import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key for Play, from android/key.properties (kept out of git).
// Without it a release build stops, because a debug-signed build in someone's
// hands can never be updated by a Play build without losing their people.
// For a release walk on your own devices, sign with the debug key on purpose:
// flutter build apk --release -PallowDebugSigning=true
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keyProperties.getProperty("storeFile")
    ?.let { file(it).exists() } ?: false
val allowDebugSigning = providers.gradleProperty("allowDebugSigning").orNull == "true"

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project && it.name.contains("Release")
    }
    if (buildsRelease && !hasUploadKey && !allowDebugSigning) {
        throw GradleException(
            "No upload key: create android/key.properties (see " +
                "docs/release-steps.md), or set allowDebugSigning=true " +
                "for a build that never leaves your own devices."
        )
    }
}

android {
    namespace = "com.rememberem.rememberem"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by flutter_local_notifications (daily reminders).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.rememberem.rememberem"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            // Keep what the reminder plugin needs (see proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Geofencing for place notifications: the same library and version
    // geolocator already ships, so nothing new goes into the app.
    implementation("com.google.android.gms:play-services-location:21.2.0")
}
