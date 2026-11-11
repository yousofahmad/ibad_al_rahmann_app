package app.ibad_al_rahmann

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationGroupCleanupPolicyTest {
    @Test
    fun clearsOnlyPrayerChildrenAfterIsha() {
        val active = listOf(
            ActiveNotificationGroupEntry(104, NotificationGroupCleanupPolicy.PRAYER_GROUP),
            ActiveNotificationGroupEntry(3004, null),
            ActiveNotificationGroupEntry(7001, NotificationGroupCleanupPolicy.GENERAL_GROUP),
            ActiveNotificationGroupEntry(NotificationGroupCleanupPolicy.PRAYER_SUMMARY_ID, NotificationGroupCleanupPolicy.PRAYER_GROUP),
            ActiveNotificationGroupEntry(777, null),
        )

        assertEquals(
            setOf(104, 3004),
            NotificationGroupCleanupPolicy.prayerChildrenToClearAfterIsha(active),
        )
    }

    @Test
    fun cancelsOnlyPrayerSummaryWhenLastPrayerChildIsDismissed() {
        val active = listOf(
            ActiveNotificationGroupEntry(101, NotificationGroupCleanupPolicy.PRAYER_GROUP),
            ActiveNotificationGroupEntry(4, NotificationGroupCleanupPolicy.GENERAL_GROUP),
        )

        assertEquals(
            setOf(NotificationGroupCleanupPolicy.PRAYER_SUMMARY_ID),
            NotificationGroupCleanupPolicy.summariesToCancel(active, dismissedNotificationId = 101),
        )
    }

    @Test
    fun keepsPrayerSummaryWhileAnotherPrayerChildIsActive() {
        val active = listOf(
            ActiveNotificationGroupEntry(101, NotificationGroupCleanupPolicy.PRAYER_GROUP),
            ActiveNotificationGroupEntry(102, NotificationGroupCleanupPolicy.PRAYER_GROUP),
        )

        assertEquals(
            setOf(NotificationGroupCleanupPolicy.GENERAL_SUMMARY_ID),
            NotificationGroupCleanupPolicy.summariesToCancel(active, dismissedNotificationId = 101),
        )
    }

    @Test
    fun cancelsBothSummariesWhenNoChildrenRemain() {
        val active = listOf(
            ActiveNotificationGroupEntry(NotificationGroupCleanupPolicy.PRAYER_SUMMARY_ID, NotificationGroupCleanupPolicy.PRAYER_GROUP),
            ActiveNotificationGroupEntry(NotificationGroupCleanupPolicy.GENERAL_SUMMARY_ID, NotificationGroupCleanupPolicy.GENERAL_GROUP),
            ActiveNotificationGroupEntry(777, null),
        )

        assertEquals(
            setOf(
                NotificationGroupCleanupPolicy.PRAYER_SUMMARY_ID,
                NotificationGroupCleanupPolicy.GENERAL_SUMMARY_ID,
            ),
            NotificationGroupCleanupPolicy.summariesToCancel(active),
        )
    }

    @Test
    fun explicitGroupMembershipTakesPrecedenceOverLegacyIdRanges() {
        val active = listOf(
            ActiveNotificationGroupEntry(101, NotificationGroupCleanupPolicy.GENERAL_GROUP),
            ActiveNotificationGroupEntry(5, NotificationGroupCleanupPolicy.PRAYER_GROUP),
        )

        assertEquals(
            emptySet<Int>(),
            NotificationGroupCleanupPolicy.summariesToCancel(active),
        )
    }

    @Test
    fun fallsBackToKnownPrayerIdsForLegacyNotificationsWithoutGroupMetadata() {
        val active = listOf(ActiveNotificationGroupEntry(3002, null))

        assertEquals(
            setOf(NotificationGroupCleanupPolicy.GENERAL_SUMMARY_ID),
            NotificationGroupCleanupPolicy.summariesToCancel(active),
        )
    }
}
