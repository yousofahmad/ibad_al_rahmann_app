package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action

        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            rescheduleAllAlarms(context)
            refreshFromStoredEpochs(context)
            WidgetUpdateHelper.onPrayerAlarmFired(context, -1)
            WidgetUpdateHelper.scheduleMidnightRefresh(context) // تشغيل محرك منتصف الليل
            return
        }

        // ── DST / date / time change ──────────────────────────────────────────────
        if (action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == "android.intent.action.TIME_SET") {
            refreshFromStoredEpochs(context)
            return
        }

        val alarmId = intent.getIntExtra("alarm_id", 0)

        // ── محرك منتصف الليل (تحديث الويدجت والأذان لليوم الجديد ذاتياً) ──
        if (alarmId == 9999) {
            refreshFromStoredEpochs(context) // سيجلب مواقيت اليوم الجديد من الـ 30 يوم
            WidgetUpdateHelper.scheduleMidnightRefresh(context) // جدولة منتصف الليل لليوم التالي
            return
        }
        
        // Ignore rogue broadcasts with no valid alarm_id.
        // This solves the bug where a rogue "تنبيه / حان الوقت" notification
        // appears alongside normal alarms (like Adhan).
        if (alarmId == 0) return
        
        // If it's a prayer alarm (100-105), update widget and notification autonomously
        if (alarmId in 100..105) {
            WidgetUpdateHelper.onPrayerAlarmFired(context, alarmId)

            // Force-push widget update to beat Doze-mode throttling
            val widgetManager = android.appwidget.AppWidgetManager.getInstance(context)
            val providers = listOf(
                PrayerWidgetProvider::class.java,
                PrayerWidgetLargeProvider::class.java,
                PrayerWidgetWideProvider::class.java,
            )
            for (provider in providers) {
                val ids = widgetManager.getAppWidgetIds(
                    android.content.ComponentName(context, provider)
                )
                if (ids.isNotEmpty()) {
                    val updateIntent = Intent(context, provider).apply {
                        setAction(android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                        putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(updateIntent)
                }
            }
        }

        // --- Original Alarm Logic (Sound/Notification) ---
        val soundName = intent.getStringExtra("sound_name") ?: "default"
        val cleanSoundNameEarly = soundName.replace(".mp3", "").lowercase().trim()
        
        // Abort early only if truly disabled. Silent notifications should proceed.
        if (cleanSoundNameEarly == "none" || cleanSoundNameEarly == "null") return
        
        val prayerNameFallback = when {
            alarmId == 100 || alarmId == 110 || alarmId == 1000 || alarmId == 3000 || alarmId == 4000 || alarmId == 5000 -> "الفجر"
            alarmId == 101 || alarmId == 111 || alarmId == 3001 || alarmId == 4001 || alarmId == 5001 -> "الشروق"
            alarmId == 102 || alarmId == 112 || alarmId == 1002 || alarmId == 3002 || alarmId == 4002 || alarmId == 5002 -> "الظهر"
            alarmId == 103 || alarmId == 113 || alarmId == 1003 || alarmId == 3003 || alarmId == 4003 || alarmId == 5003 -> "العصر"
            alarmId == 104 || alarmId == 114 || alarmId == 1004 || alarmId == 3004 || alarmId == 4004 || alarmId == 5004 -> "المغرب"
            alarmId == 105 || alarmId == 115 || alarmId == 1005 || alarmId == 3005 || alarmId == 4005 || alarmId == 5005 -> "العشاء"
            else -> null
        }

        val fallbackTitle = if (prayerNameFallback != null) {
            when {
                alarmId >= 5000 -> "إقامة صلاة $prayerNameFallback"
                alarmId >= 4000 -> "أذان صلاة $prayerNameFallback"
                alarmId >= 3000 -> "تنبيه موعد $prayerNameFallback"
                else -> "صلاة $prayerNameFallback"
            }
        } else when (alarmId) {
            1 -> "أذكار الصباح"
            2 -> "الرقية الشرعية"
            3 -> "أذكار المساء"
            4 -> "الرقية الشرعية"
            else -> ""
        }

        val fallbackBody = if (prayerNameFallback != null) {
            when {
                // 1. Iqama Messages
                alarmId >= 5000 -> when (prayerNameFallback) {
                    "الفجر" -> "تقام الآن صلاة الفجر .. أفلح من صلى"
                    else -> "تقام الآن صلاة $prayerNameFallback .. استووا واعتدلوا"
                }
                // 2. Adhan/Prayer Messages (Wisdoms)
                alarmId >= 4000 || alarmId < 3000 -> when (prayerNameFallback) {
                    "الفجر" -> "من صلى الفجر في جماعة فهو في ذمة الله"
                    "الشروق" -> "حان الآن وقت شروق الشمس"
                    "الظهر" -> "لا تجعل عملك يلهيك عن أداء الصلاة"
                    "العصر" -> "حافظوا على الصلوات والصلاة الوسطى"
                    "المغرب" -> "لا يزال الناس بخير ما عجلوا الفطر"
                    "العشاء" -> "صلاة العشاء في جماعة كقيام نصف الليل"
                    else -> "حان الآن موعد صلاة $prayerNameFallback"
                }
                // 3. Pre-prayer Messages
                alarmId >= 3000 -> "الدعاء لا يرد بين الأذان والإقامة .. استعد للصلاة"
                else -> "حان الآن موعد صلاة $prayerNameFallback"
            }
        } else when (alarmId) {
            1 -> "حان موعد أذكار الصباح .. حصن نفسك"
            2 -> "حصن نفسك الآن بالرقية الشرعية"
            3 -> "حان موعد أذكار المساء .. ذكر الله طمأنينة"
            4 -> "حصن نفسك الآن بالرقية الشرعية"
            else -> ""
        }

        val title = (intent.getStringExtra("title") ?: fallbackTitle).trim()
        val body = (intent.getStringExtra("body") ?: fallbackBody).trim()
        val payload = intent.getStringExtra("payload") ?: "home"
        val audioPath = intent.getStringExtra("audio_path")
        val customSoundName = intent.getStringExtra("custom_sound_name")

        if (title.isNotEmpty() && body.isNotEmpty()) {
            // ── Day-of-week gate for weekly alarms (IDs 5, 6, 7) ──────────────
            val todayDow = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
            val wrongDay = when (alarmId) {
                5 -> todayDow != Calendar.MONDAY && todayDow != Calendar.SUNDAY
                6, 7, 8 -> todayDow != Calendar.THURSDAY && todayDow != Calendar.WEDNESDAY
                else -> false
            }
            if (wrongDay) {
                val targetDow = if (alarmId == 5) Calendar.MONDAY else Calendar.THURSDAY
                val hour = intent.getIntExtra("hour", 0)
                val minute = intent.getIntExtra("minute", 0)
                val cal = Calendar.getInstance()
                do { cal.add(Calendar.DAY_OF_YEAR, 1) } while (cal.get(Calendar.DAY_OF_WEEK) != targetDow)
                MainActivity.scheduleAlarm(
                    context, alarmId,
                    cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
                    hour, minute, soundName, title, body, payload, false, audioPath, 0, customSoundName
                )
                handleAlarmChaining(context, intent, alarmId, soundName, title, body, payload, audioPath)
                return
            }

            // ── Quiet Hours Gate for Salawat and Takbeerat ──
            var skipNotif = false
            if (alarmId in 8000..8999) {
                // Salawat range (8000+) uses general quiet_hours
                if (isInQuietHours(context, "quiet_hours")) {
                    skipNotif = true
                }
            } else if (alarmId in 9000..9199) {
                // Takbeerat range uses takbeerat_quiet_hours
                if (isInQuietHours(context, "takbeerat_quiet_hours")) {
                    skipNotif = true
                }
            }
            // --- Backward Compatibility for Ghost Salawat Alarms ---
            var finalSoundName = soundName
            var finalPayload = payload
            var finalCustomSoundName = customSoundName
            if (alarmId == 950 || alarmId in 8000..9500) {
                finalSoundName = "saly_3ala_mo7amad"
                finalCustomSoundName = "saly_3ala_mo7amad"
                finalPayload = "salawat"
            }

            if (!skipNotif) {
                NativeLogger.log(context, "Notification Fired! Title: $title | Body: $body | AlarmId: $alarmId | Payload: $finalPayload")
                showNotification(context, alarmId, title, body, finalSoundName, finalPayload, audioPath, finalCustomSoundName)
            }
        }

        // Use the fixed soundName and payload for chaining
        var chainSoundName = soundName
        var chainPayload = payload
        var chainCustomSoundName = customSoundName
        if (alarmId == 950 || alarmId in 8000..9500) {
            chainSoundName = "saly_3ala_mo7amad"
            chainCustomSoundName = "saly_3ala_mo7amad"
            chainPayload = "salawat"
        }

        handleAlarmChaining(context, intent, alarmId, chainSoundName, title, body, chainPayload, audioPath)
    }

    private fun isInQuietHours(context: Context, prefix: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Flutter's shared_preferences stores ints as Longs on Android.
        // Reading as getInt() will crash if the value was saved by Flutter.
        // We use allKeys to check the actual type or use a helper.
        fun getSafeInt(key: String, def: Int): Int {
            return try {
                if (prefs.contains(key)) {
                    val v = prefs.all[key]
                    if (v is Long) v.toInt()
                    else if (v is Int) v
                    else def
                } else def
            } catch (e: Exception) {
                def
            }
        }

        val startHour = getSafeInt("flutter.${prefix}_start_hour", 23)
        val startMin = getSafeInt("flutter.${prefix}_start_minute", 0)
        val endHour = getSafeInt("flutter.${prefix}_end_hour", 7)
        val endMin = getSafeInt("flutter.${prefix}_end_minute", 0)

        val cal = Calendar.getInstance()
        val nowTime = cal.get(Calendar.HOUR_OF_DAY) + cal.get(Calendar.MINUTE) / 60.0
        val startTime = startHour + startMin / 60.0
        val endTime = endHour + endMin / 60.0

        return if (startTime <= endTime) {
            nowTime >= startTime && nowTime < endTime
        } else {
            nowTime >= startTime || nowTime < endTime
        }
    }

    private fun rescheduleAllAlarms(context: Context) {
        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        val allEntries = prefs.all
        
        for ((key, value) in allEntries) {
            // We look for keys like "alarm_123_active" where value is true
            if (key.startsWith("alarm_") && key.endsWith("_active") && value == true) {
                try {
                    val idStr = key.substring(6, key.length - 7)
                    val id = idStr.toIntOrNull() ?: continue
                    
                    val hour = prefs.getInt("alarm_${id}_hour", 6)
                    val minute = prefs.getInt("alarm_${id}_minute", 0)
                    val savedSound = prefs.getString("alarm_${id}_sound", null)
                    val soundName = savedSound ?: if (id in 100..105) "nafis" else "default"
                    val customSound = prefs.getString("alarm_${id}_custom_sound", null)
                    
                    val fallbackTitle = when (id) {
                        100 -> "صلاة الفجر"
                        101 -> "وقت الشروق"
                        102 -> "صلاة الظهر"
                        103 -> "صلاة العصر"
                        104 -> "صلاة المغرب"
                        105 -> "صلاة العشاء"
                        else -> ""
                    }
                    val fallbackBody = when (id) {
                        100 -> "حان الآن موعد صلاة الفجر"
                        101 -> "حان الآن وقت الشروق"
                        102 -> "حان الآن موعد صلاة الظهر"
                        103 -> "حان الآن موعد صلاة العصر"
                        104 -> "حان الآن موعد صلاة المغرب"
                        105 -> "حان الآن موعد صلاة العشاء"
                        else -> ""
                    }
                    
                    val title = prefs.getString("alarm_${id}_title", fallbackTitle)
                    val body = prefs.getString("alarm_${id}_body", fallbackBody)
                    val payload = prefs.getString("alarm_${id}_payload", null)
                    val audioPath = prefs.getString("alarm_${id}_audioPath", null)
                    val interval = prefs.getInt("alarm_${id}_interval", 0)

                    val year = prefs.getInt("alarm_${id}_year", -1)
                    val month = prefs.getInt("alarm_${id}_month", -1)
                    val day = prefs.getInt("alarm_${id}_day", -1)

                    MainActivity.scheduleAlarm(context, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, interval, customSound)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun handleAlarmChaining(context: Context, intent: Intent, alarmId: Int, soundName: String, title: String, body: String, payload: String, audioPath: String?) {
        if (alarmId == 1 || alarmId == 3) {
            // Morning Azkar (1) -> Ruqyah (2), Evening Azkar (3) -> Ruqyah (4)
            showNotification(context, alarmId + 1, "🛡️ الرقية الشرعية", "حصن نفسك الآن بالرقية الشرعية", "ruqyah", "ruqyah", null)
        }

        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
        // ... (rest of the method unchanged)

        if (alarmId in 5..8) {
            val isActive = prefs.getBoolean("alarm_${alarmId}_active", true)
            if (!isActive) return
            val hour = intent.getIntExtra("hour", 0)
            val minute = intent.getIntExtra("minute", 0)
            val cal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 7) }
            MainActivity.scheduleAlarm(
                context, alarmId,
                cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
                hour, minute, soundName, title, body, payload, false, audioPath, 0
            )
            return
        } else if (alarmId < 1000 && alarmId !in 100..105 && alarmId !in 9..11) {
            val isActive = prefs.getBoolean("alarm_${alarmId}_active", true)
            if (!isActive) return

            val hour = intent.getIntExtra("hour", 0)
            val minute = intent.getIntExtra("minute", 0)
            val interval = intent.getIntExtra("interval_minutes", 0)
            MainActivity.scheduleAlarm(context, alarmId, -1, -1, -1, hour, minute, soundName, title, body, payload, true, audioPath, interval)
        } else if (alarmId in 8000..8999 || alarmId in 9000..9199) {
            val isActive = prefs.getBoolean("alarm_${alarmId}_active", true)
            if (!isActive) return

            val interval = intent.getIntExtra("interval_minutes", 0)
            if (interval > 0) {
                val cal = Calendar.getInstance()
                
                // Use the intended trigger time as base to prevent drift
                val triggerYear = intent.getIntExtra("year", cal.get(Calendar.YEAR))
                val triggerMonth = intent.getIntExtra("month", cal.get(Calendar.MONTH) + 1)
                val triggerDay = intent.getIntExtra("day", cal.get(Calendar.DAY_OF_MONTH))
                val triggerHour = intent.getIntExtra("hour", cal.get(Calendar.HOUR_OF_DAY))
                val triggerMinute = intent.getIntExtra("minute", cal.get(Calendar.MINUTE))
                
                cal.set(triggerYear, triggerMonth - 1, triggerDay, triggerHour, triggerMinute, 0)
                cal.set(Calendar.MILLISECOND, 0)
                
                // Add interval
                cal.add(Calendar.MINUTE, interval)
                
                // If the calculated next time is already in the past, keep adding interval 
                // until we find the next future occurrence (prevents 'notification storm' on wake)
                val now = Calendar.getInstance()
                while (cal.before(now)) {
                    cal.add(Calendar.MINUTE, interval)
                }

                MainActivity.scheduleAlarm(
                    context, alarmId,
                    cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH),
                    cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE),
                    soundName, title, body, payload, false, audioPath, interval
                )
            }
        }
    }

    private fun refreshFromStoredEpochs(context: Context) {
        // Clear ghost broadcast alarms from the old broken logic
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (id in 100..115) {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            alarmManager.cancel(pi)
            pi.cancel()
        }

        NativePrayerScheduler.scheduleToday(context)

        val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
            action = "SYNC"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svcIntent)
        } else {
            context.startService(svcIntent)
        }

        WidgetUpdateHelper.onPrayerAlarmFired(context, -1)
        WidgetUpdateHelper.scheduleMidnightRefresh(context)
    }

    private fun showNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?, customSoundName: String? = null) {
        val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()

        // Absolute return for none/null — ensures no ghost notifications
        if (cleanSoundName == "none" || cleanSoundName == "null") return

        val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
            action = "PLAY_SOUND"
            putExtra("notification_id", notifId)
            putExtra("title", title)
            putExtra("body", content)
            putExtra("target_page", targetPage)
            putExtra("sound_name", soundName)
            if (customSoundName != null) putExtra("custom_sound_name", customSoundName)
            if (audioPath != null) putExtra("audio_path", audioPath)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(svcIntent)
        } else {
            context.startService(svcIntent)
        }
    }

    companion object {
        fun buildAndShowNotification(context: Context, notifId: Int, title: String, content: String, soundName: String, targetPage: String, audioPath: String?, customSoundName: String? = null) {
            val cleanSoundName = soundName.replace(".mp3", "").lowercase().trim()

            // Absolute return for none/null — ensures no ghost notifications
            if (cleanSoundName == "none" || cleanSoundName == "null") return

            val svcIntent = Intent(context, PrayerNotificationService::class.java).apply {
                action = "PLAY_SOUND"
                putExtra("notification_id", notifId)
                putExtra("title", title)
                putExtra("body", content)
                putExtra("target_page", targetPage)
                putExtra("sound_name", soundName)
                if (customSoundName != null) putExtra("custom_sound_name", customSoundName)
                if (audioPath != null) putExtra("audio_path", audioPath)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(svcIntent)
            } else {
                context.startService(svcIntent)
            }
        }

        fun forceUpdateAllWidgets(context: Context) {
            val providers = arrayOf(PrayerWidgetProvider::class.java, PrayerWidgetLargeProvider::class.java, PrayerWidgetWideProvider::class.java)
            for (provider in providers) {
                val intent = Intent(context, provider).apply { action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE }
                val ids = android.appwidget.AppWidgetManager.getInstance(context).getAppWidgetIds(android.content.ComponentName(context, provider))
                if (ids.isNotEmpty()) {
                    intent.putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    context.sendBroadcast(intent)
                }
            }
        }
    }


}
