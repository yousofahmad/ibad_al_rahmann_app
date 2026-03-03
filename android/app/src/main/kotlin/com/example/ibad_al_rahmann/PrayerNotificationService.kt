package com.example.ibad_al_rahmann

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

class PrayerNotificationService : Service() {

    private val refreshHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val refreshRunnable = object : Runnable {
        override fun run() {
            updateAllWidgets()
            refreshHandler.postDelayed(this, 1000 * 60) // 60 seconds
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        if (action == "UPDATE_PRAYER_NOTIFICATION") {
            // Start Auto-Refresh if not started
            refreshHandler.removeCallbacks(refreshRunnable)
            refreshHandler.postDelayed(refreshRunnable, 1000 * 60)

            val fajr = intent.getStringExtra("fajr") ?: "--:--"
            val dhuhr = intent.getStringExtra("dhuhr") ?: "--:--"
            val asr = intent.getStringExtra("asr") ?: "--:--"
            val maghrib = intent.getStringExtra("maghrib") ?: "--:--"
            val isha = intent.getStringExtra("isha") ?: "--:--"
            val nextName = intent.getStringExtra("nextName") ?: "انتظر"
            val countdown = intent.getStringExtra("countdown") ?: ""
            val hijri = intent.getStringExtra("hijri") ?: ""
            val currentPrayerIndex = intent.getIntExtra("prayerIndex", -1)
            val nextPrayerEpoch = intent.getLongExtra("nextPrayerEpoch", 0L)

            val notification = buildPersistentNotification(
                fajr, dhuhr, asr, maghrib, isha, nextName, countdown, hijri, currentPrayerIndex, nextPrayerEpoch
            )

            // Start Foreground
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                     startForeground(777, notification)
                } catch (e: Exception) {
                     startForeground(777, notification)
                }
            } else {
                startForeground(777, notification)
            }
        } else if (action == "STOP_PRAYER_NOTIFICATION") {
            refreshHandler.removeCallbacks(refreshRunnable)
            stopForeground(true)
            stopSelf()
        }

        return START_STICKY
    }

    private fun updateAllWidgets() {
        // Trigger Update for all our widget providers
        val providers = arrayOf(
            PrayerWidgetWideProvider::class.java,
            PrayerWidgetLargeProvider::class.java,
            PrayerWidgetGoldProvider::class.java
        )
        
        for (provider in providers) {
            val intent = Intent(this, provider).apply {
                action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(this)
            val ids = appWidgetManager.getAppWidgetIds(android.content.ComponentName(this, provider))
            if (ids.isNotEmpty()) {
                intent.putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                sendBroadcast(intent)
            }
        }
    }

    override fun onDestroy() {
        refreshHandler.removeCallbacks(refreshRunnable)
        super.onDestroy()
    }

    private fun buildPersistentNotification(
        fajr: String, dhuhr: String, asr: String, maghrib: String, isha: String,
        nextName: String, countdown: String, hijri: String, activeIndex: Int, nextPrayerEpoch: Long
    ): Notification {
        val channelId = "persistent_prayer_v2"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "شريط وقت الصلاة",
                NotificationManager.IMPORTANCE_DEFAULT 
            )
            channel.setShowBadge(false)
            channel.setSound(null, null) // No sound for persistent notification
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        // Inflate custom layout
        val remoteViews = RemoteViews(packageName, R.layout.custom_notification)

        // Set Texts
        remoteViews.setTextViewText(R.id.tv_fajr_time, fajr)
        remoteViews.setTextViewText(R.id.tv_dhuhr_time, dhuhr)
        remoteViews.setTextViewText(R.id.tv_asr_time, asr)
        remoteViews.setTextViewText(R.id.tv_maghrib_time, maghrib)
        remoteViews.setTextViewText(R.id.tv_isha_time, isha)
        
        // nextName is already formatted by Dart (e.g. "الفجر متبقي" or "مضى على الفجر")
        remoteViews.setTextViewText(R.id.tv_next_prayer_name, nextName)

        // Use Chronometer for live countdown with seconds
        if (nextPrayerEpoch > 0L) {
            val nowMs = System.currentTimeMillis()
            val differenceMs = nextPrayerEpoch - nowMs
            val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
            remoteViews.setChronometer(R.id.tv_next_prayer_countdown, baseTime, null, true)
            // Support count-up mode (when differenceMs is negative = elapsed)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                remoteViews.setChronometerCountDown(R.id.tv_next_prayer_countdown, differenceMs > 0)
            }
        } else {
            // Fallback to static text if no epoch
            remoteViews.setChronometer(R.id.tv_next_prayer_countdown, android.os.SystemClock.elapsedRealtime(), null, false)
        }

        remoteViews.setTextViewText(R.id.tv_hijri_date, hijri)

        // Highlight Active Prayer (gold accent for active, default for others)
        val accentColorId = R.color.widget_accent
        val defaultColorId = R.color.widget_text_secondary

        // Reset all times and labels to default first
        val timeIds = intArrayOf(R.id.tv_fajr_time, R.id.tv_dhuhr_time, R.id.tv_asr_time, R.id.tv_maghrib_time, R.id.tv_isha_time)
        val labelIds = intArrayOf(R.id.tv_fajr_label, R.id.tv_dhuhr_label, R.id.tv_asr_label, R.id.tv_maghrib_label, R.id.tv_isha_label)
        for (i in timeIds.indices) {
            remoteViews.setTextColor(timeIds[i], getColor(defaultColorId))
            remoteViews.setTextColor(labelIds[i], getColor(defaultColorId))
        }

        // Highlight the current one (both label and time)
        if (activeIndex in 0..4) {
            remoteViews.setTextColor(timeIds[activeIndex], getColor(accentColorId))
            remoteViews.setTextColor(labelIds[activeIndex], getColor(accentColorId))
        }

        // Also highlight the Next Prayer Name and Countdown in the header
        remoteViews.setTextColor(R.id.tv_next_prayer_name, getColor(accentColorId))
        remoteViews.setTextColor(R.id.tv_next_prayer_countdown, getColor(accentColorId))

        // Tap on notification opens the App
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews) // Extends if there's space
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true) 
            .setPriority(NotificationCompat.PRIORITY_MAX) // MAX so it stays at the top of notification shade
            .setSound(null) // No sound for persistent notification
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC) // Show on lock screen
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
