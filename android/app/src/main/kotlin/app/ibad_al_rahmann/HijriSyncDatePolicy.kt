package app.ibad_al_rahmann

import org.json.JSONObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

internal data class HijriDate(val day: Int, val month: Int, val year: Int) {
    fun sameAs(other: HijriDate): Boolean =
        day == other.day && month == other.month && year == other.year
}

internal object HijriSyncDatePolicy {
    internal data class Selection(val date: HijriDate, val source: String)

    fun select(userConfirmed: HijriDate?, surveyAuthority: HijriDate?): Selection? = when {
        userConfirmed != null -> Selection(userConfirmed, "user_confirmation")
        surveyAuthority != null -> Selection(surveyAuthority, "survey_authority_annual_calendar")
        else -> null
    }

    fun parseAnnualEsaDate(
        stateJson: String?,
        civilDate: String,
        notificationSnapshot: String?,
        notificationSnapshotSource: String?,
    ): HijriDate? {
        val fromAnnualState = runCatching {
            val state = JSONObject(stateJson ?: return@runCatching null)
            if (state.optInt("schemaVersion", -1) != 2) return@runCatching null
            val row = state.optJSONObject("survey")?.optJSONObject(civilDate)
                ?: return@runCatching null
            parseDate(row.optInt("day", -1), row.optInt("month", -1), row.optInt("year", -1))
        }.getOrNull()
        if (fromAnnualState != null) return fromAnnualState
        if (notificationSnapshotSource != "survey_authority_annual_calendar" &&
            notificationSnapshotSource != "both_authorities"
        ) return null
        return parseNotificationSnapshot(notificationSnapshot)
    }

    fun parseNotificationSnapshot(raw: String?): HijriDate? {
        val values = raw?.split(',') ?: return null
        if (values.size != 3) return null
        return parseDate(
            values[0].trim().toIntOrNull() ?: return null,
            values[1].trim().toIntOrNull() ?: return null,
            values[2].trim().toIntOrNull() ?: return null,
        )
    }

    fun parseUserConfirmation(raw: String?, civilDate: String): HijriDate? = runCatching {
        val confirmation = JSONObject(raw ?: return@runCatching null)
        val anchor = LocalDate.parse(confirmation.getString("anchorDate"))
        val expires = LocalDate.parse(confirmation.getString("expiresOn"))
        val civil = LocalDate.parse(civilDate)
        if (civil.isBefore(anchor) || civil.isAfter(expires)) return@runCatching null

        val anchorDay = confirmation.getInt("day")
        val offset = ChronoUnit.DAYS.between(anchor, civil).toInt()
        val day = anchorDay + offset
        if (offset > 0 && day > 29) return@runCatching null
        parseDate(day, confirmation.getInt("month"), confirmation.getInt("year"))
    }.getOrNull()

    private fun parseDate(day: Int, month: Int, year: Int): HijriDate? =
        if (day in 1..30 && month in 1..12 && year in 1..9999) {
            HijriDate(day, month, year)
        } else {
            null
        }
}
