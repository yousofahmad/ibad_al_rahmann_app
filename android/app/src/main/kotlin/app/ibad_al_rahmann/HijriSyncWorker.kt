package app.ibad_al_rahmann

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.floor

/**
 * Egyptian Hijri date sync, intentionally isolated from prayer alarms.
 * It reads/writes the same FlutterSharedPreferences keys as HijriSourceService.
 */
class HijriSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val actualStartedAt = System.currentTimeMillis()
        val trigger = inputData.getString(INPUT_REASON)
            ?: if (runAttemptCount > 0) "work_manager_retry" else "scheduled_or_app_check"
        var outcome = "unknown"
        var reason = "unclassified_exit"
        NativeLogger.log(
            applicationContext,
            "HijriSyncWorker: START actualStartedAt=${Date(actualStartedAt).toInstant()} trigger=$trigger runAttempt=$runAttemptCount",
        )
        return try {
            withContext(Dispatchers.IO) {
        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getString(KEY_SYSTEM, "umm_alqura") != "egyptian") {
            outcome = "skipped"
            reason = "non_egyptian_calendar"
            return@withContext Result.success()
        }

        val cairoDate = LocalDate.now(ZoneId.of("Africa/Cairo"))
        val todayKey = cairoDate.toString()
        val today = Date.from(cairoDate.atStartOfDay(ZoneId.systemDefault()).toInstant())
        val online = hasValidatedInternet()
        val manualDate = HijriSyncDatePolicy.parseUserConfirmation(
            prefs.getString(key(KEY_USER_CONFIRMATION), null),
            todayKey,
        )
        val esaDate = HijriSyncDatePolicy.parseAnnualEsaDate(
            prefs.getString(key(KEY_EGYPTIAN_SYNC_STATE), null),
            todayKey,
            prefs.getString(key("notification_hijri_$todayKey"), null),
            prefs.getString(key("local_hijri_confirmed_source_$todayKey"), null),
        )
        val selection = HijriSyncDatePolicy.select(manualDate, esaDate)
        NativeLogger.log(
            applicationContext,
            "HijriSyncWorker: SOURCE_LOOKUP civilDate=$todayKey manualAvailable=${manualDate != null} esaAnnualAvailable=${esaDate != null} selectedSource=${selection?.source ?: "unavailable"} selectedDate=${selection?.date?.let { "${it.day}/${it.month}/${it.year}" } ?: "unavailable"}",
        )
        if (selection == null) {
            if (!online) HijriSyncScheduler.enqueueConnectedRetry(applicationContext)
            outcome = "skipped"
            reason = if (online) "esa_annual_row_not_cached" else "offline_no_cached_esa_row"
            return@withContext Result.success()
        }

        val lastFetchDate = prefs.getString(key(KEY_LAST_FETCH), null)
        val previousDate = readStoredDate(prefs)
        if (lastFetchDate == todayKey &&
            previousDate?.sameAs(selection.date) == true &&
            selection.source == prefs.getString(key(KEY_DATE_SOURCE), null)
        ) {
            outcome = "skipped"
            reason = "selected_date_already_applied_today"
            return@withContext Result.success()
        }

        val lastAttemptRaw = prefs.getString(key(KEY_LAST_ATTEMPT), null)
        val lastAttemptKey = lastAttemptRaw?.take(10)
        val lastAttemptMillis = lastAttemptRaw
            ?.let { runCatching { java.time.Instant.parse(it).toEpochMilli() }.getOrNull() }
            ?: 0L
        val previousAttemptOnline = prefs.getBoolean(key(KEY_LAST_ATTEMPT_ONLINE), false)
        if (runAttemptCount == 0 && lastAttemptKey == todayKey &&
            System.currentTimeMillis() - lastAttemptMillis < RETRY_THROTTLE_MS &&
            (!online || previousAttemptOnline)) {
            if (previousDate?.sameAs(selection.date) != true ||
                selection.source != prefs.getString(key(KEY_DATE_SOURCE), null)
            ) {
                applySelectedDate(prefs, today, todayKey, selection)
            }
            if (!online) HijriSyncScheduler.enqueueConnectedRetry(applicationContext)
            outcome = "skipped"
            reason = if (online) "retry_throttle_active_cached_date_applied" else "offline_cached_date_applied"
            return@withContext Result.success()
        }

        prefs.edit()
            .putString(key(KEY_LAST_ATTEMPT), Date().toInstant().toString())
            .putBoolean(key(KEY_LAST_ATTEMPT_ONLINE), online)
            .apply()
        if (!online) {
            applySelectedDate(prefs, today, todayKey, selection)
            HijriSyncScheduler.enqueueConnectedRetry(applicationContext)
            outcome = "success"
            reason = "cached_${selection.source}_applied_offline"
            return@withContext Result.success()
        }

        // Apply the official/manual date before any network comparison; Dar
        // al-Ifta availability must never delay Egyptian notifications.
        applySelectedDate(prefs, today, todayKey, selection)
        val darDate = fetchDarAlIfta()
        val comparisonOutcome = when {
            darDate == null -> "unavailable"
            darDate.sameAs(selection.date) -> "matches_selected_egyptian_date"
            else -> "differs_from_selected_egyptian_date"
        }
        NativeLogger.log(
            applicationContext,
            "HijriSyncWorker: COMPARISON source=dar_alifta_daily_comparison_only civilDate=$todayKey outcome=$comparisonOutcome comparisonDate=${darDate?.let { "${it.day}/${it.month}/${it.year}" } ?: "unavailable"} selectedSource=${selection.source} selectedDate=${selection.date.day}/${selection.date.month}/${selection.date.year}",
        )
        outcome = "success"
        reason = "date_applied_source_${selection.source}_dar_comparison_$comparisonOutcome"
        Result.success()
            }
        } catch (error: Exception) {
            outcome = "exception"
            reason = "exception_${error.javaClass.simpleName}"
            throw error
        } finally {
            val actualFinishedAt = System.currentTimeMillis()
            NativeLogger.log(
                applicationContext,
                "HijriSyncWorker: FINISHED actualFinishedAt=${Date(actualFinishedAt).toInstant()} outcome=$outcome reason=$reason trigger=$trigger runAttempt=$runAttemptCount durationMs=${actualFinishedAt - actualStartedAt}",
            )
        }
    }

    private fun hasValidatedInternet(): Boolean {
        val manager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
    }

    private fun applySelectedDate(
        prefs: android.content.SharedPreferences,
        today: Date,
        todayKey: String,
        selection: HijriSyncDatePolicy.Selection,
    ) {
        val chosen = selection.date
        val previousDate = readStoredDate(prefs)
        val previousTemporary = prefs.getBoolean(key(KEY_TEMPORARY), false)
        val oldOffset = readInt(prefs, key(KEY_LOCAL_OFFSET))
            ?: readInt(prefs, key("hijri_offset"))
            ?: 0
        val offset = resolveOffset(chosen, today)
        val correctionNeeded = previousDate == null || !chosen.sameAs(previousDate)
        val edit = prefs.edit()
            .putLong(key(KEY_LOCKED_MONTH), chosen.month.toLong())
            .putLong(key(KEY_LOCKED_YEAR), chosen.year.toLong())
            .putString(key(KEY_LAST_FETCH), todayKey)
            .putString(key(KEY_DATE_SOURCE), selection.source)
            .putString(key(KEY_ANCHOR_DATE), todayKey)
            .putLong(key(KEY_OFFICIAL_DAY), chosen.day.toLong())
            .putLong(key(KEY_OFFICIAL_MONTH), chosen.month.toLong())
            .putLong(key(KEY_OFFICIAL_YEAR), chosen.year.toLong())
            .putBoolean(key(KEY_TEMPORARY), false)
            .putBoolean(
                key(KEY_NATIVE_RESCHEDULE),
                correctionNeeded || (offset != null && oldOffset != offset),
            )
            .putString(key("local_hijri_confirmed_source_$todayKey"), selection.source)
            .putString(
                key("notification_hijri_$todayKey"),
                "${chosen.day},${chosen.month},${chosen.year}",
            )
        if (offset != null) edit.putLong(key(KEY_LOCAL_OFFSET), offset.toLong())

        if (selection.source == "user_confirmation") {
            val confirmation = prefs.getString(key(KEY_USER_CONFIRMATION), null)
            val cairoToday = LocalDate.parse(todayKey)
            for (daysAhead in 1..32) {
                val targetKey = cairoToday.plusDays(daysAhead.toLong()).toString()
                val confirmed = HijriSyncDatePolicy.parseUserConfirmation(confirmation, targetKey)
                    ?: continue
                edit.putString(
                    key("notification_hijri_$targetKey"),
                    "${confirmed.day},${confirmed.month},${confirmed.year}",
                )
            }
        }
        edit.apply()

        updateNativeDateAndWidgets()
        if (correctionNeeded || previousDate == null || previousTemporary) {
            showCorrectionNotification(prefs, chosen, todayKey, selection.source)
        }
    }

    private fun fetchDarAlIfta(): HijriDate? {
        val raw = fetchText(DAR_ALIFTA_URL) ?: return null
        return try {
            findDateInJson(JSONObject(raw))
        } catch (_: Exception) {
            try { findDateInJson(JSONArray(raw)) } catch (_: Exception) { parseDate(raw) }
        }
    }

    private fun fetchText(url: String): String? {
        // This is a daily comparison only; a brief failure is not a sync failure.
        val timeouts = intArrayOf(10_000)
        val sourceHost = runCatching { URL(url).host }.getOrDefault("unknown")
        for ((index, timeout) in timeouts.withIndex()) {
            val startedAt = System.currentTimeMillis()
            var attemptReason = "request_not_completed"
            NativeLogger.log(
                applicationContext,
                "HijriSyncWorker: SOURCE_REQUEST_STARTED source=$sourceHost attempt=${index + 1}/${timeouts.size} timeoutMs=$timeout startedAt=${Date(startedAt).toInstant()}",
            )
            var connection: HttpURLConnection? = null
            try {
                connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = timeout
                connection.readTimeout = timeout
                connection.setRequestProperty("Accept", "application/json,text/html,*/*")
                val statusCode = connection.responseCode
                if (statusCode == HttpURLConnection.HTTP_OK) {
                    val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                    NativeLogger.log(
                        applicationContext,
                        "HijriSyncWorker: SOURCE_REQUEST_FINISHED source=$sourceHost attempt=${index + 1} outcome=success httpStatus=$statusCode responseBytes=${body.toByteArray(Charsets.UTF_8).size} durationMs=${System.currentTimeMillis() - startedAt}",
                    )
                    return body
                }
                attemptReason = "http_status_$statusCode"
                if (statusCode in 400..499) {
                    NativeLogger.log(
                        applicationContext,
                        "HijriSyncWorker: SOURCE_REQUEST_FAILED source=$sourceHost attempt=${index + 1} reason=$attemptReason durationMs=${System.currentTimeMillis() - startedAt}",
                    )
                    return null
                }
            } catch (error: Exception) {
                // WorkManager retries this job with exponential backoff.
                attemptReason = "exception_${error.javaClass.simpleName}"
            } finally {
                connection?.disconnect()
            }
            NativeLogger.log(
                applicationContext,
                "HijriSyncWorker: SOURCE_REQUEST_FAILED source=$sourceHost attempt=${index + 1} reason=$attemptReason durationMs=${System.currentTimeMillis() - startedAt}",
            )
            if (index + 1 < timeouts.size) {
                NativeLogger.log(
                    applicationContext,
                    "HijriSyncWorker: SOURCE_RETRY_SCHEDULED source=$sourceHost nextAttempt=${index + 2} delayMs=1500 reason=$attemptReason",
                )
                try { Thread.sleep(1_500) } catch (_: InterruptedException) { Thread.currentThread().interrupt() }
            }
        }
        return null
    }

    private fun findDateInJson(value: Any?): HijriDate? {
        when (value) {
            is String -> return parseDate(value)
            is JSONObject -> {
                val keys = value.keys()
                while (keys.hasNext()) {
                    val found = findDateInJson(value.opt(keys.next()))
                    if (found != null) return found
                }
            }
            is JSONArray -> {
                for (index in 0 until value.length()) {
                    val found = findDateInJson(value.opt(index))
                    if (found != null) return found
                }
            }
        }
        return null
    }

    private fun parseDate(raw: String): HijriDate? {
        val normalized = normalize(raw)
        val match = Regex("(\\d{1,2})\\s+(.+?)\\s+(\\d{4})").find(normalized) ?: return null
        val day = match.groupValues[1].toIntOrNull() ?: return null
        val monthText = match.groupValues[2]
        val year = match.groupValues[3].toIntOrNull() ?: return null
        val month = monthFromName(monthText) ?: return null
        if (day !in 1..30 || month !in 1..12 || year !in 1300..1700) return null
        return HijriDate(day, month, year)
    }

    private fun normalize(raw: String): String {
        val out = StringBuilder(raw.length)
        raw.forEach { char ->
            when (char) {
                '٠', '۰' -> out.append('0')
                '١', '۱' -> out.append('1')
                '٢', '۲' -> out.append('2')
                '٣', '۳' -> out.append('3')
                '٤', '۴' -> out.append('4')
                '٥', '۵' -> out.append('5')
                '٦', '۶' -> out.append('6')
                '٧', '۷' -> out.append('7')
                '٨', '۸' -> out.append('8')
                '٩', '۹' -> out.append('9')
                'ـ' -> Unit
                else -> if (Character.getType(char) != Character.NON_SPACING_MARK.toInt()) out.append(char)
            }
        }
        return out.toString()
            .replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا').replace('ى', 'ي')
            .replace("’", "'").lowercase(Locale.ROOT).replace(Regex("\\s+"), " ").trim()
    }

    private fun monthFromName(value: String): Int? = when {
        value.contains("muharram") || value.contains("محرم") -> 1
        value.contains("safar") || value.contains("صفر") -> 2
        value.contains("rabi") || value.contains("ربيع") -> when {
            value.contains("awwal") || value.contains("awal") || value.contains("اول") -> 3
            value.contains("thani") || value.contains("akhir") || value.contains("ثان") || value.contains("اخر") -> 4
            else -> null
        }
        value.contains("jumada") || value.contains("جماد") -> when {
            value.contains("thani") || value.contains("akhir") || value.contains("ثان") || value.contains("اخر") -> 6
            value.contains("awwal") || value.contains("awal") || value.contains("اول") -> 5
            else -> null
        }
        value.contains("rajab") || value.contains("رجب") -> 7
        value.contains("shaban") || value.contains("شعبان") -> 8
        value.contains("ramadan") || value.contains("رمضان") -> 9
        value.contains("shawwal") || value.contains("شوال") -> 10
        value.contains("qidah") || value.contains("qadah") || value.contains("قعد") -> 11
        value.contains("hijjah") || value.contains("hijja") || value.contains("حج") -> 12
        else -> null
    }

    private fun resolveOffset(authority: HijriDate, civilDate: Date): Int? {
        for (offset in -3..3) {
            if (hijriAt(civilDate, offset).sameAs(authority)) return offset
        }
        return null
    }

    private fun hijriAt(civilDate: Date, offset: Int): HijriDate {
        val calendar = Calendar.getInstance().apply {
            time = civilDate
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, offset)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val islamic = android.icu.util.IslamicCalendar(
                android.icu.util.TimeZone.getDefault(),
                Locale("ar", "EG"),
            )
            islamic.setCalculationType(android.icu.util.IslamicCalendar.CalculationType.ISLAMIC_UMALQURA)
            islamic.setTimeInMillis(calendar.timeInMillis)
            return HijriDate(
                islamic.get(android.icu.util.Calendar.DAY_OF_MONTH),
                islamic.get(android.icu.util.Calendar.MONTH) + 1,
                islamic.get(android.icu.util.Calendar.YEAR),
            )
        }
        return tabularHijri(calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH) + 1, calendar.get(Calendar.DAY_OF_MONTH))
    }

    private fun tabularHijri(year: Int, month: Int, day: Int): HijriDate {
        var civilYear = year
        var civilMonth = month
        if (civilMonth < 3) { civilYear -= 1; civilMonth += 12 }
        val a = floor(civilYear / 100.0)
        val b = 2 - a + floor(a / 4.0)
        val jd = floor(365.25 * (civilYear + 4716)) + floor(30.6001 * (civilMonth + 1)) + day + b - 1524.5
        val z = jd + 0.5
        val cycle = floor((z - 1948439.5) / 10631.0)
        val remainder = z - 1948439.5 - cycle * 10631.0
        val j = floor((remainder - 0.12) / 354.3666)
        val rest = remainder - floor(j * 354.3666 + 0.5)
        val hijriYear = (cycle * 30 + j + 1).toInt()
        var hijriMonth = floor((rest + 28.5001) / 29.5).toInt()
        if (hijriMonth == 13) hijriMonth = 12
        var hijriDay = (rest - floor(hijriMonth * 29.5 - 28.999)).toInt()
        if (hijriDay <= 0) hijriDay = 1
        if (hijriDay > 30) hijriDay = 30
        return HijriDate(hijriDay, hijriMonth, hijriYear)
    }

    private fun showCorrectionNotification(
        prefs: android.content.SharedPreferences,
        date: HijriDate,
        todayKey: String,
        source: String,
    ) {
        val correctionKey = "$todayKey:${date.day}-${date.month}-${date.year}"
        val preferenceKey = key(KEY_LAST_NOTIFIED_CORRECTION)
        if (prefs.getString(preferenceKey, null) == correctionKey) return
        val body = if (source == "user_confirmation") {
            "تم تحديث التاريخ الهجري إلى ${date.day}/${date.month}/${date.year} هـ وفق التأكيد اليدوي المحفوظ."
        } else {
            "تم تحديث التاريخ الهجري إلى ${date.day}/${date.month}/${date.year} هـ وفق جدول هيئة المساحة السنوي."
        }
        prefs.edit().putString(preferenceKey, correctionKey).apply()
        showSystemNotification(
            title = "تم تحديث التاريخ الهجري",
            body = body,
            payload = "home",
            notificationId = CORRECTION_NOTIFICATION_ID,
        )
    }

    private fun showSystemNotification(title: String, body: String, payload: String, notificationId: Int) {
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return
        }
        val channelId = "egyptian_hijri_sync_v1"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(channelId, "تحديث التاريخ الهجري", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "تنبيهات تصحيح أو تعذر تحديث التاريخ الهجري المصري"
                },
            )
        }
        val openIntent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("from_notification", true)
            putExtra("target_page", payload)
            putExtra("payload", payload)
        }
        val contentIntent = PendingIntent.getActivity(
            applicationContext,
            CONTENT_INTENT_REQUEST,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = NotificationCompat.Builder(applicationContext, channelId)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        try { manager.notify(notificationId, notification) } catch (_: SecurityException) { }
    }

    private fun updateNativeDateAndWidgets() {
        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val date = readStoredDate(prefs) ?: return
        prefs.edit().putLong(key("current_hijri_day"), date.day.toLong()).apply()
        try { NativeHijriHelper.updateNativeHijriDate(applicationContext) } catch (_: Exception) { }
        val widgetManager = android.appwidget.AppWidgetManager.getInstance(applicationContext)
        listOf(
            PrayerWidgetProvider::class.java,
            PrayerWidgetLargeProvider::class.java,
            PrayerWidgetWideProvider::class.java,
        ).forEach { provider ->
            val ids = widgetManager.getAppWidgetIds(android.content.ComponentName(applicationContext, provider))
            if (ids.isNotEmpty()) {
                applicationContext.sendBroadcast(Intent(applicationContext, provider).apply {
                    action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
        }
    }

    private fun readStoredDate(prefs: android.content.SharedPreferences): HijriDate? {
        val day = readInt(prefs, key(KEY_OFFICIAL_DAY)) ?: return null
        val month = readInt(prefs, key(KEY_OFFICIAL_MONTH)) ?: return null
        val year = readInt(prefs, key(KEY_OFFICIAL_YEAR)) ?: return null
        if (day !in 1..30 || month !in 1..12 || year !in 1300..1700) return null
        return HijriDate(day, month, year)
    }

    private fun readInt(prefs: android.content.SharedPreferences, preference: String): Int? = when (val value = prefs.all[preference]) {
        is Int -> value
        is Long -> value.toInt()
        is String -> value.toIntOrNull()
        else -> null
    }

    companion object {
        const val INPUT_REASON = "hijri_sync_reason"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SYSTEM = "flutter.hijri_system"
        private const val KEY_LOCAL_OFFSET = "local_hijri_offset"
        private const val KEY_LAST_FETCH = "local_hijri_last_fetch"
        private const val KEY_LAST_ATTEMPT = "local_hijri_last_attempt_at"
        private const val KEY_LAST_ATTEMPT_ONLINE = "local_hijri_last_attempt_online"
        private const val KEY_LOCKED_MONTH = "local_hijri_locked_month"
        private const val KEY_LOCKED_YEAR = "local_hijri_locked_year"
        private const val KEY_TEMPORARY = "local_hijri_dar_alifta_temporary"
        private const val KEY_LAST_NOTIFIED_CORRECTION = "local_hijri_last_notified_correction"
        private const val KEY_OFFICIAL_DAY = "local_hijri_official_day"
        private const val KEY_OFFICIAL_MONTH = "local_hijri_official_month"
        private const val KEY_OFFICIAL_YEAR = "local_hijri_official_year"
        private const val KEY_ANCHOR_DATE = "local_hijri_anchor_civil_date"
        private const val KEY_DATE_SOURCE = "local_hijri_date_source"
        private const val KEY_NATIVE_RESCHEDULE = "local_hijri_native_reschedule_required"
        private const val RETRY_THROTTLE_MS = 23L * 60L * 60L * 1000L
        private const val CORRECTION_NOTIFICATION_ID = 29131
        private const val CONTENT_INTENT_REQUEST = 29132
        private const val DAR_ALIFTA_URL = "https://di107.dar-alifta.org/api/HijriDate?langID=2"
        private const val KEY_USER_CONFIRMATION = "egyptian_hijri_user_confirmation_v1"
        private const val KEY_EGYPTIAN_SYNC_STATE = "egyptian_hijri_sync_state_v2"

        private fun key(name: String): String = "flutter.$name"
    }
}
