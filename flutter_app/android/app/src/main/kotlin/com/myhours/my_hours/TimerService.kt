package com.myhours.my_hours

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * 计时前台服务。
 *
 * 为什么必须是前台服务：Android 8 之后后台进程会被冻结，普通定时器活不过
 * 几分钟。用户锁屏去干活，回来时计时必须还在走——只有前台服务能保证这点。
 *
 * 时间由本服务自己推算（`SystemClock.elapsedRealtime`），不依赖 Flutter 每秒
 * 喂数据：App 退到后台后 Dart 侧可能被挂起，而服务必须继续走。
 */
class TimerService : Service() {

    companion object {
        const val CHANNEL_ID = "myhours_timer"
        const val NOTIFICATION_ID = 4201
        const val EXTRA_ELAPSED = "elapsed_ms"
        const val EXTRA_LABEL = "label"
        const val EXTRA_RUNNING = "running"

        /**
         * 胶囊收起时显示的短文本是**静态字符串**，不会自己走秒。
         * 每 10 秒重发一次通知让它跟上——再密就是白耗电，
         * 再疏用户会觉得「卡住了」。
         */
        private const val REFRESH_MS = 10_000L

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

    private val handler = Handler(Looper.getMainLooper())

    private var baseElapsedMs = 0L
    private var startedAtRealtime = 0L
    private var running = false
    private var label = "正在计时"
    private var foregroundStarted = false

    private val refreshTask = object : Runnable {
        override fun run() {
            if (!running) return
            postNotification()
            handler.postDelayed(this, REFRESH_MS)
        }
    }

    /** 当前已用时长：基准值 + 自上次开始以来的真实时间差。 */
    private fun currentElapsed(): Long =
        if (running) {
            baseElapsedMs + (SystemClock.elapsedRealtime() - startedAtRealtime)
        } else {
            baseElapsedMs
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        baseElapsedMs = intent?.getLongExtra(EXTRA_ELAPSED, 0L) ?: 0L
        label = intent?.getStringExtra(EXTRA_LABEL) ?: "正在计时"
        running = intent?.getBooleanExtra(EXTRA_RUNNING, true) ?: true
        startedAtRealtime = SystemClock.elapsedRealtime()

        val notification = buildNotification(currentElapsed(), label, running)
        if (!foregroundStarted) {
            startForeground(NOTIFICATION_ID, notification)
            foregroundStarted = true
        } else {
            getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification)
        }

        handler.removeCallbacks(refreshTask)
        if (running) handler.postDelayed(refreshTask, REFRESH_MS)

        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun postNotification() {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(currentElapsed(), label, running))
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
            // 必须是「持续状态」分类才会被系统当成正在进行的活动；
            // 用 STOPWATCH 分类不会进状态栏胶囊。
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (running) {
            // 展开态交给 SystemUI 的 Chronometer 逐秒重绘，不唤醒进程。
            builder
                .setUsesChronometer(true)
                .setWhen(System.currentTimeMillis() - elapsedMs)
                .setChronometerCountDown(false)
                .setContentText(format(elapsedMs))
        } else {
            builder
                .setUsesChronometer(false)
                .setShowWhen(false)
                .setContentText("已暂停 · ${format(elapsedMs)}")
        }

        applyPromoted(builder, format(elapsedMs), label)
        return builder.build()
    }

    /**
     * 把这条通知提升为「胶囊级」常驻通知。
     *
     * 三条路一起走，能中哪条算哪条：
     * 1. Android 16 的 `setRequestPromotedOngoing` —— 反射调用，低版本没有；
     * 2. Notification.extras 的平台约定键 —— 部分 ROM 直接读 extras；
     * 3. MIUI 焦点通知的私有参数 —— 小米/红米走这一条。
     *
     * 都不中时它就是普通常驻通知，功能不受影响。
     */
    private fun applyPromoted(
        builder: NotificationCompat.Builder,
        shortText: String,
        title: String,
    ) {
        try {
            builder.javaClass
                .getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
                .invoke(builder, true)
        } catch (_: Throwable) {
            // 系统没有这个 API
        }

        val extras = builder.extras
        extras.putBoolean("android.requestPromotedOngoing", true)
        extras.putCharSequence("android.shortCriticalText", shortText)
        extras.putString("capsule_text", shortText)

        try {
            val focusParam = JSONObject().apply {
                put("type", 1)
                put(
                    "baseInfo",
                    JSONObject().apply {
                        put("title", title)
                        put("content", shortText)
                    },
                )
            }
            extras.putString("miui.focus.param", focusParam.toString())
        } catch (_: Throwable) {
            // 构造失败就不带这条路
        }
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
