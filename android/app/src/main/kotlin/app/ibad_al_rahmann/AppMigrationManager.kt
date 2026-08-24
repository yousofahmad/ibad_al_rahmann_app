package app.ibad_al_rahmann

import android.app.NotificationManager
import android.content.Context
import android.os.Build

object AppMigrationManager {
    private const val CURRENT_NATIVE_VERSION = 9
    private const val KEY_MIGRATION = "native_migration_version"

    fun checkAndPerformMigration(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lastVersion = prefs.getInt(KEY_MIGRATION, 0)

        if (lastVersion < CURRENT_NATIVE_VERSION) {
            NativeLogger.log(context, "🚀 AppMigrationManager: Migrating native state to v$CURRENT_NATIVE_VERSION...")

            // 1. Delete all old obsolete notification channels
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val oldChannels = listOf(
                    "persistent_prayer_v1", "persistent_prayer_v2", "persistent_prayer_v3",
                    "persistent_prayer_v4", "persistent_prayer_v5", "persistent_prayer_v6",
                    "persistent_prayer_v7", "persistent_prayer_v8", "persistent_prayer_v9",
                    "persistent_prayer_v10", "persistent_prayer_v11", "persistent_prayer_v12",
                    "persistent_prayer_v13", "persistent_prayer_v14", "persistent_prayer_v15",
                    "persistent_prayer_v16", "persistent_prayer_v17", "persistent_prayer_v18",
                    "persistent_prayer_v19", "persistent_prayer_v20", "persistent_prayer_v21",
                    "persistent_prayer_v22", "prayer_sound_channel_v1", "prayer_sound_channel_v2",
                    "prayer_sound_channel_v10", "prayer_sound_channel_v11", "prayer_sound_channel_v12",
                    "adhan_channel", "azkar_channel", "general_channel"
                )
                for (ch in oldChannels) {
                    try { nm.deleteNotificationChannel(ch) } catch (_: Exception) {}
                }
            }

            // 2. Clear old widget preferences 30d cache so it calculates cleanly
            val groupPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            groupPrefs.edit().remove("prayer_times_30d").apply()

            // 3. Regenerate 30-day cache immediately
            try {
                NativePrayerManager.generateThirtyDayCache(context)
            } catch (e: Exception) {
                NativeLogger.log(context, "AppMigrationManager: generateThirtyDayCache error: ${e.message}")
            }

            // 4. Mark migration complete
            prefs.edit().putInt(KEY_MIGRATION, CURRENT_NATIVE_VERSION).apply()
            NativeLogger.log(context, "✅ AppMigrationManager: Native migration to v$CURRENT_NATIVE_VERSION complete.")
        }
    }
}
