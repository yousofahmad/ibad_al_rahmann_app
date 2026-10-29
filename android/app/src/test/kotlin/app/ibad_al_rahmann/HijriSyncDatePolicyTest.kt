package app.ibad_al_rahmann

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HijriSyncDatePolicyTest {
    @Test
    fun annualEsaRowIsSelectedWhenDarAlIftaIsUnavailable() {
        val annualState = """{"schemaVersion":2,"survey":{"2026-10-29":{"day":18,"month":5,"year":1448}}}"""
        val esa = HijriSyncDatePolicy.parseAnnualEsaDate(
            annualState,
            "2026-10-29",
            notificationSnapshot = null,
            notificationSnapshotSource = null,
        )

        assertEquals(HijriDate(18, 5, 1448), esa)
        assertEquals("survey_authority_annual_calendar", HijriSyncDatePolicy.select(null, esa)?.source)
    }

    @Test
    fun manualConfirmationWinsAndExpiresAfterItsConfirmedDayTwentyNine() {
        val confirmation = """{"anchorDate":"2026-10-28","day":28,"month":5,"year":1448,"confirmedAt":"2026-10-28T12:00:00Z","expiresOn":"2026-10-29"}"""

        val dayTwentyNine = HijriSyncDatePolicy.parseUserConfirmation(confirmation, "2026-10-29")
        val selection = HijriSyncDatePolicy.select(dayTwentyNine, HijriDate(1, 6, 1448))

        assertEquals(HijriDate(29, 5, 1448), selection?.date)
        assertEquals("user_confirmation", selection?.source)
        assertNull(HijriSyncDatePolicy.parseUserConfirmation(confirmation, "2026-10-30"))
    }

    @Test
    fun dailySnapshotFallbackRequiresAnExplicitEsaSourceMarker() {
        assertNull(
            HijriSyncDatePolicy.parseAnnualEsaDate(
                stateJson = null,
                civilDate = "2026-10-29",
                notificationSnapshot = "18,5,1448",
                notificationSnapshotSource = null,
            ),
        )
        assertEquals(
            HijriDate(18, 5, 1448),
            HijriSyncDatePolicy.parseAnnualEsaDate(
                stateJson = null,
                civilDate = "2026-10-29",
                notificationSnapshot = "18,5,1448",
                notificationSnapshotSource = "survey_authority_annual_calendar",
            ),
        )
        assertNull(
            HijriSyncDatePolicy.parseAnnualEsaDate(
                stateJson = null,
                civilDate = "2026-10-29",
                notificationSnapshot = "18,5,1448",
                notificationSnapshotSource = "manual",
            ),
        )
        assertNull(HijriSyncDatePolicy.parseNotificationSnapshot("31,13,1448"))
        assertNull(HijriSyncDatePolicy.select(null, null))
    }

    @Test
    fun nativeNotificationParserRejectsMalformedEgyptianDates() {
        assertEquals(
            Triple(18, 5, 1448),
            HijriCalendarHelper.parseEgyptianHijriSnapshot("18,5,1448"),
        )
        assertNull(HijriCalendarHelper.parseEgyptianHijriSnapshot("31,13,1448"))
        assertNull(HijriCalendarHelper.parseEgyptianHijriSnapshot(null))
    }
}
