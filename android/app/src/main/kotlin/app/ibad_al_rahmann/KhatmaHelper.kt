package app.ibad_al_rahmann

import android.content.Context
import org.json.JSONObject

object KhatmaHelper {

    fun getDelayText(context: Context, khatmaId: String): String {
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val khatmaKeys = flutterPrefs.all.keys.filter { it.startsWith("flutter.khatma_") && it.endsWith("_model") }
            
            var targetJsonStr: String? = null
            for (key in khatmaKeys) {
                val jsonStr = flutterPrefs.getString(key, null) ?: continue
                val json = JSONObject(jsonStr)
                if (json.optString("id") == khatmaId || key == "flutter.khatma_${khatmaId}_model") {
                    targetJsonStr = jsonStr
                    break
                }
            }
            
            if (targetJsonStr == null) return ""
            
            val json = JSONObject(targetJsonStr)
            val startDateStr = json.optString("startDate")
            if (startDateStr.isNullOrEmpty()) return ""
            
            // Format: 2026-08-10T22:45:05.000
            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
            val startDate = sdf.parse(startDateStr) ?: return ""
            
            val startCal = java.util.Calendar.getInstance().apply { time = startDate }
            startCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
            startCal.set(java.util.Calendar.MINUTE, 0)
            startCal.set(java.util.Calendar.SECOND, 0)
            startCal.set(java.util.Calendar.MILLISECOND, 0)
            
            val todayCal = java.util.Calendar.getInstance()
            todayCal.set(java.util.Calendar.HOUR_OF_DAY, 0)
            todayCal.set(java.util.Calendar.MINUTE, 0)
            todayCal.set(java.util.Calendar.SECOND, 0)
            todayCal.set(java.util.Calendar.MILLISECOND, 0)
            
            val diffMs = todayCal.timeInMillis - startCal.timeInMillis
            var daysSinceStart = (diffMs / (1000 * 60 * 60 * 24)).toInt()
            if (daysSinceStart < 0) daysSinceStart = 0
            
            val currentWirdIndex = json.optInt("currentWirdIndex", 0)
            val notificationType = json.optString("notificationType", "daily")
            
            var passedPeriods = daysSinceStart
            if (notificationType == "prayer") {
                // approximate prayer periods
                val startPrayerOffset = json.optInt("startPrayerOffset", 0)
                val calNow = java.util.Calendar.getInstance()
                val hour = calNow.get(java.util.Calendar.HOUR_OF_DAY)
                var currentPrayerIdx = 0
                if (hour >= 20) currentPrayerIdx = 4
                else if (hour >= 18) currentPrayerIdx = 3
                else if (hour >= 15) currentPrayerIdx = 2
                else if (hour >= 12) currentPrayerIdx = 1
                else currentPrayerIdx = 0
                
                passedPeriods = (daysSinceStart * 5) + currentPrayerIdx - startPrayerOffset
            }
            
            if (passedPeriods < 0) passedPeriods = 0
            val delayedWirds = passedPeriods - currentWirdIndex
            
            if (delayedWirds > 0) return "⚠️ أنت متأخر بمقدار $delayedWirds ورد .. "
            if (delayedWirds < 0) return "🌟 أنت متقدم بمقدار ${-delayedWirds} ورد .. "
            return ""
            
        } catch (e: Exception) {
            e.printStackTrace()
            return ""
        }
    }
}
