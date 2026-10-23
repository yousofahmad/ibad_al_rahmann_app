import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/fcm_service.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
// Test-only platform fake for the already installed path_provider plugin.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// These dates deliberately model boundary scenarios, NOT published dates.
class _FixtureBundle extends CachingAssetBundle {
  final Map<String, Map<String, int>> dates;
  _FixtureBundle(this.dates);
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'source': {
            'name': EgyptianHijriCalendar.sourceName,
            'url': EgyptianHijriCalendar.sourceUrl,
            'city': EgyptianHijriCalendar.city,
          },
          'fetchedAt': '2026-01-01T00:00:00Z',
          'dates': dates,
        }),
      ),
    ),
  );
}

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('app.ibad_al_rahmann/native_notifications');
  final calls = <MethodCall>[];
  final alarms = <Map<String, dynamic>>[];
  final calendar = EgyptianHijriCalendar.instance;
  final today = DateTime(2026, 1, 10);
  late PathProviderPlatform originalPaths;

  Map<String, int> hijri(int day, int month) => {
    'day': day,
    'month': month,
    'year': 1447,
  };

  Future<void> configure({
    Map<String, Object> settings = const {},
    Map<String, Map<String, int>>? dates,
  }) async {
    SharedPreferences.setMockInitialValues({
      'hijri_system': 'egyptian',
      'notif_fasting_monday': false,
      'notif_fasting_thursday': false,
      'notif_fasting_white_days': false,
      'notif_jumuah': false,
      'notif_kahf_salawat': false,
      ...settings,
    });
    await CacheHelper.init();
    calendar.resetForTesting();
    await calendar.initialize(
      bundle: _FixtureBundle(
        dates ??
            {
              '2026-01-10': hijri(20, 9),
              '2026-01-11': hijri(21, 9),
              '2026-01-12': hijri(22, 9),
              '2026-01-13': hijri(23, 9),
            },
      ),
    );
    calls.clear();
    alarms.clear();
  }

  Future<void> rebuild({DateTime? now}) async {
    final clock = now ?? today;
    final times = await PrayerService.getPrayerTimesForDateStatic(clock);
    expect(times, isNotNull);
    await NotificationService.scheduleAll(times!, nowOverride: clock);
    expect(
      calls.any((c) => c.method == 'updatePrayerNotification'),
      isTrue,
      reason: 'The full rebuild must finish, not swallow a scheduling error.',
    );
  }

  Map<String, dynamic> alarm(int id) =>
      alarms.singleWhere((a) => a['id'] == id);
  DateTime scheduled(Map<String, dynamic> a) => DateTime(
    a['year'] as int,
    a['month'] as int,
    a['day'] as int,
    a['hour'] as int,
    a['minute'] as int,
  );

  setUp(() {
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
          // Deep copy: scheduleAll clears its mutable batch after invoking native.
          final copied = MethodCall(
            call.method,
            call.arguments == null
                ? null
                : jsonDecode(jsonEncode(call.arguments)),
          );
          calls.add(copied);
          if (call.method == 'scheduleAlarms') {
            alarms.addAll(
              (copied.arguments['alarms'] as List).map(
                (a) => Map<String, dynamic>.from(a as Map),
              ),
            );
          }
          if (call.method == 'scheduleAlarm') {
            alarms.add(Map<String, dynamic>.from(copied.arguments as Map));
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (_) async => true,
        );
  });

  tearDown(() {
    calendar.resetForTesting();
    PathProviderPlatform.instance = originalPaths;
    for (final channel in [native, const MethodChannel('home_widget')]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  for (final lastShaabanDay in [29, 30]) {
    test(
      'Shaaban $lastShaabanDay to Ramadan 1: fasting alerts start on the first fasting civil date, not its eve',
      () async {
        await configure(
          settings: {'iftar_alarm': true, 'suhoor_alarm': true},
          dates: {
            '2026-01-10': hijri(lastShaabanDay, 8),
            '2026-01-11': hijri(1, 9),
            '2026-01-12': hijri(2, 9),
            '2026-01-13': hijri(3, 9),
          },
        );
        await rebuild();
        expect(alarms.where((a) => a['id'] == 400 || a['id'] == 410), isEmpty);
        for (final id in [401, 411]) {
          expect(scheduled(alarm(id)).day, 11);
        }
        final first = (await PrayerService.getPrayerTimesForDateStatic(
          DateTime(2026, 1, 11),
        ))!;
        expect(
          scheduled(alarm(401))
              .difference(first.maghrib.subtract(const Duration(minutes: 30)))
              .inSeconds
              .abs(),
          lessThan(60),
        );
        expect(
          scheduled(alarm(411))
              .difference(first.fajr.subtract(const Duration(minutes: 60)))
              .inSeconds
              .abs(),
          lessThan(60),
        );
      },
    );
  }

  for (final lastRamadanDay in [29, 30]) {
    test(
      'Ramadan $lastRamadanDay to Shawwal 1: last fast is kept, Eid never gets suhoor or iftar',
      () async {
        await configure(
          settings: {
            'iftar_alarm': true,
            'suhoor_alarm': true,
            'eid_fitr_alarm': true,
          },
          dates: {
            '2026-01-10': hijri(lastRamadanDay, 9),
            '2026-01-11': hijri(1, 10),
            '2026-01-12': hijri(2, 10),
            '2026-01-13': hijri(3, 10),
          },
        );
        await rebuild();
        expect(alarm(400)['day'], 10);
        expect(alarm(410)['day'], 10);
        expect(
          alarms.where((a) => [401, 402, 411, 412].contains(a['id'])),
          isEmpty,
        );
        expect(alarm(2101)['day'], 11);
      },
    );
  }

  test(
    '29 to 30 Ramadan to Eid retains both fasting dates and stops exactly on Eid',
    () async {
      await configure(
        settings: {
          'iftar_alarm': true,
          'suhoor_alarm': true,
          'eid_fitr_alarm': true,
        },
        dates: {
          '2026-01-10': hijri(29, 9),
          '2026-01-11': hijri(30, 9),
          '2026-01-12': hijri(1, 10),
          '2026-01-13': hijri(2, 10),
        },
      );
      await rebuild();
      expect(alarm(400)['day'], 10);
      expect(alarm(401)['day'], 11);
      expect(alarm(410)['day'], 10);
      expect(alarm(411)['day'], 11);
      expect(alarms.where((a) => a['id'] == 402 || a['id'] == 412), isEmpty);
      expect(alarm(2102)['day'], 12);
    },
  );

  test(
    'unknown next day after Ramadan 29 does not guess day30 or announce Eid',
    () async {
      await configure(
        settings: {
          'iftar_alarm': true,
          'suhoor_alarm': true,
          'eid_fitr_alarm': true,
          'eid_fitr_takbeer': true,
        },
        dates: {'2026-01-10': hijri(29, 9)},
      );
      await rebuild();
      expect(alarm(400)['day'], 10);
      expect(alarm(410)['day'], 10);
      expect(
        alarms.where(
          (a) => [401, 402, 411, 412, 2100, 2101, 2102, 9100].contains(a['id']),
        ),
        isEmpty,
      );
    },
  );

  test(
    'unknown next month after Shaaban 29 does not fabricate the first fast',
    () async {
      await configure(
        settings: {'iftar_alarm': true, 'suhoor_alarm': true},
        dates: {'2026-01-10': hijri(29, 8)},
      );
      await rebuild();
      expect(alarms, isEmpty);
    },
  );

  test(
    'civil new year does not shift Ramadan first-day suhoor or iftar',
    () async {
      await configure(
        settings: {'iftar_alarm': true, 'suhoor_alarm': true},
        dates: {
          '2030-12-31': hijri(30, 8),
          '2031-01-01': hijri(1, 9),
          '2031-01-02': hijri(2, 9),
          '2031-01-03': hijri(3, 9),
        },
      );
      await rebuild(now: DateTime(2030, 12, 31));
      expect(scheduled(alarm(401)).year, 2031);
      expect(scheduled(alarm(401)).month, 1);
      expect(scheduled(alarm(401)).day, 1);
      expect(scheduled(alarm(411)).year, 2031);
      expect(scheduled(alarm(411)).day, 1);
    },
  );

  test(
    'midday rebuild never reschedules the elapsed first-day suhoor',
    () async {
      await configure(
        settings: {'iftar_alarm': true, 'suhoor_alarm': true},
        dates: {
          '2026-01-10': hijri(1, 9),
          '2026-01-11': hijri(2, 9),
          '2026-01-12': hijri(3, 9),
          '2026-01-13': hijri(4, 9),
        },
      );
      await rebuild(now: DateTime(2026, 1, 10, 12));
      expect(alarms.where((a) => a['id'] == 410), isEmpty);
      expect(alarm(400)['day'], 10);
      expect(alarm(411)['day'], 11);
    },
  );

  test(
    'confirmed first Ramadan day is shared by calendar display and fasting scheduling',
    () async {
      await configure(
        settings: {
          'iftar_alarm': true,
          'suhoor_alarm': true,
          'manual_day_adjustment': 2,
        },
        dates: {
          '2026-01-10': hijri(30, 8),
          '2026-01-11': hijri(1, 9),
          '2026-01-12': hijri(2, 9),
          '2026-01-13': hijri(3, 9),
        },
      );
      calendar.applyUserConfirmation(
        EgyptianHijriUserConfirmation(
          anchorDate: today,
          hijri: const EgyptianHijriDate(hDay: 1, hMonth: 9, hYear: 1447),
          confirmedAt: '2026-01-10T00:00:00Z',
        ),
      );
      expect(calendar.lookup(today)?.hDay, 1);
      expect(PrayerService.getNotificationHijriForDate(today)?.hDay, 1);
      await rebuild();
      expect(alarm(400)['day'], 10);
      expect(alarm(410)['day'], 10);
    },
  );

  test(
    'Arafah overrides regular fasting alerts without duplicate alarm identifiers',
    () async {
      await configure(
        settings: {
          'notif_arafah': true,
          'iftar_alarm': true,
          'suhoor_alarm': true,
          'iftar_mode': 'all_year',
          'suhoor_mode': 'all_year',
        },
        dates: {
          '2026-01-10': hijri(9, 12),
          '2026-01-11': hijri(10, 12),
          '2026-01-12': hijri(11, 12),
          '2026-01-13': hijri(12, 12),
        },
      );
      await rebuild();
      expect(alarms.map((a) => a['id']).toSet(), hasLength(alarms.length));
      expect(alarm(400)['title'], 'إفطار يوم عرفة');
      expect(
        alarms.where((a) => [401, 402, 411, 412].contains(a['id'])),
        isEmpty,
      );
    },
  );

  test(
    'autumn clock change cannot duplicate a fasting civil date or skip the third day',
    () async {
      await configure(
        settings: {'iftar_alarm': true, 'suhoor_alarm': true},
        dates: {
          '2026-10-29': hijri(27, 9),
          '2026-10-30': hijri(28, 9),
          '2026-10-31': hijri(29, 9),
          '2026-11-01': hijri(30, 9),
        },
      );
      await rebuild(now: DateTime(2026, 10, 29, 0, 30));
      expect(
        [alarm(400)['day'], alarm(401)['day'], alarm(402)['day']],
        [29, 30, 31],
      );
      expect(
        [alarm(410)['day'], alarm(411)['day'], alarm(412)['day']],
        [29, 30, 31],
      );
    },
  );

  test(
    'spring clock change cannot skip the first Ramadan fasting date',
    () async {
      await configure(
        settings: {'iftar_alarm': true, 'suhoor_alarm': true},
        dates: {
          '2026-04-23': hijri(30, 8),
          '2026-04-24': hijri(1, 9),
          '2026-04-25': hijri(2, 9),
          '2026-04-26': hijri(3, 9),
        },
      );
      await rebuild(now: DateTime(2026, 4, 23, 23, 30));
      expect(alarms.where((a) => a['id'] == 400 || a['id'] == 410), isEmpty);
      expect(alarm(401)['day'], 24);
      expect(alarm(411)['day'], 24);
      expect(alarm(402)['day'], 25);
    },
  );

  test(
    'first-third and midnight modes work without enabling last-third',
    () async {
      await configure(
        settings: {
          'adhan_mode_First_third': 'silent_notif',
          'adhan_mode_Midnight': 'sound',
          'adhan_mode_Last_third': 'none',
        },
      );
      await rebuild();
      expect(
        alarms.where(
          (a) => (a['id'] as int) >= 2600 && (a['id'] as int) <= 2602,
        ),
        hasLength(3),
      );
      expect(
        alarms.where(
          (a) => (a['id'] as int) >= 2650 && (a['id'] as int) <= 2652,
        ),
        hasLength(3),
      );
      expect(
        alarms.where(
          (a) => (a['id'] as int) >= 2550 && (a['id'] as int) <= 2557,
        ),
        isEmpty,
      );
      expect(alarm(2600)['sound'], 'silent_notif');
    },
  );

  test(
    'legacy qiyam switch still activates last-third when no new mode exists',
    () async {
      await configure(settings: {'notif_qiyam': true});
      await rebuild();
      expect(
        alarms.where(
          (a) => (a['id'] as int) >= 2550 && (a['id'] as int) <= 2557,
        ),
        hasLength(3),
      );
    },
  );

  test(
    'Arafah and Eid Adha toggles work independently of regular fasting alerts',
    () async {
      await configure(
        settings: {
          'notif_arafah': true,
          'notif_eid_dhulhijjah': true,
          'eid_adha_hour': 8,
          'eid_adha_minute': 10,
        },
        dates: {
          '2026-01-10': hijri(9, 12),
          '2026-01-11': hijri(10, 12),
          '2026-01-12': hijri(11, 12),
          '2026-01-13': hijri(12, 12),
        },
      );
      await rebuild();
      expect(alarm(400)['title'], 'إفطار يوم عرفة');
      expect(alarm(410)['title'], 'سحور يوم عرفة');
      expect(scheduled(alarm(2151)), DateTime(2026, 1, 11, 8, 10));
    },
  );

  test('malformed qadaa time cannot interrupt later seasonal alarms', () async {
    await configure(
      settings: {
        'qadaa_daily_prayer_reminder': true,
        'qadaa_daily_prayer_time': 'invalid',
        'eid_fitr_alarm': true,
      },
      dates: {
        '2026-01-10': hijri(1, 10),
        '2026-01-11': hijri(2, 10),
        '2026-01-12': hijri(3, 10),
      },
    );
    await rebuild();
    expect(
      alarms.where((a) => (a['id'] as int) >= 2700 && (a['id'] as int) <= 2702),
      isEmpty,
    );
    expect(alarm(2100)['title'], 'عيد الفطر - صلاة العيد');
  });

  test('qadaa fasting honors the selected starting Hijri month', () async {
    final dates = {
      '2026-01-10': hijri(5, 7),
      '2026-01-11': hijri(6, 7),
      '2026-01-12': hijri(7, 7),
      '2026-01-13': hijri(8, 7),
    };
    await configure(
      settings: {
        'qadaa_fasting_reminder_freq': 'يومياً',
        'qadaa_fasting_reminder_start_month': 8,
      },
      dates: dates,
    );
    await rebuild();
    expect(
      alarms.where((a) => (a['id'] as int) >= 2750 && (a['id'] as int) <= 2752),
      isEmpty,
    );
    await configure(
      settings: {
        'qadaa_fasting_reminder_freq': 'يومياً',
        'qadaa_fasting_reminder_start_month': 7,
      },
      dates: dates,
    );
    await rebuild();
    expect(
      alarms.where((a) => (a['id'] as int) >= 2750 && (a['id'] as int) <= 2752),
      hasLength(3),
    );
  });

  test(
    'saved zakat due date creates a yearly reminder on the same Hijri date',
    () async {
      await configure(
        settings: {
          'qadaa_has_zakat': true,
          'qadaa_zakat_date': '2025-01-05T00:00:00',
        },
        dates: {
          '2025-01-05': {'day': 5, 'month': 8, 'year': 1446},
          '2026-01-10': hijri(5, 8),
          '2026-01-11': hijri(6, 8),
          '2026-01-12': hijri(7, 8),
        },
      );
      await rebuild();
      expect(scheduled(alarm(2800)), DateTime(2026, 1, 10, 8));
      expect(alarm(2800)['payload'], 'qadaa');
    },
  );

  test(
    'background refresh rebuilds salawat with the chosen weekdays and sound',
    () async {
      await configure(
        settings: {
          'salawat_reminder_enabled': true,
          'salawat_reminder_minutes': 20,
          'salawat_reminder_days': ['5', '0', 'bad'],
          'salawat_periodic_sound': 'salah_2',
        },
      );
      await rebuild();
      expect(alarm(950)['allowed_days'], '5');
      expect(alarm(950)['intervalMinutes'], 20);
      expect(alarm(950)['custom_sound_name'], 'salah_2');
    },
  );

  test(
    'Ramadan iftar and suhoor use exact prayer-relative dates and offsets',
    () async {
      await configure(
        settings: {
          'iftar_alarm': true,
          'suhoor_alarm': true,
          'iftar_minutes_before': 17,
          'suhoor_minutes_before': 43,
        },
      );
      final times = (await PrayerService.getPrayerTimesForDateStatic(today))!;
      await rebuild();
      expect(
        alarms.where((a) => (a['id'] as int) >= 400 && (a['id'] as int) <= 402),
        hasLength(3),
      );
      expect(
        scheduled(alarm(400))
            .difference(times.maghrib.subtract(const Duration(minutes: 17)))
            .inSeconds
            .abs(),
        lessThan(60),
      );
      expect(
        scheduled(alarm(410))
            .difference(times.fajr.subtract(const Duration(minutes: 43)))
            .inSeconds
            .abs(),
        lessThan(60),
      );
      expect(alarm(400)['custom_sound_name'], 'pre_iftar');
      expect(alarm(410)['payload'], 'fasting');
    },
  );

  test('all-year weekday selection is respected even during Ramadan', () async {
    await configure(
      settings: {
        'iftar_alarm': true,
        'suhoor_alarm': true,
        'iftar_mode': 'all_year',
        'suhoor_mode': 'all_year',
        'iftar_all_year_days': 0,
        'suhoor_all_year_days': 0,
      },
    );
    await rebuild();
    expect(
      alarms.where((a) => (a['id'] as int) >= 400 && (a['id'] as int) < 420),
      isEmpty,
    );
  });

  test('disabled Ramadan switches create no fasting alarms', () async {
    await configure();
    await rebuild();
    expect(
      alarms.where((a) => (a['id'] as int) >= 400 && (a['id'] as int) < 420),
      isEmpty,
    );
  });

  test('29 Ramadan followed by 30 does not announce or start Eid', () async {
    await configure(
      settings: {'eid_fitr_takbeer': true},
      dates: {
        '2026-01-10': hijri(29, 9),
        '2026-01-11': hijri(30, 9),
        '2026-01-12': hijri(1, 10),
        '2026-01-13': hijri(2, 10),
      },
    );
    await rebuild();
    expect(alarms.where((a) => a['id'] == 9100), isEmpty);
  });

  for (final lastRamadanDay in [29, 30]) {
    test(
      'Eid takbeerat start at Maghrib after confirmed day $lastRamadanDay and stop at the selected prayer',
      () async {
        await configure(
          settings: {
            'eid_fitr_takbeer': true,
            'eid_fitr_takbeer_interval': 7,
            'eid_fitr_hour': 7,
            'eid_fitr_minute': 15,
          },
          dates: {
            '2026-01-10': hijri(lastRamadanDay, 9),
            '2026-01-11': hijri(1, 10),
            '2026-01-12': hijri(2, 10),
            '2026-01-13': hijri(3, 10),
          },
        );
        final times = (await PrayerService.getPrayerTimesForDateStatic(today))!;
        await rebuild();
        final takbeer = alarm(9100);
        expect(
          scheduled(takbeer).difference(times.maghrib).inSeconds.abs(),
          lessThan(60),
        );
        expect(takbeer['intervalMinutes'], 7);
        expect(
          takbeer['season_end_epoch'],
          DateTime(2026, 1, 11, 7, 15).millisecondsSinceEpoch,
        );
        expect(takbeer['payload'], 'home');
      },
    );
  }

  test(
    'Eid prayer and takbeerat switches are independent and prayer defaults to sunrise +30',
    () async {
      await configure(
        settings: {'eid_fitr_alarm': true},
        dates: {
          '2026-01-10': hijri(30, 9),
          '2026-01-11': hijri(1, 10),
          '2026-01-12': hijri(2, 10),
          '2026-01-13': hijri(3, 10),
        },
      );
      final eidTimes = (await PrayerService.getPrayerTimesForDateStatic(
        today.add(const Duration(days: 1)),
      ))!;
      await rebuild();
      expect(
        scheduled(alarm(2101))
            .difference(eidTimes.sunrise.add(const Duration(minutes: 30)))
            .inSeconds
            .abs(),
        lessThan(60),
      );
      expect(
        alarms.where(
          (a) =>
              a['id'] == 9100 ||
              ((a['id'] as int) >= 2200 && (a['id'] as int) <= 2202),
        ),
        isEmpty,
      );
    },
  );

  test('Eid legacy switch and custom prayer clock still work', () async {
    await configure(
      settings: {'eid_alarm': true, 'eid_fitr_hour': 8, 'eid_fitr_minute': 12},
      dates: {
        '2026-01-10': hijri(1, 10),
        '2026-01-11': hijri(2, 10),
        '2026-01-12': hijri(3, 10),
      },
    );
    await rebuild();
    expect(scheduled(alarm(2100)), DateTime(2026, 1, 10, 8, 12));
  });

  test(
    'Eid takbeerat are canceled after the prayer and outside the season',
    () async {
      await configure(
        settings: {
          'eid_fitr_takbeer': true,
          'eid_fitr_hour': 7,
          'eid_fitr_minute': 15,
        },
        dates: {'2026-01-10': hijri(1, 10), '2026-01-11': hijri(2, 10)},
      );
      await rebuild(now: DateTime(2026, 1, 10, 10));
      expect(alarms.where((a) => a['id'] == 9100), isEmpty);
      expect(
        calls
            .where((c) => c.method == 'cancelAlarms')
            .any((c) => (c.arguments['ids'] as List).contains(9100)),
        isTrue,
      );
    },
  );

  test(
    'Dhul Hijjah repeat preference is minutes and stops at day10 Maghrib',
    () async {
      await configure(
        settings: {'notif_takbeerat': true, 'takbeerat_interval_hours': 2},
        dates: {
          '2026-01-10': hijri(10, 12),
          '2026-01-11': hijri(11, 12),
          '2026-01-12': hijri(12, 12),
        },
      );
      final times = (await PrayerService.getPrayerTimesForDateStatic(today))!;
      await rebuild();
      expect(alarm(9000)['intervalMinutes'], 2);
      expect(
        alarm(9000)['season_end_epoch'],
        times.maghrib.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'Ramadan and prohibited fasting days do not create voluntary fasting reminders',
    () async {
      for (final month in [9, 10, 12]) {
        final day = month == 9 ? 20 : (month == 10 ? 1 : 13);
        // Jan 10 is Saturday: Jan 11 (Sunday) would otherwise remind for Monday.
        await configure(
          settings: {
            'notif_fasting_monday': true,
            'notif_fasting_white_days': true,
          },
          dates: {
            '2026-01-10': hijri(
              day == 1 ? 30 : day - 1,
              month == 10 ? 9 : month,
            ),
            '2026-01-11': hijri(day, month),
            '2026-01-12': hijri(day, month),
            '2026-01-13': hijri(day, month),
          },
        );
        await rebuild();
        expect(
          alarms.where(
            (a) => (a['id'] as int) >= 2400 && (a['id'] as int) < 2510,
          ),
          isEmpty,
        );
      }
    },
  );

  test(
    'unknown official future dates do not fabricate Ramadan or Eid',
    () async {
      await configure(
        settings: {
          'iftar_alarm': true,
          'suhoor_alarm': true,
          'eid_fitr_alarm': true,
          'eid_fitr_takbeer': true,
          'notif_takbeerat': true,
        },
        dates: {},
      );
      await rebuild();
      expect(alarms, isEmpty);
    },
  );

  test(
    'invalid salawat weekdays terminate safely and cancel the legacy chain',
    () async {
      await configure();
      await NotificationService.scheduleSalawatReminders(60, [0, 8, -1]);
      expect(alarms, isEmpty);
      expect(calls.any((c) => c.method == 'cancelAlarms'), isTrue);
    },
  );

  test(
    'foreground Firebase messages are rendered locally without real Firebase configuration',
    () async {
      await configure();
      await FCMService.handleForegroundMessage(
        const RemoteMessage(
          notification: RemoteNotification(title: 'عنوان', body: 'النص'),
          data: {'payload': 'ramadan'},
        ),
      );
      expect(alarms, hasLength(1));
      expect(alarms.single['id'], inInclusiveRange(700000, 799999));
      expect(alarms.single['title'], 'عنوان');
      expect(alarms.single['soundName'], 'default');
      expect(alarms.single['payload'], 'ramadan');
    },
  );

  test('empty Firebase messages do not create blank notifications', () async {
    await configure();
    await FCMService.handleForegroundMessage(
      const RemoteMessage(data: {'payload': 'home'}),
    );
    expect(alarms, isEmpty);
  });
}
