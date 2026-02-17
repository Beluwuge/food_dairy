plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.food_dairy"
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
        applicationId = "com.zest.app"
        minSdk = 21
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

    dependencies {
        // Import the Firebase BoM
        implementation(platform("com.google.firebase:firebase-bom:34.9.0"))

        // TODO: Add the dependencies for Firebase products you want to use
        // When using the BoM, don't specify versions in Firebase dependencies
        implementation("com.google.firebase:firebase-analytics")

        // Add the dependencies for any other desired Firebase products
        // https://firebase.google.com/docs/android/setup#available-libraries
    }
}

flutter {
    source = "../.."
}
