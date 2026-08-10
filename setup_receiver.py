# -*- coding: utf-8 -*-
import os

receiver_code = '''package app.ibad_al_rahmann

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.media.AudioAttributes

class ScreenUnlockReceiver : BroadcastReceiver() {
    
    private var mediaPlayer: MediaPlayer? = null
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_USER_PRESENT || intent.action == Intent.ACTION_SCREEN_ON) {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val mode = flutterPrefs.getString("flutter.salah_unlock_mode", "none") ?: "none"
            
            if (mode == "none") return
            
            // Randomize if "both"
            val soundToPlay = if (mode == "both") {
                if (Math.random() > 0.5) "salah_2" else "saly_3ala_mo7amad"
            } else {
                mode
            }
            
            val volumeLevel = flutterPrefs.getDouble("flutter.salah_unlock_volume", 1.0).toFloat()
            
            val resId = context.resources.getIdentifier(soundToPlay, "raw", context.packageName)
            if (resId != 0) {
                try {
                    mediaPlayer?.release()
                    mediaPlayer = MediaPlayer.create(context, resId)
                    mediaPlayer?.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .build()
                    )
                    mediaPlayer?.setVolume(volumeLevel, volumeLevel)
                    mediaPlayer?.setOnCompletionListener {
                        it.release()
                    }
                    mediaPlayer?.start()
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}
'''

with open(r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\ScreenUnlockReceiver.kt', 'w', encoding='utf-8') as f:
    f.write(receiver_code)

# Now update MainApplication.kt
main_app_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\MainApplication.kt'
with open(main_app_path, 'r', encoding='utf-8') as f:
    app_content = f.read()

import_line = "import android.content.IntentFilter\nimport androidx.core.content.ContextCompat"
if "import androidx.core.content.ContextCompat" not in app_content:
    app_content = app_content.replace('import android.os.Build', 'import android.os.Build\n' + import_line)

registration_code = '''
        // Register Screen Unlock Receiver dynamically
        try {
            val receiver = ScreenUnlockReceiver()
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
'''
if "ScreenUnlockReceiver" not in app_content:
    app_content = app_content.replace('PrayerDataPatcher.patchTodayEpochsFrom30d(this)\n            } catch (e: Exception) { e.printStackTrace() }\n        }.start()', 
        'PrayerDataPatcher.patchTodayEpochsFrom30d(this)\n            } catch (e: Exception) { e.printStackTrace() }\n        }.start()\n' + registration_code)

with open(main_app_path, 'w', encoding='utf-8') as f:
    f.write(app_content)

print("Created ScreenUnlockReceiver and updated MainApplication")