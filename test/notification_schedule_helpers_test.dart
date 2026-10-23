import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/notification_schedule_helpers.dart';

void main() {
  group('NotificationScheduleHelpers', () {
    test(
      'civil day shifts preserve wall-clock dates across DST and year boundaries',
      () {
        for (final date in [
          DateTime(2026, 4, 23, 23, 30),
          DateTime(2026, 10, 29, 0, 30),
          DateTime(2026, 3, 7, 23, 30),
          DateTime(2026, 11, 1, 0, 30),
          DateTime(2026, 12, 31, 23, 59),
        ]) {
          final next = NotificationScheduleHelpers.addCivilDays(date, 1);
          final expected = DateTime(date.year, date.month, date.day + 1);
          expect(
            [next.year, next.month, next.day],
            [expected.year, expected.month, expected.day],
          );
          expect([next.hour, next.minute], [date.hour, date.minute]);
          final back = NotificationScheduleHelpers.addCivilDays(next, -1);
          expect(
            [back.year, back.month, back.day, back.hour, back.minute],
            [date.year, date.month, date.day, date.hour, date.minute],
          );
        }
        final utc = DateTime.utc(2026, 12, 31, 23, 59, 58, 123, 456);
        final next = NotificationScheduleHelpers.addCivilDays(utc, 1);
        expect(next, DateTime.utc(2027, 1, 1, 23, 59, 58, 123, 456));
        expect(next.isUtc, isTrue);
      },
    );

    test(
      'fasting rules exclude Eid, Tashreeq, unknown dates and Ramadan nafl',
      () {
        for (final day in [10, 11, 12, 13]) {
          expect(
            NotificationScheduleHelpers.isFastingDayAllowed(
              month: 12,
              day: day,
            ),
            isFalse,
          );
        }
        expect(
          NotificationScheduleHelpers.isFastingDayAllowed(month: 10, day: 1),
          isFalse,
        );
        expect(
          NotificationScheduleHelpers.isFastingDayAllowed(month: 0, day: 0),
          isFalse,
        );
        expect(
          NotificationScheduleHelpers.isFastingDayAllowed(month: 12, day: 9),
          isTrue,
        );
        expect(
          NotificationScheduleHelpers.isFastingDayAllowed(month: 12, day: 14),
          isTrue,
        );
        expect(
          NotificationScheduleHelpers.isFastingDayAllowed(month: 9, day: 15),
          isTrue,
        );
        expect(
          NotificationScheduleHelpers.isVoluntaryOrQadaaFastAllowed(
            month: 9,
            day: 15,
          ),
          isFalse,
        );
        expect(
          NotificationScheduleHelpers.intervalMinutesFromPreference(9999),
          240,
        );
        expect(NotificationScheduleHelpers.intervalMinutes(-10), 15);
      },
    );

    test('29 Ramadan is Eid night only when tomorrow is 1 Shawwal', () {
      expect(
        NotificationScheduleHelpers.isEidFitrNight(
          hijriMonth: 9,
          hijriDay: 29,
          nextHijriMonth: 9,
          nextHijriDay: 30,
        ),
        isFalse,
      );
      expect(
        NotificationScheduleHelpers.isEidFitrNight(
          hijriMonth: 9,
          hijriDay: 29,
          nextHijriMonth: 10,
          nextHijriDay: 1,
        ),
        isTrue,
      );
      expect(
        NotificationScheduleHelpers.isEidFitrNight(
          hijriMonth: 9,
          hijriDay: 30,
          nextHijriMonth: 10,
          nextHijriDay: 1,
        ),
        isTrue,
      );
    });

    test('Eid day and unrelated days are classified correctly', () {
      expect(
        NotificationScheduleHelpers.isEidFitrDay(hijriMonth: 10, hijriDay: 1),
        isTrue,
      );
      expect(
        NotificationScheduleHelpers.isEidFitrDay(hijriMonth: 10, hijriDay: 2),
        isFalse,
      );
    });

    test('takbeerat preference is already minutes and bounded', () {
      expect(NotificationScheduleHelpers.intervalMinutesFromPreference(2), 2);
      expect(NotificationScheduleHelpers.intervalMinutesFromPreference(0), 60);
      expect(NotificationScheduleHelpers.intervalMinutesFromPreference(60), 60);
      expect(
        NotificationScheduleHelpers.intervalMinutesFromPreference(240),
        240,
      );
      expect(NotificationScheduleHelpers.intervalMinutes(15), 15);
    });

    test('invalid clock components fall back instead of rolling date', () {
      expect(NotificationScheduleHelpers.clampHour(24, fallback: 8), 8);
      expect(NotificationScheduleHelpers.clampMinute(60, fallback: 10), 10);
      expect(NotificationScheduleHelpers.clampHour(23), 23);
      expect(NotificationScheduleHelpers.clampMinute(59), 59);
    });
  });
}
