package app.ibad_al_rahmann

import android.content.Context

object NativeHijriHelper {
    fun updateNativeHijriDate(context: Context) {
        try {
            val widgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val hijriStr = NativePrayerManager.getHijriDate(context)
            if (hijriStr.isNotEmpty()) {
                widgetPrefs.edit().putString("hijri", hijriStr).apply()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
