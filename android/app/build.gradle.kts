plugins {
    id("com.android.application")
    id("kotlin-android")
<<<<<<< HEAD
    id("dev.flutter.flutter-gradle-plugin")
=======
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase google-services plugin
>>>>>>> c00c9d440be47def005461b5f096b9180b2c8584
    id("com.google.gms.google-services")
}

android {
    namespace = "com.saafhisaab.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.saafhisaab.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
<<<<<<< HEAD
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
=======
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
>>>>>>> c00c9d440be47def005461b5f096b9180b2c8584
        }
    }
}

dependencies {
<<<<<<< HEAD
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
=======
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
>>>>>>> c00c9d440be47def005461b5f096b9180b2c8584
}

flutter {
    source = "../.."
}
