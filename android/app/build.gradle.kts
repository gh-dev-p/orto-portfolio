import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// リリース署名鍵（android/key.properties・android/keystore/release.jks、どちらもgitignore対象）。
// このマシン以外で `flutter build` の release ビルドを行う場合は、同じ2ファイルを別途安全な方法で配置すること。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Kotlin 2.3 では android.kotlinOptions の jvmTarget がエラーになるため、compilerOptions で指定する
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.example.orto"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.orto"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 環境分離（dev/prod、アーキテクチャ設計書6章）：Firebaseプロジェクトの取り違え事故を
    // 構造的に防ぐため、applicationId自体をFlavorごとに分ける。google-services.jsonは
    // Google Servicesプラグインの規約通りsrc/<flavor>/配下に配置する。
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Orto Dev")
            // 招待リンクのドメイン（AndroidManifest.xmlのApp Linksから参照。lib/config/invite_links.dartと対応）
            manifestPlaceholders["inviteLinkHost"] = "orto-dev.example.com"
            manifestPlaceholders["inviteLinkAltHost"] = "open-dev.example.com"
            // 招待リンクのカスタムURLスキーム（AndroidManifest.xmlから参照。lib/config/invite_links.dartと対応）
            manifestPlaceholders["appUrlScheme"] = "orto-dev"
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Orto")
            manifestPlaceholders["inviteLinkHost"] = "orto.example.com"
            manifestPlaceholders["inviteLinkAltHost"] = "open.example.com"
            manifestPlaceholders["appUrlScheme"] = "orto"
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // android/key.properties が無い環境（このマシン以外でのビルド等）では、
            // debugの鍵にフォールバックする（`flutter run --release` 等が壊れないようにするため）。
            // ストア提出用のビルドは、必ずkey.propertiesがある状態（このマシン）で行うこと。
            signingConfig = if (hasReleaseSigning) {
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
    // アルバムの動画の圧縮（VideoProcessingChannel.kt、機能仕様書4.4.9）
    implementation("androidx.media3:media3-transformer:1.8.1")
    implementation("androidx.media3:media3-effect:1.8.1")
    implementation("androidx.media3:media3-common:1.8.1")
}
