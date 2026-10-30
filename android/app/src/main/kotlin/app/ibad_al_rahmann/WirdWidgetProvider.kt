package app.ibad_al_rahmann

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import org.json.JSONObject

class WirdWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val startedAt = SystemClock.elapsedRealtime()
        NativeLogger.log(context, "WirdWidget event=update_started trigger=appwidget_on_update widgets=${appWidgetIds.size}")
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val snapshot = readSnapshot(prefs)
        var updated = 0

        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_wird)
                if (snapshot == null) {
                    views.setTextViewText(R.id.tv_wird_name, "لا توجد ختمة نشطة")
                    views.setTextViewText(R.id.tv_wird_progress, "—")
                    views.setTextViewText(R.id.tv_wird_pages, "ابدأ وردك من التطبيق")
                    views.setTextViewText(R.id.tv_wird_hint, "اضغط لفتح عباد الرحمن")
                    views.setProgressBar(R.id.pb_wird_progress, 100, 0, false)
                } else {
                    views.setTextViewText(R.id.tv_wird_name, snapshot.name)
                    if (snapshot.targetIndex == null) {
                        views.setTextViewText(R.id.tv_wird_progress, "اكتملت الختمة")
                        views.setTextViewText(R.id.tv_wird_pages, "ما شاء الله، أتممت الورد")
                        views.setTextViewText(R.id.tv_wird_hint, "اضغط لفتح ختماتك")
                    } else {
                        val targetNumber = snapshot.targetIndex + 1
                        views.setTextViewText(
                            R.id.tv_wird_progress,
                            "الورد ${toArabicDigits(targetNumber.toString())} من ${toArabicDigits(snapshot.totalWirds.toString())}",
                        )
                        val start = toArabicDigits(snapshot.startPage.toString())
                        val end = toArabicDigits(snapshot.endPage.toString())
                        val pageText = if (snapshot.startPage == snapshot.endPage) {
                            "صفحة $start"
                        } else {
                            "من صفحة $start إلى $end"
                        }
                        views.setTextViewText(R.id.tv_wird_pages, pageText)
                        views.setTextViewText(R.id.tv_wird_hint, "اضغط لمتابعة وردك")
                    }
                    views.setProgressBar(
                        R.id.pb_wird_progress,
                        100,
                        snapshot.progressPercent,
                        false,
                    )
                }

                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        appWidgetId + 4300,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    views.setOnClickPendingIntent(R.id.widget_wird_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                updated++
            } catch (error: Exception) {
                NativeLogger.log(context, "WirdWidget event=update_failed reason=${error.javaClass.simpleName}")
            }
        }

        NativeLogger.log(
            context,
            "WirdWidget event=update_finished outcome=${if (snapshot == null) "waiting_for_active_khatma" else "success"} updated=$updated elapsed_ms=${SystemClock.elapsedRealtime() - startedAt}",
        )
    }

    private fun readSnapshot(prefs: android.content.SharedPreferences): Snapshot? {
        val activeId = readString(prefs, "active_khatma_id")
        val activeJson = activeId?.let { readString(prefs, "khatma_$it") }
        val activeSnapshot = parseSnapshot(activeJson)
        if (activeSnapshot != null) return activeSnapshot

        val candidates = prefs.all.entries
            .asSequence()
            .filter { it.value is String }
            .filter { entry ->
                val key = entry.key.removePrefix("flutter.")
                key.startsWith("khatma_") && key != "khatma_completed_list"
            }
            .sortedBy { it.key }
            .mapNotNull { parseSnapshot(it.value as? String) }
            .toList()
        return candidates.firstOrNull { it.targetIndex != null } ?: candidates.firstOrNull()
    }

    private fun readString(
        prefs: android.content.SharedPreferences,
        key: String,
    ): String? = (prefs.all["flutter.$key"] ?: prefs.all[key]) as? String

    private fun parseSnapshot(rawJson: String?): Snapshot? {
        if (rawJson.isNullOrBlank()) return null
        return try {
            val root = JSONObject(rawJson)
            val wirds = root.optJSONArray("wirds") ?: return null
            if (wirds.length() == 0) return null

            val completionFlags = (0 until wirds.length()).map { index ->
                wirds.optJSONObject(index)?.optBoolean("isCompleted", false) ?: false
            }
            val currentIndex = root.optInt("currentWirdIndex", 0)
            val targetIndex = WirdWidgetData.currentTargetIndex(currentIndex, completionFlags)
            val target = targetIndex?.let { wirds.optJSONObject(it) }
            val totalWirds = wirds.length()
            val completedCount = completionFlags.count { it }
            Snapshot(
                name = root.optString("name").takeIf { it.isNotBlank() } ?: "ورد القرآن",
                totalWirds = totalWirds,
                targetIndex = targetIndex,
                startPage = target?.optInt("startPage", 1) ?: 1,
                endPage = target?.optInt("endPage", 1) ?: 1,
                progressPercent = ((completedCount * 100) / totalWirds).coerceIn(0, 100),
            )
        } catch (_: Exception) {
            null
        }
    }

    private data class Snapshot(
        val name: String,
        val totalWirds: Int,
        val targetIndex: Int?,
        val startPage: Int,
        val endPage: Int,
        val progressPercent: Int,
    )

    private fun toArabicDigits(value: String): String = buildString(value.length) {
        for (character in value) {
            append(if (character in '0'..'9') ('\u0660'.code + (character - '0')).toChar() else character)
        }
    }

    companion object {
        fun requestUpdate(context: Context, trigger: String) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WirdWidgetProvider::class.java))
            NativeLogger.log(context, "WirdWidget event=refresh_requested trigger=$trigger widgets=${ids.size}")
            if (ids.isEmpty()) return
            val intent = Intent(context, WirdWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
