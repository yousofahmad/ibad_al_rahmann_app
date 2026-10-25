class BackupSyncSchedule {
  const BackupSyncSchedule._();

  static const Duration afterIsha = Duration(hours: 1);
  static const Duration retryInterval = Duration(hours: 1);
  static const Duration powerRecoveryRetryInterval = Duration(minutes: 30);
  static const int maxPowerRecoveryAttempts = 4;

  static DateTime nextDailyRun({
    required DateTime now,
    required DateTime todayIsha,
    required DateTime tomorrowIsha,
  }) {
    final todayTarget = todayIsha.add(afterIsha);
    return todayTarget.isAfter(now) ? todayTarget : tomorrowIsha.add(afterIsha);
  }

  static DateTime? nextHourlyRetry({
    required DateTime now,
    required DateTime fajr,
  }) {
    final retryAt = now.add(retryInterval);
    return retryAt.isBefore(fajr) ? retryAt : null;
  }

  static DateTime? nextPowerRecoveryRetry({
    required DateTime now,
    required int attemptsRemaining,
  }) {
    if (attemptsRemaining <= 0) return null;
    return now.add(powerRecoveryRetryInterval);
  }

  static int attemptsRemainingAfterPowerRecoveryAttempt(int attemptsRemaining) {
    return attemptsRemaining > 0 ? attemptsRemaining - 1 : 0;
  }

  static DateTime? retryDeadline({
    required DateTime now,
    required DateTime scheduledAt,
    required DateTime ishaOnScheduledDate,
    required DateTime fajrOnScheduledDate,
    required DateTime? fajrOnNextDate,
  }) {
    if (scheduledAt.isBefore(ishaOnScheduledDate) &&
        fajrOnScheduledDate.isAfter(now)) {
      return fajrOnScheduledDate;
    }
    if (fajrOnNextDate != null && fajrOnNextDate.isAfter(now)) {
      return fajrOnNextDate;
    }
    return null;
  }
}
