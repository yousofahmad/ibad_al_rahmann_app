import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/backup_sync_schedule.dart';

void main() {
  group('BackupSyncSchedule', () {
    test('schedules one hour after the app-computed Isha', () {
      final now = DateTime(2026, 10, 24, 19, 45);
      final todayIsha = DateTime(2026, 10, 24, 19, 30);
      final tomorrowIsha = DateTime(2026, 10, 25, 19, 28);

      expect(
        BackupSyncSchedule.nextDailyRun(
          now: now,
          todayIsha: todayIsha,
          tomorrowIsha: tomorrowIsha,
        ),
        DateTime(2026, 10, 24, 20, 30),
      );
    });

    test('uses tomorrow after today’s after-Isha target has passed', () {
      expect(
        BackupSyncSchedule.nextDailyRun(
          now: DateTime(2026, 10, 24, 20, 30),
          todayIsha: DateTime(2026, 10, 24, 19, 30),
          tomorrowIsha: DateTime(2026, 10, 25, 19, 28),
        ),
        DateTime(2026, 10, 25, 20, 28),
      );
    });

    test('retries hourly only when the next attempt is before Fajr', () {
      expect(
        BackupSyncSchedule.nextHourlyRetry(
          now: DateTime(2026, 10, 24, 21, 10),
          fajr: DateTime(2026, 10, 25, 4, 30),
        ),
        DateTime(2026, 10, 24, 22, 10),
      );
      expect(
        BackupSyncSchedule.nextHourlyRetry(
          now: DateTime(2026, 10, 25, 3, 45),
          fajr: DateTime(2026, 10, 25, 4, 30),
        ),
        isNull,
      );
    });

    test('power-on recovery waits 30 minutes while attempts remain', () {
      final now = DateTime(2026, 10, 25, 8, 0);
      expect(BackupSyncSchedule.maxPowerRecoveryAttempts, 4);
      expect(
        BackupSyncSchedule.nextPowerRecoveryRetry(
          now: now,
          attemptsRemaining: 3,
        ),
        DateTime(2026, 10, 25, 8, 30),
      );
      expect(
        BackupSyncSchedule.nextPowerRecoveryRetry(
          now: now,
          attemptsRemaining: 0,
        ),
        isNull,
      );
      expect(
        BackupSyncSchedule.attemptsRemainingAfterPowerRecoveryAttempt(4),
        3,
      );
      expect(
        BackupSyncSchedule.attemptsRemainingAfterPowerRecoveryAttempt(1),
        0,
      );
      expect(
        BackupSyncSchedule.attemptsRemainingAfterPowerRecoveryAttempt(0),
        0,
      );
    });

    test('sets the retry deadline to the Fajr ending the scheduled night', () {
      final sameDayFajr = DateTime(2026, 10, 25, 4, 30);
      final nextDayFajr = DateTime(2026, 10, 26, 4, 31);

      expect(
        BackupSyncSchedule.retryDeadline(
          now: DateTime(2026, 10, 24, 21, 0),
          scheduledAt: DateTime(2026, 10, 24, 20, 30),
          ishaOnScheduledDate: DateTime(2026, 10, 24, 19, 30),
          fajrOnScheduledDate: DateTime(2026, 10, 24, 4, 29),
          fajrOnNextDate: sameDayFajr,
        ),
        sameDayFajr,
      );
      expect(
        BackupSyncSchedule.retryDeadline(
          now: DateTime(2026, 10, 25, 3, 0),
          scheduledAt: DateTime(2026, 10, 25, 2, 30),
          ishaOnScheduledDate: DateTime(2026, 10, 25, 19, 28),
          fajrOnScheduledDate: sameDayFajr,
          fajrOnNextDate: nextDayFajr,
        ),
        sameDayFajr,
      );
      expect(
        BackupSyncSchedule.retryDeadline(
          now: DateTime(2026, 10, 25, 20, 45),
          scheduledAt: DateTime(2026, 10, 25, 20, 30),
          ishaOnScheduledDate: DateTime(2026, 10, 25, 19, 28),
          fajrOnScheduledDate: sameDayFajr,
          fajrOnNextDate: null,
        ),
        isNull,
      );
      expect(
        BackupSyncSchedule.retryDeadline(
          now: DateTime(2026, 10, 25, 10, 0),
          scheduledAt: DateTime(2026, 10, 25, 7, 0),
          ishaOnScheduledDate: DateTime(2026, 10, 25, 19, 28),
          fajrOnScheduledDate: sameDayFajr,
          fajrOnNextDate: nextDayFajr,
        ),
        nextDayFajr,
      );
    });
  });
}
