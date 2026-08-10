package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class BackgroundMethodChannelPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private lateinit var context: Context

    companion object {
        private const val CHANNEL = "app.ibad_al_rahmann/native_notifications"
        var currentChannel: MethodChannel? = null
        
        // Keep a static reference for MainActivity to use if needed, 
        // though plugin registration is preferred.
        fun setupMethodChannel(context: Context, methodChannel: MethodChannel) {
            val instance = BackgroundMethodChannelPlugin()
            instance.context = context
            instance.channel = methodChannel
            instance.setup(methodChannel)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        currentChannel = channel
        setup(channel!!)
        // Flush any pending navigation payload that arrived before the channel was ready
        val pending = MainActivity.pendingNavigationPayload
        if (pending != null) {
            android.util.Log.d("PrayerApp", "BackgroundPlugin: flushing pending payload '$pending' to Flutter")
            channel!!.invokeMethod("onPayloadReceived", pending)
            MainActivity.pendingNavigationPayload = null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        if (currentChannel == channel) currentChannel = null
        channel = null
    }

    private fun setup(methodChannel: MethodChannel) {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "nativeLog" -> {
                    val message = call.argument<String>("message") ?: ""
                    NativeLogger.log(context, "[Flutter] $message")
                    result.success(null)
                }
                "getLaunchPayload" -> {
                    result.success(MainActivity.getAndClearLaunchPayload())
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val intent = Intent(context, AlarmReceiver::class.java)
                    val pendingIntent = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    alarmManager.cancel(pendingIntent)
                    context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                        .edit().putBoolean("alarm_${id}_active", false).apply()
                    result.success("Canceled")
                }
                "cancelAlarms" -> {
                    val ids = call.argument<List<Int>>("ids")
                    if (ids != null) {
                        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (id in ids) {
                            val intent = Intent(context, AlarmReceiver::class.java)
                            val pendingIntent = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                            alarmManager.cancel(pendingIntent)
                            editor.putBoolean("alarm_${id}_active", false)
                            
                            // Cancel legacy flutter_local_notifications if they exist
                            try {
                                val legacyIntent = Intent().setClassName(context, "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver")
                                val legacyPi = PendingIntent.getBroadcast(context, id, legacyIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                                alarmManager.cancel(legacyPi)
                            } catch (e: Exception) {}
                        }
                        editor.apply()
                    }
                    result.success("Batch Canceled")
                }
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val year = call.argument<Int>("year") ?: -1
                    val month = call.argument<Int>("month") ?: -1
                    val day = call.argument<Int>("day") ?: -1
                    val hour = call.argument<Int>("hour") ?: 6
                    val minute = call.argument<Int>("minute") ?: 0
                    val soundName = call.argument<String>("sound") ?: call.argument<String>("soundName") ?: "nafis"
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val payload = call.argument<String>("payload")
                    val audioPath = call.argument<String>("audioPath")
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    val allowedDays = call.argument<String>("allowed_days")
                    
                    val customSoundName = call.argument<String>("custom_sound_name")
                    val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    MainActivity.scheduleAlarmInternal(context, editor, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, intervalMinutes, customSoundName, allowedDays)
                    editor.apply()
                    result.success("Scheduled")
                }
                "scheduleAlarms" -> {
                    val alarms = call.argument<List<Map<String, Any>>>("alarms")
                    if (alarms != null) {
                        val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (alarm in alarms) {
                            val id = alarm["id"] as? Int ?: continue
                            val year = alarm["year"] as? Int ?: -1
                            val month = alarm["month"] as? Int ?: -1
                            val day = alarm["day"] as? Int ?: -1
                            val hour = alarm["hour"] as? Int ?: 6
                            val minute = alarm["minute"] as? Int ?: 0
                            val soundName = alarm["sound"] as? String ?: alarm["soundName"] as? String ?: "nafis"
                            val title = alarm["title"] as? String
                            val body = alarm["body"] as? String
                            val payload = alarm["payload"] as? String
                            val audioPath = alarm["audioPath"] as? String
                            val intervalMinutes = alarm["intervalMinutes"] as? Int ?: 0
                            val customSoundName = alarm["custom_sound_name"] as? String
                            val allowedDays = alarm["allowed_days"] as? String
                            
                            MainActivity.scheduleAlarmInternal(context, editor, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, intervalMinutes, customSoundName, allowedDays)
                        }
                        editor.apply()
                    }
                    result.success("Batch Scheduled")
                }
                "printAllAlarms" -> {
                    val prefs = context.getSharedPreferences("AzkarNativePrefs", Context.MODE_PRIVATE)
                    val allEntries = prefs.all
                    val activeAlarms = allEntries.keys.filter { it.endsWith("_active") && prefs.getBoolean(it, false) }
                        .map { it.replace("alarm_", "").replace("_active", "") }
                        
                    val sb = java.lang.StringBuilder()
                    sb.append("--- ALARM AUDIT LOG ---\n")
                    for (id in activeAlarms) {
                        val year = prefs.getInt("alarm_${id}_year", -1)
                        val month = prefs.getInt("alarm_${id}_month", -1)
                        val day = prefs.getInt("alarm_${id}_day", -1)
                        val hour = prefs.getInt("alarm_${id}_hour", -1)
                        val min = prefs.getInt("alarm_${id}_minute", -1)
                        val sound = prefs.getString("alarm_${id}_sound", "default")
                        val payload = prefs.getString("alarm_${id}_payload", "none")
                        val title = prefs.getString("alarm_${id}_title", "No Title")
                        
                        sb.append("ID: $id | Time: $hour:$min | Date: $year-$month-$day | Sound: $sound | Payload: $payload | Title: $title\n")
                    }
                    sb.append("-----------------------\n")
                    NativeLogger.log(context, sb.toString())
                    result.success(sb.toString())
                }
                "updatePrayerNotification" -> {
                    try {
                        val fajr = call.argument<String>("fajr")
                        
                        val intent = Intent(context, PrayerNotificationService::class.java)
                        
                        if (fajr == null) {
                            // Simple sync call
                            intent.action = "SYNC"
                        } else {
                            // Full update call
                            val dhuhr = call.argument<String>("dhuhr")
                            val asr = call.argument<String>("asr")
                            val maghrib = call.argument<String>("maghrib")
                            val isha = call.argument<String>("isha")
                            val nextName = call.argument<String>("nextName")
                            val countdown = call.argument<String>("countdown")
                            val hijri = call.argument<String>("hijri")
                            val prayerIndex = call.argument<Int>("prayerIndex") ?: -1
                            val nextPrayerEpoch = when (val epochArg = call.argument<Any>("nextPrayerEpoch")) {
                                is Long -> epochArg
                                is Int -> epochArg.toLong()
                                is String -> epochArg.toLongOrNull() ?: 0L
                                else -> 0L
                            }
                            val isCountUp = call.argument<Boolean>("isCountUp") ?: false

                            // Persist to SharedPreferences
                            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                            prefs.edit().apply {
                                putString("fajr", fajr)
                                putString("dhuhr", dhuhr)
                                putString("asr", asr)
                                putString("maghrib", maghrib)
                                putString("isha", isha)
                                putString("nextName", nextName)
                                putString("countdown", countdown)
                                putString("hijri", hijri)
                                putInt("prayerIndex", prayerIndex)
                                putLong("next_prayer_time_epoch", nextPrayerEpoch)
                                putBoolean("is_count_up", isCountUp)
                                apply()
                            }

                            intent.action = "UPDATE_PRAYER_NOTIFICATION"
                            intent.putExtra("fajr", fajr)
                            intent.putExtra("dhuhr", dhuhr)
                            intent.putExtra("asr", asr)
                            intent.putExtra("maghrib", maghrib)
                            intent.putExtra("isha", isha)
                            intent.putExtra("nextName", nextName)
                            intent.putExtra("countdown", countdown)
                            intent.putExtra("hijri", hijri)
                            intent.putExtra("prayerIndex", prayerIndex)
                            intent.putExtra("next_prayer_time_epoch", nextPrayerEpoch)
                            intent.putExtra("isCountUp", isCountUp)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            androidx.core.content.ContextCompat.startForegroundService(context, intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                "stopPrayerNotification" -> {
                    val intent = Intent(context, PrayerNotificationService::class.java).apply {
                        action = "STOP_PRAYER_NOTIFICATION"
                    }
                    androidx.core.content.ContextCompat.startForegroundService(context, intent)
                    result.success(null)
                }
                "getLaunchPayload" -> {
                    result.success(MainActivity.getAndClearLaunchPayload())
                }
                "isBatteryOptimizationIgnored" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(context.packageName))
                    } else {
                        result.success(true)
                    }
                }
                "checkBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                            val intent = Intent().apply {
                                action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                data = android.net.Uri.parse("package:${context.packageName}")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                        }
                    }
                    result.success(null)
                }
                "vibrate" -> {
                    val duration = call.argument<Int>("duration")?.toLong() ?: 100L
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createOneShot(duration, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(duration)
                    }
                    result.success(null)
                }
                "simulateTestAdhan" -> {
                    val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val testIntent = Intent(context, AlarmReceiver::class.java).apply {
                        action = "SIMULATE_ADHAN"
                        putExtra("sound_name", "nafis")
                        putExtra("title", "أذان تجريبي")
                        putExtra("body", "هذا أذان تجريبي لاختبار النظام")
                        putExtra("payload", "home")
                    }
                    val pi = PendingIntent.getBroadcast(context, 99999, testIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                    val triggerTime = System.currentTimeMillis() + 60000L // 60 seconds
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pi)
                    } else {
                        am.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pi)
                    }
                    result.success("تمت جدولة أذان تجريبي بعد 60 ثانية")
                }
                "generateThirtyDayCache" -> {
                    // Run in background to not block UI
                    Thread {
                        NativePrayerManager.generateThirtyDayCache(context)
                    }.start()
                    result.success("Cache generation started")
                }
                "startNativePrayerEngine" -> {
                    // Delegate prayer alarm scheduling entirely to native; safe to call on every app open
                    Thread {
                        try {
                            NativePrayerManager.generateThirtyDayCache(context)
                            NativePrayerScheduler.scheduleToday(context)
                        } catch (e: Exception) { e.printStackTrace() }
                    }.start()
                    result.success("Native prayer engine started")
                }
                "checkOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        android.provider.Settings.canDrawOverlays(context)
                    } else { true }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(
                        android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:${context.packageName}")
                    ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
                    context.startActivity(intent)
                    result.success(null)
                }
                "setPrayerFocusEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        .edit().putBoolean("flutter.prayer_focus_enabled", enabled).apply()
                    result.success(null)
                }
                "startScreenUnlockService" -> {
                    // Save salawat unlock settings to FlutterSharedPreferences so
                    // ScreenUnlockService can read them without a running Flutter engine.
                    val mode   = call.argument<String>("mode")   ?: "saly_3ala_mo7amad"
                    val volume = call.argument<Double>("volume") ?: 1.0
                    val prefs  = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("flutter.salah_unlock_mode",   mode)
                        .putFloat("flutter.salah_unlock_volume",  volume.toFloat())
                        .apply()

                    val intent = Intent(context, ScreenUnlockService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(null)
                }
                "stopScreenUnlockService" -> {
                    ScreenUnlockService.stop(context)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
