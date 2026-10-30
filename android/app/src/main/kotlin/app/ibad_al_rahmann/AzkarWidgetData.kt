package app.ibad_al_rahmann

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Pure time and cycle-date helpers shared by the morning/evening azkar widget. */
internal object AzkarWidgetData {
    enum class Session { MORNING, EVENING }

    /**
     * Morning azkar is active after Fajr until Asr. Evening azkar is active
     * from Asr through the night until the following Fajr. If prayer times have
     * not been saved yet, use a local-clock fallback rather than showing nothing.
     */
    fun sessionFor(
        nowMillis: Long,
        fajrEpochMillis: Long,
        asrEpochMillis: Long,
        timeZone: TimeZone = TimeZone.getDefault(),
    ): Session {
        if (
            fajrEpochMillis > 0L &&
            asrEpochMillis > fajrEpochMillis &&
            isSameLocalDay(nowMillis, fajrEpochMillis, timeZone) &&
            isSameLocalDay(nowMillis, asrEpochMillis, timeZone)
        ) {
            return if (nowMillis < fajrEpochMillis || nowMillis >= asrEpochMillis) {
                Session.EVENING
            } else {
                Session.MORNING
            }
        }

        val hour = Calendar.getInstance(timeZone).apply {
            timeInMillis = nowMillis
        }.get(Calendar.HOUR_OF_DAY)
        return if (hour in 4..14) Session.MORNING else Session.EVENING
    }

    private fun isSameLocalDay(firstMillis: Long, secondMillis: Long, timeZone: TimeZone): Boolean {
        val first = Calendar.getInstance(timeZone).apply { timeInMillis = firstMillis }
        val second = Calendar.getInstance(timeZone).apply { timeInMillis = secondMillis }
        return first.get(Calendar.YEAR) == second.get(Calendar.YEAR) &&
            first.get(Calendar.DAY_OF_YEAR) == second.get(Calendar.DAY_OF_YEAR)
    }

    /** Mirrors IslamicDay.todayKey(): the logical date advances after Maghrib. */
    fun logicalDateKey(
        nowMillis: Long,
        maghribEpochMillis: Long,
        timeZone: TimeZone = TimeZone.getDefault(),
    ): String {
        val calendar = Calendar.getInstance(timeZone).apply { timeInMillis = nowMillis }
        val currentDayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        val currentYear = calendar.get(Calendar.YEAR)
        val hasSameDayMaghrib = maghribEpochMillis > 0L && Calendar.getInstance(timeZone).run {
            timeInMillis = maghribEpochMillis
            get(Calendar.YEAR) == currentYear && get(Calendar.DAY_OF_YEAR) == currentDayOfYear
        }
        val afterMaghrib = if (hasSameDayMaghrib) {
            nowMillis >= maghribEpochMillis
        } else {
            calendar.get(Calendar.HOUR_OF_DAY) >= 18
        }
        if (afterMaghrib) calendar.add(Calendar.DAY_OF_YEAR, 1)

        return SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            this.timeZone = timeZone
        }.format(Date(calendar.timeInMillis))
    }
}
