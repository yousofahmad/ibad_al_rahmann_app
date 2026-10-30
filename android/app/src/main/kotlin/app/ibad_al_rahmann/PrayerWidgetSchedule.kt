package app.ibad_al_rahmann

import java.util.Calendar

/** Pure time-selection helpers shared by the native prayer widgets. */
internal object PrayerWidgetSchedule {
    private val prayerNames = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")

    internal data class PrayerTarget(
        val index: Int,
        val name: String,
        val epochMillis: Long,
    )

    /**
     * Returns the next prayer strictly after [nowMillis]. When today's Isha has
     * passed, uses the independently calculated next-day Fajr epoch instead of
     * assuming that a civil day is exactly 24 hours long.
     */
    fun nextUpcomingPrayer(
        nowMillis: Long,
        prayerEpochs: LongArray,
        nextFajrEpochMillis: Long,
    ): PrayerTarget? {
        if (prayerEpochs.size != prayerNames.size || prayerEpochs.any { it <= 0L }) {
            return null
        }

        for (index in prayerEpochs.indices) {
            if (nowMillis < prayerEpochs[index]) {
                return PrayerTarget(index, prayerNames[index], prayerEpochs[index])
            }
        }

        return PrayerTarget(
            index = 0,
            name = prayerNames[0],
            epochMillis = nextFajrForNight(
                nowMillis = nowMillis,
                fajrEpochMillis = prayerEpochs[0],
                ishaEpochMillis = prayerEpochs[4],
                nextFajrEpochMillis = nextFajrEpochMillis,
            ),
        )
    }

    /** Resolve a future Fajr for the night beginning with today's Isha. */
    fun nextFajrForNight(
        nowMillis: Long,
        fajrEpochMillis: Long,
        ishaEpochMillis: Long,
        nextFajrEpochMillis: Long,
    ): Long {
        if (nextFajrEpochMillis > ishaEpochMillis && nextFajrEpochMillis > nowMillis) {
            return nextFajrEpochMillis
        }

        // Defensive fallback for older/corrupt widget data. Add a civil day so
        // a daylight-saving transition does not shift Fajr by an hour.
        var fallback = addCivilDays(fajrEpochMillis, 1)
        while (fallback <= nowMillis) {
            fallback = addCivilDays(fallback, 1)
        }
        return fallback
    }

    private fun addCivilDays(epochMillis: Long, days: Int): Long =
        Calendar.getInstance().apply {
            timeInMillis = epochMillis
            add(Calendar.DAY_OF_YEAR, days)
        }.timeInMillis
}
