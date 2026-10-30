package app.ibad_al_rahmann

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class PrayerWidgetScheduleTest {
    private val base = 1_800_000_000_000L
    private val oneHour = 60L * 60L * 1000L
    private val day = 24L * oneHour
    private val todayPrayers = longArrayOf(
        base + 4 * oneHour + 30 * 60_000L,
        base + 9 * oneHour,
        base + 12 * oneHour,
        base + 17 * oneHour,
        base + 19 * oneHour,
    )
    private val tomorrowFajr = base + day + 4 * oneHour + 42 * 60_000L

    @Test
    fun afterIshaBeforeMidnightTargetsTomorrowFajrNotTodayFajr() {
        val now = base + 22 * oneHour

        val target = PrayerWidgetSchedule.nextUpcomingPrayer(
            nowMillis = now,
            prayerEpochs = todayPrayers,
            nextFajrEpochMillis = tomorrowFajr,
        )

        assertEquals(0, target?.index)
        assertEquals("الفجر", target?.name)
        assertEquals(tomorrowFajr, target?.epochMillis)
        assertTrue(target!!.epochMillis > now)
    }

    @Test
    fun beforeMidnightAfterIshaDoesNotRollPrayerEpochsByAWholeDay() {
        val now = base + 23 * oneHour + 50 * 60_000L

        val target = PrayerWidgetSchedule.nextUpcomingPrayer(
            nowMillis = now,
            prayerEpochs = todayPrayers,
            nextFajrEpochMillis = tomorrowFajr,
        )

        assertEquals(tomorrowFajr, target?.epochMillis)
    }

    @Test
    fun afterMidnightBeforeFajrTargetsTodaysFajr() {
        val now = base + 2 * oneHour

        val target = PrayerWidgetSchedule.nextUpcomingPrayer(
            nowMillis = now,
            prayerEpochs = todayPrayers,
            nextFajrEpochMillis = tomorrowFajr,
        )

        assertEquals(0, target?.index)
        assertEquals(todayPrayers[0], target?.epochMillis)
    }

    @Test
    fun missingNextFajrUsesAFutureFallbackInsteadOfReturningPastFajr() {
        val now = base + 22 * oneHour

        val target = PrayerWidgetSchedule.nextUpcomingPrayer(
            nowMillis = now,
            prayerEpochs = todayPrayers,
            nextFajrEpochMillis = 0L,
        )

        val expected = Calendar.getInstance().apply {
            timeInMillis = todayPrayers[0]
            add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
        assertEquals(expected, target?.epochMillis)
        assertTrue(target!!.epochMillis > now)
    }

    @Test
    fun fallbackPreservesCivilFajrAcrossDaylightSavingChange() {
        val originalZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
            val todayFajr = Calendar.getInstance().apply {
                clear()
                set(2026, Calendar.MARCH, 7, 4, 30, 0)
            }.timeInMillis
            val isha = Calendar.getInstance().apply {
                clear()
                set(2026, Calendar.MARCH, 7, 19, 0, 0)
            }.timeInMillis
            val now = Calendar.getInstance().apply {
                clear()
                set(2026, Calendar.MARCH, 7, 22, 0, 0)
            }.timeInMillis
            val expectedTomorrowFajr = Calendar.getInstance().apply {
                timeInMillis = todayFajr
                add(Calendar.DAY_OF_YEAR, 1)
            }.timeInMillis

            val target = PrayerWidgetSchedule.nextFajrForNight(
                nowMillis = now,
                fajrEpochMillis = todayFajr,
                ishaEpochMillis = isha,
                nextFajrEpochMillis = 0L,
            )

            assertEquals(expectedTomorrowFajr, target)
            assertEquals(23 * oneHour, target - todayFajr)
        } finally {
            TimeZone.setDefault(originalZone)
        }
    }
}
