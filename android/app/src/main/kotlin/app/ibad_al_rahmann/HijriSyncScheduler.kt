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
        scheduleMidnightCheck(context)
        ensurePeriodicWork(context)
        enqueueOneTimeCheck(context, "app_open")
    }

    fun onSystemEvent(context: Context, action: String?) {
        scheduleMidnightCheck(context)
        ensurePeriodicWork(context)
        enqueueOneTimeCheck(context, action ?: "system_event")
    }

    fun onMidnightAlarm(context: Context) {
        enqueueOneTimeCheck(context, "midnight")
        scheduleMidnightCheck(context)
    }

    private fun ensurePeriodicWork(context: Context) {
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
    }

    private fun enqueueOneTimeCheck(context: Context, reason: String) {
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
    }

    fun enqueueConnectedRetry(context: Context) {
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
