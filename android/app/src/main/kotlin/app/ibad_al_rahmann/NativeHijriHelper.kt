package app.ibad_al_rahmann

import android.content.Context
import java.time.LocalDate
import java.time.chrono.HijrahDate
import java.time.temporal.ChronoField

object NativeHijriHelper {
    fun updateNativeHijriDate(context: Context) {
        try {
            val widgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val hijriStr = NativePrayerManager.getHijriDate(context)
            widgetPrefs.edit().putString("hijri", hijriStr).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
