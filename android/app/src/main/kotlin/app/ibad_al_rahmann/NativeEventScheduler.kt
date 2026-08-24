package app.ibad_al_rahmann

import android.app.AlarmManager
import android.content.Context
import java.util.Calendar
import java.util.Date

object NativeEventScheduler {

    // Unique IDs for secondary alarms
    private const val ID_MIDNIGHT = 2000
    private const val ID_FIRST_THIRD = 2001
    private const val ID_LAST_THIRD = 2002
    private const val ID_FASTING = 2003
    private const val ID_ARAFAH_IFTAR = 2004
    private const val ID_ARAFAH_SUHOOR = 2005
    private const val ID_IFTAR = 2006
    private const val ID_SUHOOR = 2007
    private const val ID_MIDNIGHT_REFRESH = 9999

    fun scheduleEvents(context: Context, todayEpochs: LongArray, tomorrowFajrEpoch: Long) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()

        // Schedule an invisible alarm at 00:00:01 to force-refresh Hijri date & Widgets
        val tomorrowCal = Calendar.getInstance()
        tomorrowCal.timeInMillis = now
        tomorrowCal.add(Calendar.DAY_OF_YEAR, 1)
        tomorrowCal.set(Calendar.HOUR_OF_DAY, 0)
        tomorrowCal.set(Calendar.MINUTE, 0)
        tomorrowCal.set(Calendar.SECOND, 1)
        if (tomorrowCal.timeInMillis > now) {
            val intent = android.content.Intent(context, AlarmReceiver::class.java).apply {
                putExtra("payload", "sync_only")
                putExtra("alarm_id", ID_MIDNIGHT_REFRESH)
            }
            val pi = android.app.PendingIntent.getBroadcast(
                context, ID_MIDNIGHT_REFRESH, intent,
                android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(tomorrowCal.timeInMillis, pi), pi)
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, tomorrowCal.timeInMillis, pi)
            }
        }

        val todayFajr = todayEpochs[0]
        val todayMaghrib = todayEpochs[3]
        
        val yesterdayMaghrib = try {
            val yesterdayTimes = NativePrayerManager.calculatePrayerTimes(context, Date(now - 86_400_000L))
            yesterdayTimes?.maghrib?.time ?: (todayMaghrib - 86_400_000L)
        } catch (e: Exception) { todayMaghrib - 86_400_000L }

        // 1. NIGHT THIRDS & MIDNIGHT
        val nightStart: Long
        val nightEnd: Long
        
        if (now < todayFajr) {
            // Between midnight and Fajr -> use current night (started yesterday at Maghrib)
            nightStart = yesterdayMaghrib
            nightEnd = todayFajr
        } else {
            // After Fajr -> use upcoming night (starts today at Maghrib)
            nightStart = todayMaghrib
            nightEnd = tomorrowFajrEpoch
        }

        if (nightEnd > nightStart) {
            val nightLength = nightEnd - nightStart
            val firstThird = nightStart + (nightLength / 3)
            val midnight = nightStart + (nightLength / 2)
            val lastThird = nightStart + (nightLength * 2 / 3)

            // Midnight
            if (midnight > now && prefs.getBoolean("flutter.notif_midnight", false)) {
                NativePrayerScheduler.scheduleSingleAlarm(
                    context, alarmManager, ID_MIDNIGHT, midnight,
                    "منتصف الليل", "بدأ منتصف الليل",
                    "silent_notif", null, "home"
                )
            }
            // First Third
            if (firstThird > now && prefs.getBoolean("flutter.notif_first_third", false)) {
                NativePrayerScheduler.scheduleSingleAlarm(
                    context, alarmManager, ID_FIRST_THIRD, firstThird,
                    "الثلث الأول من الليل", "مضى ثلث الليل الأول",
                    "silent_notif", null, "home"
                )
            }
            // Last Third (Qiyam)
            val qiyamMode = prefs.getString("flutter.adhan_mode_Last_third", null)
                ?: if (prefs.getBoolean("flutter.notif_qiyam", false)) "sound" else "none"
            if (qiyamMode != "none" && lastThird > now) {
                NativePrayerScheduler.scheduleSingleAlarm(
                    context, alarmManager, ID_LAST_THIRD, lastThird,
                    "الثلث الأخير من الليل", "هل من داع فأستجيب له",
                    if (qiyamMode == "silent_notif") "silent_notif" else "night_last",
                    "night_last", "home"
                )
            }
        }

        // 2. FASTING REMINDERS
        scheduleFasting(context, alarmManager, prefs, now, todayEpochs, tomorrowFajrEpoch)
    }

    private fun scheduleFasting(
        context: Context,
        alarmManager: AlarmManager,
        prefs: android.content.SharedPreferences,
        now: Long,
        todayEpochs: LongArray,
        tomorrowFajr: Long
    ) {
        val todayIsha = todayEpochs[4]
        // Fasting reminder time: 1 hour after Isha
        val reminderTime = todayIsha + 3600_000L

        // We are scheduling for TOMORROW's fasting. So we check tomorrow's Hijri date.
        val tomorrowCal = Calendar.getInstance()
        tomorrowCal.timeInMillis = now + 86_400_000L // Roughly tomorrow
        val tomorrowDate = tomorrowCal.time

        val (hDay, hMonth, _) = HijriCalendarHelper.getHijriDateComponents(context, tomorrowDate)
        val dayOfWeek = tomorrowCal.get(Calendar.DAY_OF_WEEK)

        val isRamadan = hMonth == 9
        val isTashreeq = hMonth == 12 && hDay in 11..13
        val isArafah = hMonth == 12 && hDay == 9

        // NOTE: Fasting reminders (Mon/Thu/White Days) are scheduled by Flutter's notification_service.dart
        // via AlarmIds 720-724. Scheduling them here again from Native causes duplicate notifications.
        // NativeEventScheduler only keeps Iftar/Suhoor/Arafah-specific alarms below.

        // 3. IFTAR / SUHOOR
        // Suhoor is before tomorrowFajr. Iftar is tomorrow's Maghrib.
        // We only have today's Maghrib. To get tomorrow's Maghrib, we estimate by adding 24h to today's Maghrib.
        // Or we can just calculate tomorrow's prayer times accurately.
        val tomorrowTimes = NativePrayerManager.calculatePrayerTimes(context, tomorrowDate)
        if (tomorrowTimes != null) {
            val tomorrowMaghrib = tomorrowTimes.maghrib.time

            // If tomorrow is Arafah, and Arafah is enabled, use Arafah specific alarms regardless of year-round settings
            if (isArafah) {
                val arafahIftarMins = getSafeInt(prefs, "flutter.arafah_iftar_mins", 0)
                val arafahSuhoorMins = getSafeInt(prefs, "flutter.arafah_suhoor_mins", 30)
                
                val arafahSuhoorTime = tomorrowFajr - (arafahSuhoorMins * 60_000L)
                val arafahIftarTime = tomorrowMaghrib - (arafahIftarMins * 60_000L)

                if (arafahSuhoorTime > now) {
                    NativePrayerScheduler.scheduleSingleAlarm(
                        context, alarmManager, ID_ARAFAH_SUHOOR, arafahSuhoorTime,
                        "سحور يوم عرفة", "تسحروا فإن في السحور بركة",
                        "time_suhoor", "time_suhoor", "home"
                    )
                }
                if (arafahIftarTime > now) {
                    NativePrayerScheduler.scheduleSingleAlarm(
                        context, alarmManager, ID_ARAFAH_IFTAR, arafahIftarTime,
                        "إفطار يوم عرفة", "ذهب الظمأ وابتلت العروق",
                        "time_iftar", "time_iftar", "home"
                    )
                }
            } else {
                // Regular Iftar / Suhoor
                val isIftarActive = prefs.getBoolean("flutter.iftar_alarm", false)
                val isSuhoorActive = prefs.getBoolean("flutter.suhoor_alarm", false)
                
                // Fasting mode check (Ramadan vs All year vs specific days)
                val iftarMode = prefs.getString("flutter.iftar_mode", "ramadan") ?: "ramadan"
                var iftarValid = false
                if (iftarMode == "ramadan" && isRamadan) iftarValid = true
                if (iftarMode == "all_year") iftarValid = true

                if (isIftarActive && iftarValid) {
                    val mins = getSafeInt(prefs, "flutter.iftar_minutes_before", 30)
                    val iftarTime = tomorrowMaghrib - (mins * 60_000L)
                    if (iftarTime > now) {
                        NativePrayerScheduler.scheduleSingleAlarm(
                            context, alarmManager, ID_IFTAR, iftarTime,
                            "تنبيه الإفطار", "اقترب موعد أذان المغرب",
                            "time_iftar", "time_iftar", "home"
                        )
                    }
                }

                val suhoorMode = prefs.getString("flutter.suhoor_mode", "ramadan") ?: "ramadan"
                var suhoorValid = false
                if (suhoorMode == "ramadan" && isRamadan) suhoorValid = true
                if (suhoorMode == "all_year") suhoorValid = true

                if (isSuhoorActive && suhoorValid) {
                    val mins = getSafeInt(prefs, "flutter.suhoor_minutes_before", 60)
                    val suhoorTime = tomorrowFajr - (mins * 60_000L)
                    if (suhoorTime > now) {
                        NativePrayerScheduler.scheduleSingleAlarm(
                            context, alarmManager, ID_SUHOOR, suhoorTime,
                            "تنبيه السحور", "تسحروا فإن في السحور بركة",
                            "time_suhoor", "time_suhoor", "home"
                        )
                    }
                }
            }
        }
    }

    private fun getSafeInt(prefs: android.content.SharedPreferences, key: String, default: Int): Int {
        return when (val v = prefs.all[key]) {
            is Long   -> v.toInt()
            is Int    -> v
            is Float  -> v.toInt()
            is String -> v.toIntOrNull() ?: default
            else      -> default
        }
    }
}
