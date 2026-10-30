package app.ibad_al_rahmann

/** Pure selection helpers for the Qur'an wird widget. */
internal object WirdWidgetData {
    /** Returns the first unread wird at or after the persisted current index. */
    fun currentTargetIndex(currentIndex: Int, completionFlags: List<Boolean>): Int? {
        val start = currentIndex.coerceAtLeast(0)
        if (start >= completionFlags.size) return null
        return (start until completionFlags.size).firstOrNull { !completionFlags[it] }
    }
}
