package app.ibad_al_rahmann

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerFocusOverlayDiagnosticsTest {
    @Test
    fun addViewEventDoesNotClaimTheOverlayWasActuallySeen() {
        val message = PrayerFocusOverlayDiagnostics.windowManagerAddViewReturned(
            overlayKind = "prayer_focus",
            prayerName = "الفجر",
            alarmId = 100,
            isPreview = false,
            screenInteractive = false,
            keyguardLocked = true,
        )

        assertTrue(message.contains("event=window_manager_add_view_returned"))
        assertTrue(message.contains("screenInteractive=false"))
        assertTrue(message.contains("keyguardLocked=true"))
        assertFalse(message.contains("shown"))
    }

    @Test
    fun skippedEventIncludesTheReasonAndPrayerContext() {
        val message = PrayerFocusOverlayDiagnostics.showSkipped(
            overlayKind = "prayer_focus",
            reason = "overlay_permission_missing",
            prayerName = "الفجر",
            alarmId = 100,
            isPreview = false,
        )

        assertTrue(message.contains("event=show_skipped"))
        assertTrue(message.contains("reason=overlay_permission_missing"))
        assertTrue(message.contains("prayer=الفجر id=100"))
    }
}
