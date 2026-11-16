package com.myhours.my_hours

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * 计时前台服务。
 *
 * 为什么必须是前台服务：Android 8 之后后台进程会被冻结，普通定时器活不过
 * 几分钟。用户锁屏去干活，回来时计时必须还在走——只有前台服务能保证这点。
 *
 * 计时本身交给系统的 Chronometer（`setUsesChronometer`），它由 SystemUI
 * 逐秒重绘，我们不需要每秒唤醒自己去更新通知。这是省电的关键：服务只在
 * 开始 / 暂停 / 停止三个时刻被唤醒。
 */
class TimerService : Service() {

    companion object {
        const val CHANNEL_ID = "myhours_timer"
        const val NOTIFICATION_ID = 4201
        const val EXTRA_ELAPSED = "elapsed_ms"
        const val EXTRA_LABEL = "label"
        const val EXTRA_RUNNING = "running"

        fun start(context: Context, elapsedMs: Long, label: String, running: Boolean) {
            val intent = Intent(context, TimerService::class.java).apply {
                putExtra(EXTRA_ELAPSED, elapsedMs)
                putExtra(EXTRA_LABEL, label)
                putExtra(EXTRA_RUNNING, running)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TimerService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val elapsed = intent?.getLongExtra(EXTRA_ELAPSED, 0L) ?: 0L
        val label = intent?.getStringExtra(EXTRA_LABEL) ?: "计时中"
        val running = intent?.getBooleanExtra(EXTRA_RUNNING, true) ?: true
        startForeground(NOTIFICATION_ID, buildNotification(elapsed, label, running))
        // 被系统杀掉后由 START_STICKY 拉起；具体数值由 Flutter 侧恢复时重新下发。
        return START_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "计时",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "记录正在进行的计时"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(
        elapsedMs: Long,
        label: String,
        running: Boolean,
    ): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(label)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (running) {
            // 交给 SystemUI 逐秒重绘：不唤醒进程，也不耗电。
            builder
                .setUsesChronometer(true)
                .setWhen(System.currentTimeMillis() - elapsedMs)
                .setChronometerCountDown(false)
                .setContentText(format(elapsedMs))
        } else {
            // 暂停：停掉 chronometer，改成静态时长。
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setContentText("已暂停 · ${format(elapsedMs)}")
        }

        // Android 16（API 36）起，带短关键文本的常驻通知会自动进入状态栏
        // 胶囊（Live Update）。低版本没有这个方法，用反射调用，
        // 这样一份代码能同时编译给 minSdk 24 和运行在 36 上。
        if (Build.VERSION.SDK_INT >= 36) {
            try {
                val text = format(elapsedMs)
                builder.javaClass
                    .getMethod("setShortCriticalText", CharSequence::class.java)
                    .invoke(builder, text)
            } catch (_: Throwable) {
                // 厂商修改了实现：静默降级为普通常驻通知。
            }
        }

        return builder.build()
    }

    private fun format(ms: Long): String {
        val total = (ms / 1000).coerceAtLeast(0)
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) {
            String.format("%d:%02d:%02d", h, m, s)
        } else {
            String.format("%02d:%02d", m, s)
        }
    }
}
