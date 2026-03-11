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
            syncFromSharedPrefs()
            refreshHandler.postDelayed(this, 15 * 60 * 1000) // Refresh every 15 minutes (Chronometer handles seconds)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_STICKY // Default to sticky

        when (action) {
            "UPDATE_PRAYER_NOTIFICATION" -> {
                // Initial data from intent (from Foreground App)
                refreshHandler.removeCallbacks(refreshRunnable)
                handleUpdateIntent(intent)
                refreshHandler.postDelayed(refreshRunnable, 15 * 60 * 1000)
            }
            "STOP_PRAYER_NOTIFICATION" -> {
                refreshHandler.removeCallbacks(refreshRunnable)
                stopForeground(true)
                stopSelf()
            }
            else -> {
                // Likely a system restart or sticky restart
                if (action != "SYNC") {
                   syncFromSharedPrefs()
                }
                refreshHandler.removeCallbacks(refreshRunnable)
                refreshHandler.postDelayed(refreshRunnable, 15 * 60 * 1000)
            }
        }

        return START_STICKY
    }

    private fun handleUpdateIntent(intent: Intent) {
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
        val isCountUp = intent.getBooleanExtra("isCountUp", false)

        val notification = buildPersistentNotification(
            fajr, dhuhr, asr, maghrib, isha, nextName, countdown, hijri, currentPrayerIndex, nextPrayerEpoch, isCountUp
        )
        startForeground(777, notification)
        updateAllWidgets()
    }

    private fun syncFromSharedPrefs() {
        // SharedPreferences for HomeWidget is where Dart saves data.
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        
        val fajr = prefs.getString("fajr", "--:--") ?: "--:--"
        val dhuhr = prefs.getString("dhuhr", "--:--") ?: "--:--"
        val asr = prefs.getString("asr", "--:--") ?: "--:--"
        val maghrib = prefs.getString("maghrib", "--:--") ?: "--:--"
        val isha = prefs.getString("isha", "--:--") ?: "--:--"
        val hijri = prefs.getString("hijri", "") ?: ""
        
        // Epochs
        val fEpoch = prefs.getLong("fajr_epoch", 0L)
        val dEpoch = prefs.getLong("dhuhr_epoch", 0L)
        val aEpoch = prefs.getLong("asr_epoch", 0L)
        val mEpoch = prefs.getLong("maghrib_epoch", 0L)
        val iEpoch = prefs.getLong("isha_epoch", 0L)
        val sEpoch = prefs.getLong("sunrise_epoch", 0L)

        if (fEpoch == 0L) return // No data yet

        // ─── Smart Logic ───
        val now = System.currentTimeMillis()
        val epochs = longArrayOf(fEpoch, dEpoch, aEpoch, mEpoch, iEpoch)
        val names = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
        
        // 1. Determine Current Prayer index (the one we are 'after')
        var currentIndex = 4 // Default to Isha if before Fajr or after Isha
        if (now < fEpoch) {
            currentIndex = 4 // It's "after Isha" of yesterday
        } else {
            for (i in 0..4) {
                if (now >= epochs[i]) {
                    currentIndex = i
                } else {
                    break
                }
            }
        }
        
        // 2. Determine Next Prayer index
        var nextIndex = (currentIndex + 1) % 5
        var nextTargetEpoch = epochs[nextIndex]
        if (nextIndex == 0 && now >= epochs[4]) {
            // Next is Fajr Tomorrow (roughly fEpoch + 24h)
            nextTargetEpoch = fEpoch + (24 * 60 * 60 * 1000)
        } else if (now < fEpoch) {
            // Next is Today's Fajr
            nextTargetEpoch = fEpoch
        }

        // 3. Count-up Rule (45 mins)
        val currentEpoch = epochs[currentIndex]
        val elapsedFromCurrent = now - currentEpoch
        val countUpWindowMs = 45 * 60 * 1000L
        val isCountUp = elapsedFromCurrent in 0..countUpWindowMs
        
        val targetEpoch = if (isCountUp) currentEpoch else nextTargetEpoch
        val statusName = if (isCountUp) "مضى على ${names[currentIndex]}" else "متبقي على ${names[nextIndex]}"
        val highlightedIndex = if (isCountUp) currentIndex else nextIndex

        // Schedule a precise refresh when the count-up window expires
        if (isCountUp) {
            val remainingMs = countUpWindowMs - elapsedFromCurrent + 1000
            refreshHandler.postDelayed({ syncFromSharedPrefs() }, remainingMs)
        }
        
        val notification = buildPersistentNotification(
            fajr, dhuhr, asr, maghrib, isha, statusName, "", hijri, highlightedIndex, targetEpoch, isCountUp
        )
        startForeground(777, notification)
        updateAllWidgets()
    }

    private fun updateAllWidgets() {
        val providers = arrayOf(
            PrayerWidgetProvider::class.java,
            PrayerWidgetWideProvider::class.java,
            PrayerWidgetLargeProvider::class.java
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
        nextName: String, countdown: String, hijri: String, activeIndex: Int, nextPrayerEpoch: Long, isCountUp: Boolean
    ): Notification {
        val channelId = "persistent_prayer_v2"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "شريط وقت الصلاة",
                NotificationManager.IMPORTANCE_LOW // Use LOW to avoid sound/interruption on update
            )
            channel.setShowBadge(false)
            channel.setSound(null, null)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val nowMs = System.currentTimeMillis()
        val differenceMs = nextPrayerEpoch - nowMs
        val signStr = if (nextPrayerEpoch > 0L) {
            if (isCountUp) "+" else "-"
        } else {
            ""
        }

        val collapsedView = RemoteViews(packageName, R.layout.notification_collapsed)
        collapsedView.setTextViewText(R.id.tv_next_prayer_name, toArabicDigits(nextName))
        collapsedView.setTextViewText(R.id.tv_hijri_date, toArabicDigits(hijri))

        if (nextPrayerEpoch > 0L) {
            val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
            collapsedView.setChronometer(R.id.tv_next_prayer_countdown, baseTime, "$signStr%s", true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                collapsedView.setChronometerCountDown(R.id.tv_next_prayer_countdown, !isCountUp)
            }
        }

        val expandedView = RemoteViews(packageName, R.layout.custom_notification)
        fun setTimeAndAmPm(timeStr: String, timeId: Int, ampmId: Int) {
            val parts = timeStr.trim().split(" ")
            expandedView.setTextViewText(timeId, toArabicDigits(parts.getOrNull(0) ?: timeStr))
            expandedView.setTextViewText(ampmId, parts.getOrNull(1) ?: "")
        }

        setTimeAndAmPm(fajr, R.id.tv_fajr_time, R.id.tv_fajr_am_pm)
        setTimeAndAmPm(dhuhr, R.id.tv_dhuhr_time, R.id.tv_dhuhr_am_pm)
        setTimeAndAmPm(asr, R.id.tv_asr_time, R.id.tv_asr_am_pm)
        setTimeAndAmPm(maghrib, R.id.tv_maghrib_time, R.id.tv_maghrib_am_pm)
        setTimeAndAmPm(isha, R.id.tv_isha_time, R.id.tv_isha_am_pm)
        
        expandedView.setTextViewText(R.id.tv_next_prayer_name, toArabicDigits(nextName))
        if (nextPrayerEpoch > 0L) {
            val baseTime = android.os.SystemClock.elapsedRealtime() + differenceMs
            expandedView.setChronometer(R.id.tv_next_prayer_countdown, baseTime, "$signStr%s", true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                expandedView.setChronometerCountDown(R.id.tv_next_prayer_countdown, !isCountUp)
            }
        }
        expandedView.setTextViewText(R.id.tv_hijri_date, toArabicDigits(hijri))

        val accentColorId = R.color.widget_accent
        val defaultColorId = R.color.widget_text_secondary
        val timeIds = intArrayOf(R.id.tv_fajr_time, R.id.tv_dhuhr_time, R.id.tv_asr_time, R.id.tv_maghrib_time, R.id.tv_isha_time)
        val amPmIds = intArrayOf(R.id.tv_fajr_am_pm, R.id.tv_dhuhr_am_pm, R.id.tv_asr_am_pm, R.id.tv_maghrib_am_pm, R.id.tv_isha_am_pm)
        val labelIds = intArrayOf(R.id.tv_fajr_label, R.id.tv_dhuhr_label, R.id.tv_asr_label, R.id.tv_maghrib_label, R.id.tv_isha_label)
        
        for (i in 0..4) {
            val color = if (i == activeIndex) getColor(accentColorId) else getColor(defaultColorId)
            expandedView.setTextColor(timeIds[i], color)
            expandedView.setTextColor(amPmIds[i], color)
            expandedView.setTextColor(labelIds[i], color)
        }

        expandedView.setTextColor(R.id.tv_next_prayer_name, getColor(accentColorId))
        expandedView.setTextColor(R.id.tv_next_prayer_countdown, getColor(accentColorId))

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setCustomContentView(collapsedView)
            .setCustomBigContentView(expandedView)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH) // Changed to HIGH for better visibility
            .setSound(null)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun toArabicDigits(input: String): String {
        val english = arrayOf("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
        val arabic = arrayOf("٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩")
        var result = input
        for (i in english.indices) result = result.replace(english[i], arabic[i])
        return result
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
