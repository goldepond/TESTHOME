plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.property"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        // Kotlin 컴파일러 캐시 문제 해결
        freeCompilerArgs += listOf("-Xno-call-assertions", "-Xno-receiver-assertions", "-Xno-param-assertions")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.property"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            isDebuggable = true
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // APK 출력 설정 추가
    buildFeatures {
        buildConfig = true
    }
    
    // APK 출력 경로 설정
    applicationVariants.all {
        outputs.all {
            if (this is com.android.build.gradle.internal.api.BaseVariantOutputImpl) {
                if (name == "debug") {
                    outputFileName = "app-debug.apk"
                    // The following will ensure the APK is named correctly and placed in the default output directory
                    // For custom output directory, a copy step may be needed post-build
                } else {
                    outputFileName = "app-${name}.apk"
                }
            }
        }
    }
    
    // Automatically copy debug APK to Flutter-expected location
    tasks.whenTaskAdded {
        if (name.startsWith("assemble")) {
            doLast {
                val variant = if (name.endsWith("Debug")) "debug" else "release"
                val sourceApk = File("${project.buildDir}/outputs/apk/$variant/app-$variant.apk")
                val targetDir = File("${rootProject.projectDir}/../build/app/outputs/flutter-apk")
                val targetApk = File(targetDir, "app-$variant.apk")
                
                if (sourceApk.exists()) {
                    targetDir.mkdirs()
                    sourceApk.copyTo(targetApk, overwrite = true)
                    println("✅ APK copied to Flutter-expected location: ${targetApk.absolutePath}")
                } else {
                    println("⚠️ Source APK not found: ${sourceApk.absolutePath}")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-analytics")
}
