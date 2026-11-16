package com.myhours.my_hours

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
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("timer_error", t.message, null)
                }
            }
    }

    companion object {
        private const val CHANNEL = "com.myhours.app/timer"
    }
}
