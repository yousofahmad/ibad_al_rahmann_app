package app.ibad_al_rahmann

import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Test

class AzkarWidgetDataTest {
    private val utc = TimeZone.getTimeZone("UTC")

    @Test
    fun sessionChangesAtFajrAndAsr() {
        val fajr = epoch("2026-10-30 04:30")
        val asr = epoch("2026-10-30 15:30")

        assertEquals(AzkarWidgetData.Session.EVENING, AzkarWidgetData.sessionFor(fajr - 1, fajr, asr, utc))
        assertEquals(AzkarWidgetData.Session.MORNING, AzkarWidgetData.sessionFor(fajr, fajr, asr, utc))
        assertEquals(AzkarWidgetData.Session.MORNING, AzkarWidgetData.sessionFor(epoch("2026-10-30 12:00"), fajr, asr, utc))
        assertEquals(AzkarWidgetData.Session.EVENING, AzkarWidgetData.sessionFor(asr, fajr, asr, utc))
    }

    @Test
    fun missingPrayerTimesUseLocalClockFallback() {
        assertEquals(AzkarWidgetData.Session.EVENING, AzkarWidgetData.sessionFor(epoch("2026-10-30 03:00"), 0L, 0L, utc))
        assertEquals(AzkarWidgetData.Session.MORNING, AzkarWidgetData.sessionFor(epoch("2026-10-30 08:00"), 0L, 0L, utc))
        assertEquals(AzkarWidgetData.Session.EVENING, AzkarWidgetData.sessionFor(epoch("2026-10-30 17:00"), 0L, 0L, utc))
        assertEquals(
            AzkarWidgetData.Session.MORNING,
            AzkarWidgetData.sessionFor(
                epoch("2026-10-30 08:00"),
                epoch("2026-10-29 04:30"),
                epoch("2026-10-29 15:30"),
                utc,
            ),
        )
    }

    @Test
    fun logicalCycleDateAdvancesAfterMaghribOnly() {
        val maghrib = epoch("2026-10-30 17:45")
        assertEquals("2026-10-30", AzkarWidgetData.logicalDateKey(epoch("2026-10-30 17:44"), maghrib, utc))
        assertEquals("2026-10-31", AzkarWidgetData.logicalDateKey(maghrib, maghrib, utc))
        assertEquals("2026-10-30", AzkarWidgetData.logicalDateKey(epoch("2026-10-30 02:00"), 0L, utc))
    }

    private fun epoch(value: String): Long = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).apply {
        timeZone = utc
        isLenient = false
    }.parse(value)!!.time
}
