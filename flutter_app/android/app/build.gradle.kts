import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 复用 React 版已有的 release 签名（android/keystore.properties + myhours-release.keystore）。
// 同 applicationId + 同签名 + versionCode 递增 = 可覆盖升级，用户数据不必换包迁移。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("../../android/keystore.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.myhours.my_hours"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true
    }

    defaultConfig {
        applicationId = "com.myhours.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file("../../android/" + keystoreProperties["storeFile"])
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 缺密钥直接失败，不回落到 debug 签名。
            //
            // 用 debug 签名产出的「release 包」签名指纹不一致，已安装用户
            // 下次装真 release 会 INSTALL_FAILED_UPDATE_INCOMPATIBLE，
            // 只能卸载重装（本地数据全丢）；而 apksigner 对 debug 证书同样
            // 返回 0，校验不报错，问题只会在用户身上爆发。
            if (!hasReleaseKeystore) {
                throw GradleException(
                    "缺少 android/keystore.properties 或 myhours-release.keystore：" +
                        "release 包必须用固定签名。要本地试跑请用 --debug 构建。",
                )
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Flutter 只换了引擎的 target-platform，插件自带的 jniLibs 仍可能把
    // armeabi-v7a/x86_64 打进单 ABI 包。必须按 target-platform 再裁一次，
    // 否则 32 位手机可能装上一个缺 libflutter/libapp 的包并启动即退。
    packaging {
        val targetPlatforms = (project.findProperty("target-platform") as String?)
            ?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
        val abi = when (targetPlatforms.singleOrNull()) {
            "android-arm64" -> "arm64-v8a"
            "android-arm" -> "armeabi-v7a"
            "android-x64" -> "x86_64"
            "android-x86" -> "x86"
            else -> null
        }
        if (abi != null) {
            jniLibs {
                excludes += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
                    .filter { it != abi }
                    .map { "lib/$it/**" }
            }
        }
    }

    // 两个变体：完整版与「只记工时」（后者 applicationId 加 .hours，可与完整版共存）
    flavorDimensions += "variant"
    productFlavors {
        create("full") {
            dimension = "variant"
            applicationId = "com.myhours.app"
            resValue("string", "app_name", "时页")
        }
        create("hours") {
            dimension = "variant"
            applicationId = "com.myhours.app.hours"
            resValue("string", "app_name", "时页·工时")
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
