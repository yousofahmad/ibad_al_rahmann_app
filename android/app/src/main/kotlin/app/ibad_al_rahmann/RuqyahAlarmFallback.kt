package app.ibad_al_rahmann

internal data class AlarmFallbackContent(
    val title: String,
    val body: String,
)

/** Fallback copy used if an older or restored alarm intent lacks saved text. */
internal object RuqyahAlarmFallback {
    const val MORNING_ALARM_ID = 4
    const val EVENING_ALARM_ID = 5

    fun forAlarmId(alarmId: Int): AlarmFallbackContent? = when (alarmId) {
        MORNING_ALARM_ID, EVENING_ALARM_ID -> AlarmFallbackContent(
            title = "الرقية الشرعية",
            body = "حصن نفسك الآن بالرقية الشرعية",
        )
        else -> null
    }

    fun shouldSuppressWhenDisabled(
        alarmId: Int,
        ruqyahEnabled: Boolean,
    ): Boolean =
        forAlarmId(alarmId) != null && !ruqyahEnabled
}
