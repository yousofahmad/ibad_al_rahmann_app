package app.ibad_al_rahmann

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RuqyahAlarmFallbackTest {
    @Test
    fun morningAndEveningRuqyahAlarmsBothHaveDeliverableFallbackContent() {
        val morning = RuqyahAlarmFallback.forAlarmId(RuqyahAlarmFallback.MORNING_ALARM_ID)
        val evening = RuqyahAlarmFallback.forAlarmId(RuqyahAlarmFallback.EVENING_ALARM_ID)

        assertNotNull(morning)
        assertNotNull(evening)
        assertEquals("الرقية الشرعية", morning!!.title)
        assertEquals("الرقية الشرعية", evening!!.title)
        assertTrue(morning.body.isNotBlank())
        assertTrue(evening.body.isNotBlank())
    }

    @Test
    fun unrelatedAlarmIdsDoNotReceiveRuqyahFallbackContent() {
        assertNull(RuqyahAlarmFallback.forAlarmId(1))
        assertNull(RuqyahAlarmFallback.forAlarmId(3))
    }

    @Test
    fun disabledRuqyahSuppressesBothMorningAndEveningAlarmIds() {
        assertTrue(
            RuqyahAlarmFallback.shouldSuppressWhenDisabled(
                RuqyahAlarmFallback.MORNING_ALARM_ID,
                ruqyahEnabled = false,
            ),
        )
        assertTrue(
            RuqyahAlarmFallback.shouldSuppressWhenDisabled(
                RuqyahAlarmFallback.EVENING_ALARM_ID,
                ruqyahEnabled = false,
            ),
        )
        assertFalse(
            RuqyahAlarmFallback.shouldSuppressWhenDisabled(
                RuqyahAlarmFallback.MORNING_ALARM_ID,
                ruqyahEnabled = true,
            ),
        )
        assertFalse(
            RuqyahAlarmFallback.shouldSuppressWhenDisabled(
                1,
                ruqyahEnabled = false,
            ),
        )
    }
}
