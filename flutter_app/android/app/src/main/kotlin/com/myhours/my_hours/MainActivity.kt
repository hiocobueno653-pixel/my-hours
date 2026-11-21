package com.myhours.my_hours

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 计时通知的桥。
 *
 * Flutter 负责计时逻辑与数据写入，这里只做一件事：把「正在计时」这件事
 * 交给系统，让它在用户离开应用后依然可见。两边只交换三个时刻的状态
 * （开始 / 暂停 / 停止），不做秒级同步——秒级由通知自带的 Chronometer
 * 在 SystemUI 里走。
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            requestNotificationPermissionIfNeeded()
                            val elapsed =
                                (call.argument<Number>("elapsedMs") ?: 0).toLong()
                            val label = call.argument<String>("label") ?: "计时中"
                            val running = call.argument<Boolean>("running") ?: true
                            TimerService.start(this, elapsed, label, running)
                            result.success(null)
                        }
                        "stop" -> {
                            TimerService.stop(this)
                            result.success(null)
                        }
                        // 让界面能如实告诉用户：这台机器到底支不支持胶囊。
                        "capabilities" -> {
                            result.success(
                                mapOf(
                                    "sdkInt" to android.os.Build.VERSION.SDK_INT,
                                    "manufacturer" to android.os.Build.MANUFACTURER,
                                    "brand" to android.os.Build.BRAND,
                                    "model" to android.os.Build.MODEL,
                                    "notificationsGranted" to
                                        (Build.VERSION.SDK_INT < 33 ||
                                            checkSelfPermission(
                                                Manifest.permission.POST_NOTIFICATIONS,
                                            ) == PackageManager.PERMISSION_GRANTED),
                                ),
                            )
                        }
                        "notificationSettings" -> {
                            val intent = if (Build.VERSION.SDK_INT >= 26) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName"),
                                )
                            }
                            startActivity(intent)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("timer_error", t.message, null)
                }
            }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < 33) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    companion object {
        private const val CHANNEL = "com.myhours.app/timer"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4202
    }
}
