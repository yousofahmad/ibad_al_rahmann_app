package app.ibad_al_rahmann

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WirdWidgetDataTest {
    @Test
    fun selectsFirstUnreadWirdFromPersistedIndex() {
        assertEquals(2, WirdWidgetData.currentTargetIndex(1, listOf(true, true, false, false)))
        assertEquals(3, WirdWidgetData.currentTargetIndex(3, listOf(true, true, true, false)))
    }

    @Test
    fun returnsNullWhenAllWirdsAreCompleteOrIndexIsPastEnd() {
        assertNull(WirdWidgetData.currentTargetIndex(0, listOf(true, true)))
        assertNull(WirdWidgetData.currentTargetIndex(4, listOf(false, false)))
    }

    @Test
    fun negativeIndexStartsAtTheFirstWird() {
        assertEquals(0, WirdWidgetData.currentTargetIndex(-1, listOf(false, true)))
    }
}
