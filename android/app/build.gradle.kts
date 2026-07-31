import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = rootProject.file("key.properties")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseKeyPropertiesFile.isFile) {
    releaseKeyPropertiesFile.inputStream().use(releaseKeyProperties::load)
} else if (releaseBuildRequested) {
    throw GradleException(
        "release signing requires android/key.properties",
    )
}

fun releaseKeyProperty(name: String): String {
    return releaseKeyProperties.getProperty(name)
        ?: throw GradleException("missing $name in android/key.properties")
}

android {
    namespace = "com.akator.wallet"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.akator.wallet"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeyPropertiesFile.isFile) {
            create("release") {
                keyAlias = releaseKeyProperty("keyAlias")
                keyPassword = releaseKeyProperty("keyPassword")
                storeFile = file(releaseKeyProperty("storeFile"))
                storePassword = releaseKeyProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}
