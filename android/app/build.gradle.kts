import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

// Parses `--dart-define=KEY=value` entries passed by the Flutter Gradle plugin.
fun loadDartDefines(): Map<String, String> {
    val result = mutableMapOf<String, String>()
    if (!project.hasProperty("dart-defines")) {
        return result
    }
    val raw = project.property("dart-defines") as String
    raw.split(",").filter { it.isNotEmpty() }.forEach { encoded ->
        val decoded = String(Base64.getDecoder().decode(encoded))
        val separator = decoded.indexOf('=')
        if (separator > 0) {
            result[decoded.substring(0, separator)] =
                decoded.substring(separator + 1)
        }
    }
    return result
}

val dartDefines = loadDartDefines()
val apiBaseUrlFromDartDefine = dartDefines["API_BASE_URL"] ?: ""

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin
    // plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

android {
    namespace = "com.munawwaracare.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.munawwaracare.android"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["usesCleartextTraffic"] = "false"
        buildConfigField(
            "String",
            "API_BASE_URL",
            "\"${apiBaseUrlFromDartDefine.replace("\"", "\\\"")}\"",
        )
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core-telecom:1.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("com.google.firebase:firebase-messaging:24.1.0")
}
