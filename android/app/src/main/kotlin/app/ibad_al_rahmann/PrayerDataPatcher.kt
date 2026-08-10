package app.ibad_al_rahmann

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PrayerDataPatcher {
    fun getSafeLong(prefs: SharedPreferences, key: String, def: Long): Long {
        val v = prefs.all[key] ?: return def
        return when (v) {
            is Long -> v
            is Int -> v.toLong()
            is Float -> v.toLong()
            is Double -> v.toLong()
            is String -> v.toLongOrNull() ?: def
            else -> def
        }
    }

    fun patchTodayEpochsFrom30d(context: Context) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val edit = prefs.edit()

        // 1. PRIMARY: NATIVE CALCULATION
        try {
            val todayTimes = NativePrayerManager.calculatePrayerTimes(context, Date())
            if (todayTimes != null) {
                edit.putLong("fajr_epoch", todayTimes.fajr.time)
                edit.putLong("dhuhr_epoch", todayTimes.dhuhr.time)
                edit.putLong("asr_epoch", todayTimes.asr.time)
                edit.putLong("maghrib_epoch", todayTimes.maghrib.time)
                edit.putLong("isha_epoch", todayTimes.isha.time)
                edit.putLong("sunrise_epoch", todayTimes.sunrise.time)
                
                val tomorrow = Date(System.currentTimeMillis() + 86400000L)
                val tomorrowTimes = NativePrayerManager.calculatePrayerTimes(context, tomorrow)
                edit.putLong("next_fajr_epoch", tomorrowTimes?.fajr?.time ?: (todayTimes.isha.time + 86400000L))
                
                // Format strings for display
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val is24H = flutterPrefs.getBoolean("flutter.is_24_hour", false)
                val timeFmt = SimpleDateFormat(if (is24H) "HH:mm" else "hh:mm a", Locale(if (is24H) "en" else "ar"))
                
                edit.putString("fajr", timeFmt.format(todayTimes.fajr))
                edit.putString("dhuhr", timeFmt.format(todayTimes.dhuhr))
                edit.putString("asr", timeFmt.format(todayTimes.asr))
                edit.putString("maghrib", timeFmt.format(todayTimes.maghrib))
                edit.putString("isha", timeFmt.format(todayTimes.isha))
                edit.putString("sunrise", timeFmt.format(todayTimes.sunrise))

                edit.putBoolean("is_data_ready", true)
                edit.apply()
                return
            }
        } catch (e: Exception) { e.printStackTrace() }

        // 2. FALLBACK: HomeWidget pushed data (Flutter writes here via HomeWidget.saveWidgetData)
        try {
            val hwPrefs = context.getSharedPreferences(
                "HomeWidgetData-app.ibad_al_rahmann", Context.MODE_PRIVATE
            )
            val hwFajr = getSafeLong(hwPrefs, "fajr_epoch", 0L)
            
            // CRITICAL FIX: Only use Flutter's cached widget data if it belongs to TODAY or later!
            // If hwFajr is less than today's start of day, it's stuck/old data.
            val startOfToday = System.currentTimeMillis() - 86400000L // Roughly 24h ago buffer
            
            if (hwFajr > startOfToday) {
                edit.putLong("fajr_epoch",      hwFajr)
                edit.putLong("dhuhr_epoch",     getSafeLong(hwPrefs, "dhuhr_epoch",     0L))
                edit.putLong("asr_epoch",       getSafeLong(hwPrefs, "asr_epoch",       0L))
                edit.putLong("maghrib_epoch",   getSafeLong(hwPrefs, "maghrib_epoch",   0L))
                edit.putLong("isha_epoch",      getSafeLong(hwPrefs, "isha_epoch",      0L))
                edit.putLong("sunrise_epoch",   getSafeLong(hwPrefs, "sunrise_epoch",   0L))
                edit.putLong("next_fajr_epoch", getSafeLong(hwPrefs, "next_fajr_epoch", 0L))
                edit.putBoolean("is_data_ready", true)
                edit.apply()
                return
            }
        } catch (e: Exception) { e.printStackTrace() }

        // 3. FALLBACK: JSON CACHE (Only if native and HomeWidget data both fail)
        val thirtyStr = prefs.getString("prayer_times_30d", null) ?: return
        try {
            val json = JSONObject(thirtyStr)
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val dateKey = sdf.format(Date())
            val tomorrowKey = sdf.format(Date(System.currentTimeMillis() + 86400000L))
            
            val dayObj = json.optJSONObject(dateKey)
            val tomorrowObj = json.optJSONObject(tomorrowKey)
            
            if (dayObj != null) {
                edit.putLong("fajr_epoch", dayObj.optLong("f", 0L))
                edit.putLong("dhuhr_epoch", dayObj.optLong("d", 0L))
                edit.putLong("asr_epoch", dayObj.optLong("a", 0L))
                edit.putLong("maghrib_epoch", dayObj.optLong("m", 0L))
                edit.putLong("isha_epoch", dayObj.optLong("i", 0L))
                edit.putLong("sunrise_epoch", dayObj.optLong("s", 0L))
                
                if (tomorrowObj != null) {
                    edit.putLong("next_fajr_epoch", tomorrowObj.optLong("f", 0L))
                }
                
                edit.putString("fajr", dayObj.optString("f_str", "--:--"))
                edit.putString("dhuhr", dayObj.optString("d_str", "--:--"))
                edit.putString("asr", dayObj.optString("a_str", "--:--"))
                edit.putString("maghrib", dayObj.optString("m_str", "--:--"))
                edit.putString("isha", dayObj.optString("i_str", "--:--"))
                edit.putString("sunrise", dayObj.optString("s_str", "--:--"))
                
                edit.putBoolean("is_data_ready", true)
                edit.apply()
            }
        } catch (e: Exception) { e.printStackTrace() }
    }
}
