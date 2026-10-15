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
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.floor

/**
 * Egyptian Hijri date sync, intentionally isolated from prayer alarms.
 * It reads/writes the same FlutterSharedPreferences keys as HijriSourceService.
 */
class HijriSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    data class HijriDate(val day: Int, val month: Int, val year: Int) {
        fun sameAs(other: HijriDate): Boolean =
            day == other.day && month == other.month && year == other.year
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getString(KEY_SYSTEM, "umm_alqura") != "egyptian") return@withContext Result.success()

        val today = civilDate(Date())
        val todayKey = dateKey(today)
        val lastFetchDate = prefs.getString(key(KEY_LAST_FETCH), null)
        val temporary = prefs.getBoolean(key(KEY_TEMPORARY), false)
        if (lastFetchDate == todayKey && !temporary && hasTrustedStoredDate(prefs)) {
            return@withContext Result.success()
        }

        val lastAttemptRaw = prefs.getString(key(KEY_LAST_ATTEMPT), null)
        val lastAttempt = parseCivilDate(lastAttemptRaw)
        val lastAttemptMillis = lastAttemptRaw
            ?.let { runCatching { java.time.Instant.parse(it).toEpochMilli() }.getOrNull() }
            ?: 0L
        val online = hasValidatedInternet()
        val previousAttemptOnline = prefs.getBoolean(key(KEY_LAST_ATTEMPT_ONLINE), false)
        if (runAttemptCount == 0 && lastAttempt == today &&
            System.currentTimeMillis() - lastAttemptMillis < RETRY_THROTTLE_MS &&
            (!online || previousAttemptOnline)) {
            applyOfflineProjection(prefs, today)
            if (!online) HijriSyncScheduler.enqueueConnectedRetry(applicationContext)
            return@withContext Result.success()
        }

        prefs.edit()
            .putString(key(KEY_LAST_ATTEMPT), Date().toInstant().toString())
            .putBoolean(key(KEY_LAST_ATTEMPT_ONLINE), online)
            .apply()
        if (!online) {
            applyOfflineProjection(prefs, today)
            showFailureNotification(prefs, todayKey)
            if (inputData.getString(INPUT_REASON) == "network_restored") {
                return@withContext Result.retry()
            }
            HijriSyncScheduler.enqueueConnectedRetry(applicationContext)
            return@withContext Result.success()
        }

        val (darDate, esaDate) = coroutineScope {
            val dar = async(Dispatchers.IO) { fetchDarAlIfta() }
            val esa = async(Dispatchers.IO) { fetchSurveyAuthority() }
            dar.await() to esa.await()
        }
        // Dar Al-Ifta is the live date for today; ESA's full calendar is a
        // verifier only and is never substituted when the API is unavailable.
        val chosen = darDate
        if (chosen == null) {
            applyOfflineProjection(prefs, today)
            showFailureNotification(prefs, todayKey)
            return@withContext Result.retry()
        }

        val offset = resolveOffset(chosen, today)
        if (offset == null) {
            applyOfflineProjection(prefs, today)
            showFailureNotification(prefs, todayKey)
            return@withContext Result.retry()
        }

        val previousDate = readStoredDate(prefs)
        val previousTemporary = prefs.getBoolean(key(KEY_TEMPORARY), false)
        val oldOffset = readInt(prefs, key(KEY_LOCAL_OFFSET))
            ?: readInt(prefs, key("hijri_offset"))
            ?: 0
        val previousDisplayed = hijriAt(today, oldOffset)
        val correctionNeeded = !chosen.sameAs(previousDisplayed)
        val temporaryDarSource = darDate != null &&
            (esaDate == null || !darDate.sameAs(esaDate))
        val source = when {
            darDate != null && esaDate != null && darDate.sameAs(esaDate) -> "both_authorities"
            else -> "dar_alifta_api"
        }

        val edit = prefs.edit()
            .putLong(key(KEY_LOCAL_OFFSET), offset.toLong())
            .putLong(key(KEY_LOCKED_MONTH), chosen.month.toLong())
            .putLong(key(KEY_LOCKED_YEAR), chosen.year.toLong())
            .putString(key(KEY_LAST_FETCH), todayKey)
            .putString(key(KEY_CONFIRMED), todayKey)
            .putString(key(KEY_DATE_SOURCE), source)
            .putString(key(KEY_ANCHOR_DATE), todayKey)
            .putLong(key(KEY_OFFICIAL_DAY), chosen.day.toLong())
            .putLong(key(KEY_OFFICIAL_MONTH), chosen.month.toLong())
            .putLong(key(KEY_OFFICIAL_YEAR), chosen.year.toLong())
            .putBoolean(key(KEY_TEMPORARY), temporaryDarSource)
            .putBoolean(key(KEY_NATIVE_RESCHEDULE), correctionNeeded || oldOffset != offset)
            .putString(key("local_hijri_confirmed_source_$todayKey"), source)
        edit.apply()

        updateNativeDateAndWidgets()
        if (correctionNeeded || previousDate == null || previousTemporary) {
            showCorrectionNotification(prefs, chosen, todayKey, temporaryDarSource)
        }
        Result.success()
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

    private fun fetchDarAlIfta(): HijriDate? {
        val raw = fetchText(DAR_ALIFTA_URL) ?: return null
        return try {
            findDateInJson(JSONObject(raw))
        } catch (_: Exception) {
            try { findDateInJson(JSONArray(raw)) } catch (_: Exception) { parseDate(raw) }
        }
    }

    private fun fetchSurveyAuthority(): HijriDate? {
        val raw = fetchText(SURVEY_AUTHORITY_URL, browserAgent = true) ?: return null
        val row = Regex(
            "(?is)القاهرة.*?</td>\\s*<td[^>]*>[^<]*</td>\\s*<td[^>]*>([^<]+)</td>",
        ).find(raw)?.groupValues?.getOrNull(1) ?: return null
        return parseDate(row)
    }

    private fun fetchText(url: String, browserAgent: Boolean = false): String? {
        val timeouts = intArrayOf(15_000, 30_000, 45_000)
        for (timeout in timeouts) {
            var connection: HttpURLConnection? = null
            try {
                connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = timeout
                connection.readTimeout = timeout
                connection.setRequestProperty("Accept", "application/json,text/html,*/*")
                if (browserAgent) {
                    connection.setRequestProperty(
                        "User-Agent",
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36",
                    )
                }
                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    return connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                }
                if (connection.responseCode in 400..499) return null
            } catch (_: Exception) {
                // WorkManager retries this job with exponential backoff.
            } finally {
                connection?.disconnect()
            }
            try { Thread.sleep(1_500) } catch (_: InterruptedException) { Thread.currentThread().interrupt() }
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
            val islamic = android.icu.util.IslamicCalendar(TimeZone.getDefault(), Locale("ar", "EG"))
            islamic.calculationType = android.icu.util.IslamicCalendar.CalculationType.ISLAMIC_UMALQURA
            islamic.timeInMillis = calendar.timeInMillis
            return HijriDate(
                islamic.get(android.icu.util.IslamicCalendar.DAY_OF_MONTH),
                islamic.get(android.icu.util.IslamicCalendar.MONTH) + 1,
                islamic.get(android.icu.util.IslamicCalendar.YEAR),
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

    private fun applyOfflineProjection(prefs: android.content.SharedPreferences, today: Date) {
        val saved = readStoredDate(prefs)
        if (saved == null || !hasTrustedStoredDate(prefs)) {
            val hadLocalOffset = prefs.contains(key(KEY_LOCAL_OFFSET))
            prefs.edit()
                .putBoolean(key(KEY_TEMPORARY), true)
                .putBoolean(key(KEY_NATIVE_RESCHEDULE), hadLocalOffset)
                .remove(key(KEY_LOCAL_OFFSET))
                .apply()
            if (saved != null) updateNativeDateAndWidgets()
            return
        }
        val anchor = parseCivilDate(prefs.getString(key(KEY_ANCHOR_DATE), null)) ?: return
        val elapsed = try {
            ChronoUnit.DAYS.between(
                LocalDate.parse(dateKey(anchor)),
                LocalDate.parse(dateKey(today)),
            ).toInt().coerceAtLeast(0)
        } catch (_: Exception) { 0 }
        if (elapsed == 0) return

        var projected = saved
        for (day in 0 until elapsed) {
            if (projected.day == 29) break
            projected = if (projected.day == 30) {
                if (projected.month == 12) HijriDate(1, 1, projected.year + 1)
                else HijriDate(1, projected.month + 1, projected.year)
            } else {
                HijriDate(projected.day + 1, projected.month, projected.year)
            }
        }
        val offset = resolveOffset(projected, today) ?: return
        val previousOffset = readInt(prefs, key(KEY_LOCAL_OFFSET))
        val dateChanged = !projected.sameAs(saved)
        val edit = prefs.edit()
            .putLong(key(KEY_LOCAL_OFFSET), offset.toLong())
            .putLong(key(KEY_LOCKED_MONTH), projected.month.toLong())
            .putLong(key(KEY_LOCKED_YEAR), projected.year.toLong())
            .putLong(key(KEY_OFFICIAL_DAY), projected.day.toLong())
            .putLong(key(KEY_OFFICIAL_MONTH), projected.month.toLong())
            .putLong(key(KEY_OFFICIAL_YEAR), projected.year.toLong())
            .putString(key(KEY_ANCHOR_DATE), dateKey(today))
            .putString(key(KEY_DATE_SOURCE), "offline_estimate")
            .putString(key(KEY_CONFIRMED), dateKey(today))
            .putBoolean(key(KEY_TEMPORARY), true)
            .putBoolean(key(KEY_NATIVE_RESCHEDULE), dateChanged || previousOffset != offset)
        edit.apply()
        updateNativeDateAndWidgets()
    }

    private fun showFailureNotification(prefs: android.content.SharedPreferences, todayKey: String) {
        val notificationKey = key("local_hijri_failure_notified_$todayKey")
        if (prefs.getBoolean(notificationKey, false)) return
        val saved = readStoredDate(prefs)
        val body = when {
            saved == null || !hasTrustedStoredDate(prefs) -> "تعذر الاتصال بـ API دار الإفتاء ولا يوجد تاريخ محفوظ منه. سيعرض التطبيق تاريخ المكتبة مؤقتًا؛ افتح الإعدادات للتحديث أو الإدخال اليدوي."
            saved.day >= 29 -> "فشل تحديث المصادر المصرية ووصل التاريخ المحفوظ إلى اليوم 29. اتصل بالإنترنت لتأكيد هل الغد 30 أم غرة الشهر."
            else -> "تعذر الاتصال بالمصادر المصرية. سيواصل التطبيق من التاريخ المحفوظ مؤقتًا ويحاول التحديث مجددًا."
        }
        prefs.edit().putBoolean(notificationKey, true).apply()
        showSystemNotification(
            title = "تعذّر تحديث التاريخ الهجري",
            body = body,
            payload = "hijri_confirmation",
            notificationId = FAILURE_NOTIFICATION_ID,
        )
    }

    private fun showCorrectionNotification(
        prefs: android.content.SharedPreferences,
        date: HijriDate,
        todayKey: String,
        temporary: Boolean,
    ) {
        val correctionKey = "$todayKey:${date.day}-${date.month}-${date.year}"
        val preferenceKey = key(KEY_LAST_NOTIFIED_CORRECTION)
        if (prefs.getString(preferenceKey, null) == correctionKey) return
        val body = if (temporary) {
            "تم تحديث التاريخ إلى ${date.day}/${date.month}/${date.year} هـ وفق دار الإفتاء مؤقتًا، وسيستمر التحقق يوميًا من جدول هيئة المساحة."
        } else {
            "تم تأكيد التاريخ الهجري ${date.day}/${date.month}/${date.year} هـ من المصادر المصرية."
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

    private fun hasTrustedStoredDate(prefs: android.content.SharedPreferences): Boolean {
        if (readStoredDate(prefs) == null) return false
        val source = prefs.getString(key(KEY_DATE_SOURCE), null)
        if (source == "survey_authority") return false
        val lastFetch = prefs.getString(key(KEY_LAST_FETCH), null)
        val previousSource = lastFetch?.let {
            prefs.getString(key("local_hijri_confirmed_source_$it"), null)
        }
        if (source == null && previousSource == "survey_authority") return false
        return true
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

    private fun civilDate(date: Date): Date {
        val calendar = Calendar.getInstance().apply { time = date }
        return Calendar.getInstance().apply {
            clear()
            set(calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH), calendar.get(Calendar.DAY_OF_MONTH), 0, 0, 0)
        }.time
    }

    private fun dateKey(date: Date): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)

    private fun parseCivilDate(raw: String?): Date? {
        if (raw.isNullOrBlank()) return null
        return try {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
            formatter.parse(raw.take(10))
        } catch (_: Exception) { null }
    }

    companion object {
        const val INPUT_REASON = "hijri_sync_reason"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SYSTEM = "flutter.hijri_system"
        private const val KEY_LOCAL_OFFSET = "local_hijri_offset"
        private const val KEY_LAST_FETCH = "local_hijri_last_fetch"
        private const val KEY_LAST_ATTEMPT = "local_hijri_last_attempt_at"
        private const val KEY_LAST_ATTEMPT_ONLINE = "local_hijri_last_attempt_online"
        private const val KEY_CONFIRMED = "local_hijri_confirmed_date"
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
        private const val FAILURE_NOTIFICATION_ID = 29130
        private const val CORRECTION_NOTIFICATION_ID = 29131
        private const val CONTENT_INTENT_REQUEST = 29132
        private const val DAR_ALIFTA_URL = "https://di107.dar-alifta.org/api/HijriDate?langID=2"
        private const val SURVEY_AUTHORITY_URL = "https://www.esa.gov.eg/praytimes.aspx"

        private fun key(name: String): String = "flutter.$name"
    }
}
