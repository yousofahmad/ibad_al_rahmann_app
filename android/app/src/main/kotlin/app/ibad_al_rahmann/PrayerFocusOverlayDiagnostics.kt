package app.ibad_al_rahmann

internal object PrayerFocusOverlayDiagnostics {
    fun showSkipped(
        overlayKind: String,
        reason: String,
        prayerName: String,
        alarmId: Int,
        isPreview: Boolean,
    ): String =
        "PrayerFocusOverlay event=show_skipped overlay=$overlayKind reason=$reason " +
            "prayer=$prayerName id=$alarmId isPreview=$isPreview"

    fun windowManagerAddViewReturned(
        overlayKind: String,
        prayerName: String,
        alarmId: Int,
        isPreview: Boolean,
        screenInteractive: Boolean,
        keyguardLocked: Boolean,
    ): String =
        "PrayerFocusOverlay event=window_manager_add_view_returned overlay=$overlayKind " +
            "prayer=$prayerName id=$alarmId isPreview=$isPreview " +
            "screenInteractive=$screenInteractive keyguardLocked=$keyguardLocked"
}
