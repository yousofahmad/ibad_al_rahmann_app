package app.ibad_al_rahmann

/** Alarm IDs used by older Kahf/Salawat schedulers and safe to cancel on migration. */
internal object LegacyKahfAlarmIds {
    val all: Set<Int> = setOf(2350, 2351, 2352, 2360, 2361, 2362)
}
