package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.BackoffPolicy
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.Constraints
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

/** Independent scheduling boundary for Egyptian Hijri date checks.
 * This deliberately does not use AlarmReceiver or the prayer-alarm scheduler.
 */
object HijriSyncScheduler {
    const val ACTION_MIDNIGHT_CHECK = "app.ibad_al_rahmann.action.HIJRI_MIDNIGHT_CHECK"
    private const val MIDNIGHT_REQUEST_CODE = 29129
    private const val PERIODIC_WORK_NAME = "egyptian_hijri_daily_authority_check"
    private const val ONE_TIME_WORK_NAME = "egyptian_hijri_due_check"
    private const val CONNECTED_RETRY_WORK_NAME = "egyptian_hijri_wait_for_network"
    private const val DAILY_INTERVAL_HOURS = 24L

    fun onAppStarted(context: Context) {
        NativeLogger.log(context, "HijriSyncScheduler: TRIGGER reason=app_open actualAt=${java.time.Instant.now()}")
        scheduleMidnightCheck(context)
        ensurePeriodicWork(context)
        enqueueOneTimeCheck(context, "app_open")
    }

    fun onSystemEvent(context: Context, action: String?) {
        NativeLogger.log(context, "HijriSyncScheduler: TRIGGER reason=system_event action=${action ?: "unknown"} actualAt=${java.time.Instant.now()}")
        scheduleMidnightCheck(context)
        ensurePeriodicWork(context)
        enqueueOneTimeCheck(context, action ?: "system_event")
    }

    fun onMidnightAlarm(context: Context) {
        NativeLogger.log(context, "HijriSyncScheduler: TRIGGER reason=midnight_alarm actualAt=${java.time.Instant.now()}")
        enqueueOneTimeCheck(context, "midnight")
        scheduleMidnightCheck(context)
    }

    private fun ensurePeriodicWork(context: Context) {
        val scheduleRequestedAt = System.currentTimeMillis()
        val expectedFirstRunAt = scheduleRequestedAt + millisUntilNextMidnight()
        NativeLogger.log(
            context,
            "HijriSyncScheduler: PERIODIC_ENQUEUE_REQUESTED reason=daily_authority_check requestedAt=${java.time.Instant.ofEpochMilli(scheduleRequestedAt)} expectedFirstRunAt=${java.time.Instant.ofEpochMilli(expectedFirstRunAt)} intervalHours=$DAILY_INTERVAL_HOURS backoff=exponential_15m",
        )
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
            .build()
        val request = PeriodicWorkRequestBuilder<HijriSyncWorker>(
            DAILY_INTERVAL_HOURS,
            TimeUnit.HOURS,
        )
            .setInitialDelay(millisUntilNextMidnight(), TimeUnit.MILLISECONDS)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
        NativeLogger.log(
            context,
            "HijriSyncScheduler: PERIODIC_ENQUEUE_SUBMITTED expectedFirstRunAt=${java.time.Instant.ofEpochMilli(expectedFirstRunAt)} policy=KEEP",
        )
    }

    private fun enqueueOneTimeCheck(context: Context, reason: String) {
        val requestedAt = System.currentTimeMillis()
        NativeLogger.log(
            context,
            "HijriSyncScheduler: ONE_TIME_ENQUEUE_REQUESTED reason=$reason requestedAt=${java.time.Instant.ofEpochMilli(requestedAt)} backoff=exponential_15m",
        )
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
            .build()
        val request = OneTimeWorkRequestBuilder<HijriSyncWorker>()
            .setInputData(androidx.work.workDataOf(HijriSyncWorker.INPUT_REASON to reason))
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            ONE_TIME_WORK_NAME,
            ExistingWorkPolicy.KEEP,
            request,
        )
        NativeLogger.log(
            context,
            "HijriSyncScheduler: ONE_TIME_ENQUEUE_SUBMITTED reason=$reason expectedEarliestAt=${java.time.Instant.ofEpochMilli(requestedAt)} policy=KEEP",
        )
    }

    fun enqueueConnectedRetry(context: Context) {
        val requestedAt = System.currentTimeMillis()
        NativeLogger.log(
            context,
            "HijriSyncScheduler: CONNECTED_RETRY_REQUESTED reason=network_restored requestedAt=${java.time.Instant.ofEpochMilli(requestedAt)}",
        )
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<HijriSyncWorker>()
            .setInputData(androidx.work.workDataOf(HijriSyncWorker.INPUT_REASON to "network_restored"))
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            CONNECTED_RETRY_WORK_NAME,
            ExistingWorkPolicy.KEEP,
            request,
        )
        NativeLogger.log(
            context,
            "HijriSyncScheduler: CONNECTED_RETRY_SUBMITTED expectedAt=${java.time.Instant.ofEpochMilli(requestedAt)} networkRequired=CONNECTED policy=KEEP",
        )
    }

    private fun scheduleMidnightCheck(context: Context) {
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        val intent = Intent(context, HijriSyncReceiver::class.java).apply {
            action = ACTION_MIDNIGHT_CHECK
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            MIDNIGHT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        var exact = true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    next.timeInMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, next.timeInMillis, pendingIntent)
            }
        } catch (_: SecurityException) {
            exact = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    next.timeInMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, next.timeInMillis, pendingIntent)
            }
        }
        NativeLogger.log(
            context,
            "HijriSyncScheduler: MIDNIGHT_ALARM_SCHEDULED reason=daily_check scheduledFor=${java.time.Instant.ofEpochMilli(next.timeInMillis)} exact=$exact",
        )
    }

    private fun millisUntilNextMidnight(): Long {
        val now = Calendar.getInstance()
        val next = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= now.timeInMillis) add(Calendar.DAY_OF_YEAR, 1)
        }
        return (next.timeInMillis - now.timeInMillis).coerceAtLeast(0L)
    }
}
