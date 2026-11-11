package app.ibad_al_rahmann

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LegacyKahfAlarmIdsTest {
    @Test
    fun legacyCleanupIdsDoNotOverlapCurrentDartKahfWindow() {
        val currentDartKahfIds = (2850..2852).toSet() + (2860..2862).toSet()

        assertEquals(
            setOf(2350, 2351, 2352, 2360, 2361, 2362),
            LegacyKahfAlarmIds.all,
        )
        assertTrue(LegacyKahfAlarmIds.all.intersect(currentDartKahfIds).isEmpty())
    }
}
