package app.ibad_al_rahmann

/** Pure policy for deciding which notification group summaries have no children. */
internal data class ActiveNotificationGroupEntry(
    val id: Int,
    val group: String?,
)

internal object NotificationGroupCleanupPolicy {
    const val PRAYER_GROUP = "PRAYER_GROUP"
    const val GENERAL_GROUP = "GENERAL_GROUP"
    const val PRAYER_SUMMARY_ID = 666
    const val GENERAL_SUMMARY_ID = 667
    private const val PERSISTENT_NOTIFICATION_ID = 777

    /**
     * Returns summary IDs that should be cancelled. Explicit group membership wins;
     * ID ranges are only used for notifications created before group metadata existed.
     */
    fun summariesToCancel(
        activeNotifications: Iterable<ActiveNotificationGroupEntry>,
        dismissedNotificationId: Int = -1,
    ): Set<Int> {
        var hasPrayerChildren = false
        var hasGeneralChildren = false

        for (notification in activeNotifications) {
            if (notification.id == PRAYER_SUMMARY_ID ||
                notification.id == GENERAL_SUMMARY_ID ||
                notification.id == PERSISTENT_NOTIFICATION_ID ||
                notification.id == dismissedNotificationId
            ) {
                continue
            }

            when (notification.group) {
                PRAYER_GROUP -> hasPrayerChildren = true
                GENERAL_GROUP -> hasGeneralChildren = true
                else -> if (isLegacyPrayerNotificationId(notification.id)) {
                    hasPrayerChildren = true
                } else {
                    hasGeneralChildren = true
                }
            }
        }

        val summariesToCancel = mutableSetOf<Int>()
        if (!hasPrayerChildren) summariesToCancel.add(PRAYER_SUMMARY_ID)
        if (!hasGeneralChildren) summariesToCancel.add(GENERAL_SUMMARY_ID)
        return summariesToCancel
    }

    private fun isLegacyPrayerNotificationId(id: Int): Boolean =
        id in 100..139 ||
            id in 3000..3099 ||
            id in 5000..5099 ||
            id in 730..739
}
