package com.example.ibad_al_rahmann

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object BackgroundMethodChannelPlugin {
    private const val CHANNEL = "com.example.ibad_al_rahmann/native_notifications"

    fun registerWith(context: Context) {
        // We defer registering to when the engine actually starts in MainActivity or the AlarmService.
        // It's safer to just handle the static method calls that the background dart code makes to Android.
    }

    fun setupMethodChannel(context: Context, methodChannel: MethodChannel) {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 1
                    val year = call.argument<Int>("year") ?: -1
                    val month = call.argument<Int>("month") ?: -1
                    val day = call.argument<Int>("day") ?: -1
                    val hour = call.argument<Int>("hour") ?: 6
                    val minute = call.argument<Int>("minute") ?: 0
                    val soundName = call.argument<String>("soundName") ?: "default"
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val payload = call.argument<String>("payload")
                    val audioPath = call.argument<String>("audioPath")
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                    
                    MainActivity.scheduleAlarm(context, id, year, month, day, hour, minute, soundName, title, body, payload, false, audioPath, intervalMinutes)
                    result.success("Scheduled")
                }
                "updatePrayerNotification" -> {
                    try {
                        val intent = Intent(context, PrayerNotificationService::class.java).apply {
                            action = "UPDATE_PRAYER_NOTIFICATION"
                            putExtra("fajr", call.argument<String>("fajr"))
                            putExtra("dhuhr", call.argument<String>("dhuhr"))
                            putExtra("asr", call.argument<String>("asr"))
                            putExtra("maghrib", call.argument<String>("maghrib"))
                            putExtra("isha", call.argument<String>("isha"))
                            putExtra("nextName", call.argument<String>("nextName"))
                            putExtra("countdown", call.argument<String>("countdown"))
                            putExtra("hijri", call.argument<String>("hijri"))
                            putExtra("prayerIndex", call.argument<Int>("prayerIndex"))
                            
                            val epochArg = call.argument<Any>("nextPrayerEpoch")
                            val nextPrayerEpoch = when (epochArg) {
                                is Long -> epochArg
                                is Int -> epochArg.toLong()
                                is String -> epochArg.toLongOrNull() ?: 0L
                                else -> 0L
                            }
                            putExtra("nextPrayerEpoch", nextPrayerEpoch)
                            putExtra("isCountUp", call.argument<Boolean>("isCountUp") ?: false)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
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
                    context.startService(intent)
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
                else -> result.notImplemented()
            }
        }
    }
}
