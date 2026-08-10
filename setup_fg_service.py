# -*- coding: utf-8 -*-
import os

service_code = '''package app.ibad_al_rahmann

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class ScreenUnlockForegroundService : Service() {

    private var receiver: ScreenUnlockReceiver? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Use foregroundServiceType specialUse for Android 14+
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(9999, createNotification(), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(9999, createNotification())
        }
        
        receiver = ScreenUnlockReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        receiver?.let { unregisterReceiver(it) }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "screen_unlock_channel",
                "تنبيه الصلاة على النبي (الخلفية)",
                NotificationManager.IMPORTANCE_MIN
            )
            channel.description = "تُبقي خدمة التنبيه عند قفل الشاشة فعالة"
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "screen_unlock_channel")
            .setContentTitle("تنبيه الصلاة على النبي")
            .setContentText("التنبيه يعمل في الخلفية")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()
    }
}
'''
with open(r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\ScreenUnlockForegroundService.kt', 'w', encoding='utf-8') as f:
    f.write(service_code)

print("Created ScreenUnlockForegroundService")