package app.ibad_al_rahmann

import android.content.Context
import com.batoulapps.adhan.*
import com.batoulapps.adhan.data.DateComponents
import java.util.*

object NativePrayerManager {
    fun calculatePrayerTimes(context: Context, date: Date = Date()): PrayerTimes? {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Use double/long safe reading as Flutter saves as Long sometimes, or as a base64-prefixed String
        fun getSafeDouble(key: String, def: Double): Double {
            val v = prefs.all[key]
            return when (v) {
                is Double -> v
                is Float -> v.toDouble()
                is Long -> Double.fromBits(v)
                is Int -> v.toDouble()
                is String -> {
                    val doublePrefix = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"
                    if (v.startsWith(doublePrefix)) {
                        v.removePrefix(doublePrefix).toDoubleOrNull() ?: def
                    } else {
                        v.toDoubleOrNull() ?: def
                    }
                }
                else -> def
            }
        }

        var lat = getSafeDouble("flutter.latitude", 0.0)
        if (lat == 0.0) lat = getSafeDouble("flutter.last_lat", 0.0)
        
        var lng = getSafeDouble("flutter.longitude", 0.0)
        if (lng == 0.0) lng = getSafeDouble("flutter.last_lng", 0.0)

        
        // Strictly use saved coordinates, never attempt to 'search' for location here.
        if (lat == 0.0 && lng == 0.0) return null

        val methodStr = prefs.getString("flutter.calculation_method", "EGYPTIAN") ?: "EGYPTIAN"
        val params = when (methodStr) {
            "KARACHI" -> CalculationMethod.KARACHI.parameters
            "UMM_AL_QURA" -> CalculationMethod.UMM_AL_QURA.parameters
            "MUSLIM_WORLD_LEAGUE" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
            "EGYPTIAN" -> CalculationMethod.EGYPTIAN.parameters
            "NORTH_AMERICA" -> CalculationMethod.NORTH_AMERICA.parameters
            "KUWAIT" -> CalculationMethod.KUWAIT.parameters
            "QATAR" -> CalculationMethod.QATAR.parameters
            "SINGAPORE" -> CalculationMethod.SINGAPORE.parameters
            "DUBAI" -> CalculationMethod.DUBAI.parameters
            else -> CalculationMethod.EGYPTIAN.parameters
        }

        val madhabStr = prefs.getString("flutter.madhab", "SHAFI") ?: "SHAFI"
        params.madhab = if (madhabStr == "HANAFI") Madhab.HANAFI else Madhab.SHAFI

        fun getSafeInt(key: String, default: Int): Int {
            return when (val v = prefs.all[key]) {
                is Long   -> v.toInt()
                is Int    -> v
                is Float  -> v.toInt()
                is String -> v.toIntOrNull() ?: default
                else      -> default
            }
        }

        params.adjustments.fajr = getSafeInt("flutter.offset_Fajr", 0)
        params.adjustments.sunrise = getSafeInt("flutter.offset_Sunrise", 0)
        params.adjustments.dhuhr = getSafeInt("flutter.offset_Dhuhr", 0)
        params.adjustments.asr = getSafeInt("flutter.offset_Asr", 0)
        params.adjustments.maghrib = getSafeInt("flutter.offset_Maghrib", 0)
        params.adjustments.isha = getSafeInt("flutter.offset_Isha", 0)

        val coordinates = Coordinates(lat, lng)
        val components = DateComponents.from(date)
        
        return PrayerTimes(coordinates, components, params)
    }

    fun getHijriDate(context: Context, date: Date = Date()): String {
        return HijriCalendarHelper.getArabicDate(context, date)
    }

    fun generateThirtyDayCache(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val lat = prefs.all["flutter.latitude"]?.toString()?.toDoubleOrNull() ?: 0.0
        val lng = prefs.all["flutter.longitude"]?.toString()?.toDoubleOrNull() ?: 0.0
        
        if (lat == 0.0 && lng == 0.0) return

        val jsonResult = org.json.JSONObject()
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        val timeFmt = java.text.SimpleDateFormat("hh:mm a", java.util.Locale("ar"))
        
        val calendar = java.util.Calendar.getInstance()
        
        // Calculate for 30 days starting from today
        for (i in 0..30) {
            val date = calendar.time
            val prayerTimes = calculatePrayerTimes(context, date)
            
            if (prayerTimes != null) {
                val dayObj = org.json.JSONObject()
                dayObj.put("f", prayerTimes.fajr.time)
                dayObj.put("s", prayerTimes.sunrise.time)
                dayObj.put("d", prayerTimes.dhuhr.time)
                dayObj.put("a", prayerTimes.asr.time)
                dayObj.put("m", prayerTimes.maghrib.time)
                dayObj.put("i", prayerTimes.isha.time)
                
                dayObj.put("f_str", timeFmt.format(prayerTimes.fajr))
                dayObj.put("s_str", timeFmt.format(prayerTimes.sunrise))
                dayObj.put("d_str", timeFmt.format(prayerTimes.dhuhr))
                dayObj.put("a_str", timeFmt.format(prayerTimes.asr))
                dayObj.put("m_str", timeFmt.format(prayerTimes.maghrib))
                dayObj.put("i_str", timeFmt.format(prayerTimes.isha))
                
                jsonResult.put(sdf.format(date), dayObj)
            }
            calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        
        val groupPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        groupPrefs.edit().putString("prayer_times_30d", jsonResult.toString()).apply()
        
        // Immediately patch today's data so widgets update right away
        PrayerDataPatcher.patchTodayEpochsFrom30d(context)
    }
}

object HijriCalendarHelper {
    fun getHijriDateComponents(context: Context, date: Date): Triple<Int, Int, Int> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        fun parseOffset(key: String): Int {
            val raw = prefs.all[key]
            return when (raw) {
                is Long -> raw.toInt()
                is Int -> raw
                is Double -> raw.toInt()
                is String -> raw.toIntOrNull() ?: 0
                else -> 0
            }
        }

        var manualOffset = parseOffset("flutter.hijri_offset_manual")
        val storedMonth = parseOffset("flutter.hijri_offset_month")
        val localDelta = parseOffset("flutter.hijri_local_delta")
        val generalOffset = parseOffset("flutter.hijri_offset")
        
        // Auto-reset manual offset if the month has rolled over
        if (storedMonth > 0 && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            try {
                val tempIcu = android.icu.util.IslamicCalendar()
                tempIcu.calculationType = android.icu.util.IslamicCalendar.CalculationType.ISLAMIC_UMALQURA
                tempIcu.time = date
                val curHMonth = tempIcu.get(android.icu.util.IslamicCalendar.MONTH) + 1
                if (curHMonth != storedMonth) {
                    manualOffset = 0
                }
            } catch (_: Exception) {}
        }

        val totalOffset = if (prefs.contains("flutter.hijri_offset_manual") || prefs.contains("flutter.hijri_local_delta")) {
            manualOffset + localDelta + parseOffset("flutter.global_hijri_offset")
        } else {
            generalOffset
        }
        
        val adjustedCal = Calendar.getInstance()
        adjustedCal.time = date
        adjustedCal.add(Calendar.DAY_OF_YEAR, totalOffset)

        // في الشريعة الإسلامية يبدأ اليوم الجديد مع أذان المغرب (الغروب)
        try {
            val prayerTimes = NativePrayerManager.calculatePrayerTimes(context, date)
            if (prayerTimes != null && date.after(prayerTimes.maghrib)) {
                adjustedCal.add(Calendar.DAY_OF_YEAR, 1)
            }
        } catch (_: Exception) {}

        val adjustedDate = adjustedCal.time

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            try {
                val icuCal = android.icu.util.IslamicCalendar()
                icuCal.calculationType = android.icu.util.IslamicCalendar.CalculationType.ISLAMIC_UMALQURA
                icuCal.time = adjustedDate
                val hDay = icuCal.get(android.icu.util.IslamicCalendar.DAY_OF_MONTH)
                val hMonth = icuCal.get(android.icu.util.IslamicCalendar.MONTH) + 1
                val hYear = icuCal.get(android.icu.util.IslamicCalendar.YEAR)
                if (hDay in 1..30 && hMonth in 1..12 && hYear > 1400) {
                    return Triple(hDay, hMonth, hYear)
                }
            } catch (_: Exception) {}
        }

        val cal = Calendar.getInstance()
        cal.time = adjustedDate
        
        val day = cal.get(Calendar.DAY_OF_MONTH)
        var month = cal.get(Calendar.MONTH) + 1
        var year = cal.get(Calendar.YEAR)

        var m = month
        var y = year
        if (m < 3) {
            y -= 1
            m += 12
        }

        val a = Math.floor(y / 100.0).toInt()
        val b = 2 - a + Math.floor(a / 4.0).toInt()
        
        val jd = Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + day + b - 1524.5

        val z = jd + 0.5
        val cyc = Math.floor((z - 1948439.5) / 10631.0).toInt()
        val rem = z - 1948439.5 - cyc * 10631.0
        
        val j = Math.floor((rem - 0.12) / 354.3666).toInt()
        val res = rem - Math.floor(j * 354.3666 + 0.5)
        
        var hYear = cyc * 30 + j + 1
        var hMonth = Math.floor((res + 28.5001) / 29.5).toInt()
        if (hMonth == 13) hMonth = 12
        
        var hDay = (res - Math.floor(hMonth * 29.5 - 28.999)).toInt()
        if (hDay <= 0) hDay = 1
        if (hDay > 30) hDay = 30

        if (hMonth <= 0) {
            hMonth = 12
            hYear -= 1
            hDay = 30
        }

        return Triple(hDay, hMonth, hYear)
    }

    fun getArabicDate(context: Context, date: Date): String {
        try {
            val (hDay, hMonth, hYear) = getHijriDateComponents(context, date)
            val monthsAr = arrayOf(
                "محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الآخرة",
                "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
            )
            
            val monthName = if (hMonth in 1..12) monthsAr[hMonth - 1] else "شهر"
            
            return toArabicDigits("$hDay $monthName $hYear هـ")
        } catch (e: Exception) {
            return "التاريخ الهجري"
        }
    }

    private fun toArabicDigits(input: String): String {
        val english = arrayOf("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")
        val arabic = arrayOf("٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩")
        var result = input
        for (i in english.indices) result = result.replace(english[i], arabic[i])
        return result
    }
}
