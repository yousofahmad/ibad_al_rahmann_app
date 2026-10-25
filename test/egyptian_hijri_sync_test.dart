import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ibad_al_rahmann/services/egyptian_hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_sources.dart';
import 'package:ibad_al_rahmann/services/egyptian_hijri_sync.dart';

const _darUrl = 'https://www.dar-alifta.org/ar/services/details/12/date';
final _now = DateTime.utc(2026, 10, 19, 12);
String _key(DateTime d) => EgyptianHijriCalendar.civilKey(d);

Map<String, Map<String, int>> _fullYear(int year, {int currentDay = 8}) {
  final result = <String, Map<String, int>>{};
  for (
    var d = DateTime(year);
    d.year == year;
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final day = d.year == 2026 && d.month == 10 && d.day == 19
        ? currentDay
        : ((d.difference(DateTime(year)).inDays) % 30) + 1;
    result[_key(d)] = {'day': day, 'month': 7, 'year': 1448};
  }
  return result;
}

Map<String, Map<String, int>> _fullMonth(
  int year,
  int month, {
  int currentDay = 8,
}) {
  final result = <String, Map<String, int>>{};
  for (
    var d = DateTime(year, month);
    d.month == month;
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    result[_key(d)] = {
      'day': d.day == 19 ? currentDay : ((d.day - 1) % 30) + 1,
      'month': 7,
      'year': 1448,
    };
  }
  return result;
}

class FakeSources extends EgyptianHijriSources {
  FakeSources({
    this.darDay = 7,
    this.annualDay = 8,
    this.monthDay = 8,
    this.failDar = false,
    this.failAnnual = false,
    this.failMonth = false,
    this.stale = false,
  });
  int darDay,
      annualDay,
      monthDay,
      darCalls = 0,
      annualCalls = 0,
      monthCalls = 0;
  bool failDar, failAnnual, failMonth, stale;

  @override
  Future<DarIftaSnapshot> fetchDarIfta(DateTime date) async {
    darCalls++;
    if (failDar) throw StateError('network down');
    return DarIftaSnapshot(
      civilDate: stale ? date.subtract(const Duration(days: 1)) : date,
      hijri: OfficialHijriValue(darDay, 7, 1448),
      sourceUrl: _darUrl,
    );
  }

  @override
  Future<Map<String, Map<String, int>>> fetchSurveyYear(int year) async {
    annualCalls++;
    if (failAnnual) throw StateError('annual down');
    return _fullYear(year, currentDay: annualDay);
  }

  @override
  Future<Map<String, Map<String, int>>> fetchSurveyMonth(
    int month,
    int year,
  ) async {
    monthCalls++;
    if (failMonth) throw StateError('month down');
    return _fullMonth(year, month, currentDay: monthDay);
  }
}

class WrongYearSources extends FakeSources {
  @override
  Future<Map<String, Map<String, int>>> fetchSurveyYear(int year) async {
    annualCalls++;
    return _fullYear(year - 1);
  }
}

class BlockingSources extends FakeSources {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Map<String, Map<String, int>>> fetchSurveyYear(int year) async {
    annualCalls++;
    started.complete();
    await release.future;
    return _fullYear(year, currentDay: annualDay);
  }
}

class ChangingMonthSources extends FakeSources {
  ChangingMonthSources({
    required this.firstMonthDay,
    required this.secondMonthDay,
  }) : super(
         annualDay: firstMonthDay,
         monthDay: secondMonthDay,
         darDay: secondMonthDay,
       );
  final int firstMonthDay;
  final int secondMonthDay;

  @override
  Future<Map<String, Map<String, int>>> fetchSurveyYear(int year) async {
    annualCalls++;
    return _fullYear(year, currentDay: firstMonthDay);
  }

  @override
  Future<Map<String, Map<String, int>>> fetchSurveyMonth(
    int month,
    int year,
  ) async {
    monthCalls++;
    return _fullMonth(year, month, currentDay: secondMonthDay);
  }
}

Map<String, dynamic> _state({
  Map<String, dynamic>? survey,
  String? annualYear,
  String? annualSuccess,
  Map<String, dynamic>? extra,
}) => {
  'schemaVersion': 2,
  'survey': survey ?? <String, dynamic>{},
  if (annualYear != null) 'annualYear': int.parse(annualYear),
  if (annualSuccess != null) 'annualSuccess': annualSuccess,
  ...?extra,
};

Future<void> _seed(Map<String, dynamic> state) async {
  SharedPreferences.setMockInitialValues({
    EgyptianHijriSync.stateKey: jsonEncode(state),
  });
  EgyptianHijriCalendar.instance.resetForTesting();
}

Future<EgyptianHijriSync> _refresh(
  FakeSources source, {
  DateTime Function()? clock,
}) async {
  final engine = EgyptianHijriSync(sources: source, clock: clock ?? () => _now);
  await engine.refresh();
  return engine;
}

Future<EgyptianHijriSync> _refreshAt(
  FakeSources source,
  DateTime at, {
  bool force = false,
}) async {
  final engine = EgyptianHijriSync(sources: source, clock: () => at);
  await engine.refresh(force: force);
  return engine;
}

Future<Map<String, dynamic>> _savedState() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString(EgyptianHijriSync.stateKey)!)
      as Map<String, dynamic>;
}

Future<void> _makePending(FakeSources source) async {
  await _seed(_state());
  await _refreshAt(source, _now);
  await _refreshAt(source, _now.add(EgyptianHijriSync.minConfirmationInterval));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    EgyptianHijriCalendar.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'first ESA=8 and Dar=7 observation is not immediately actionable',
    () async {
      final source = FakeSources();
      await _seed(_state());
      await _refresh(source);
      final calendar = EgyptianHijriCalendar.instance;
      expect(calendar.lookup(_now)?.hDay, 8);
      expect(calendar.pendingConfirmation, isNull);
      expect(calendar.shouldPromptConfirmation, isFalse);
      expect((await _savedState())['disagreement']['checks'], 1);
    },
  );

  test(
    'confirm displayed 8 with adjustment 0 stores 8 and manual lookup wins',
    () async {
      final source = FakeSources();
      await _makePending(source);
      final engine = EgyptianHijriSync(
        sources: source,
        clock: () => _now.add(EgyptianHijriSync.minConfirmationInterval),
      );
      final calendar = EgyptianHijriCalendar.instance;
      await engine.confirmDate(
        civilDate: _now,
        displayedDate: calendar.lookup(_now)!,
        adjustment: 0,
      );
      expect(calendar.lookup(_now)?.hDay, 8);
      expect(calendar.dateSourceLabel(_now), 'بتأكيد المستخدم');
      expect(calendar.userConfirmation, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(egyptianHijriConfirmationKey), isNotNull);
      expect(prefs.getString(egyptianHijriDeferredKey), isNull);
    },
  );

  test(
    'adjustments -1/+1 choose 7/9, but manual continuation stops at 29',
    () async {
      final source = FakeSources();
      await _makePending(source);
      final engine = EgyptianHijriSync(
        sources: source,
        clock: () => _now.add(EgyptianHijriSync.minConfirmationInterval),
      );
      final c = EgyptianHijriCalendar.instance;
      final displayed = c.pendingConfirmation!.displayedDate;
      expect(c.choiceForAdjustment(_now, displayed, -1)!.hDay, 7);
      expect(c.choiceForAdjustment(_now, displayed, 1)!.hDay, 9);
      await engine.confirmDate(
        civilDate: _now,
        displayedDate: displayed,
        adjustment: 0,
      );
      expect(c.userConfirmation!.lookup(DateTime.utc(2026, 11, 9))!.hDay, 29);
      expect(c.userConfirmation!.lookup(DateTime.utc(2026, 11, 10)), isNull);
    },
  );

  test(
    'day 29 confirmation does not repeat today; expiry waits for persistent disagreement',
    () async {
      final source = FakeSources(annualDay: 29, darDay: 28, monthDay: 29);
      await _seed(_state());
      await _refreshAt(source, _now);
      final engine = await _refreshAt(
        source,
        _now.add(EgyptianHijriSync.minConfirmationInterval),
      );
      final c = EgyptianHijriCalendar.instance;
      expect(c.pendingConfirmation, isNotNull);
      await engine.confirmDate(
        civilDate: _now,
        displayedDate: c.pendingConfirmation!.displayedDate,
        adjustment: 0,
      );
      expect(c.pendingConfirmation, isNull);
      await _refresh(FakeSources(annualDay: 29, darDay: 29, monthDay: 29));
      expect(c.pendingConfirmation, isNull);
      final tomorrow = DateTime.utc(2026, 10, 20);
      final tomorrowSource = FakeSources(
        annualDay: 30,
        darDay: 30,
        monthDay: 30,
      );
      await _refreshAt(tomorrowSource, tomorrow.add(const Duration(hours: 12)));
      expect(c.lookup(tomorrow), isNotNull);
      expect(c.pendingConfirmation, isNull);
      await _refreshAt(tomorrowSource, tomorrow.add(const Duration(hours: 13)));
      expect(c.pendingConfirmation?.reason, 'manual_recheck');
    },
  );

  test(
    'choice at month boundary requires a published adjacent row, never guesses 29/30',
    () async {
      await _seed(
        _state(
          survey: {
            _key(_now): {'day': 30, 'month': 7, 'year': 1448},
          },
        ),
      );
      await _refresh(FakeSources(annualDay: 30, darDay: 30));
      final c = EgyptianHijriCalendar.instance;
      final displayed = c.lookup(_now)!;
      expect(c.choiceForAdjustment(_now, displayed, 1), isNull);
      expect(c.choiceForAdjustment(_now, displayed, -1)!.hDay, 29);
    },
  );

  test(
    'stale Dar is rejected; prior ESA remains, and metadata Dar is accepted only for current header pair',
    () async {
      await _seed(
        _state(
          survey: {
            _key(_now): {'day': 8, 'month': 7, 'year': 1448},
          },
        ),
      );
      final source = FakeSources(stale: true);
      await _refresh(source);
      expect(EgyptianHijriCalendar.instance.lookup(_now)?.hDay, 8);
      expect(EgyptianHijriCalendar.instance.pendingConfirmation, isNull);
      expect(EgyptianHijriCalendar.instance.lastError, contains('Stale Dar'));
    },
  );

  test(
    'forced refresh reloads a successful annual ESA table and keeps it primary',
    () async {
      await _seed(
        _state(
          survey: _fullYear(2026, currentDay: 8),
          annualYear: '2026',
          annualSuccess: _now.toIso8601String(),
        ),
      );
      final source = FakeSources(annualDay: 9, darDay: 7);
      await _refreshAt(
        source,
        _now.add(const Duration(hours: 2)),
        force: true,
      );
      expect(source.annualCalls, 1);
      expect(EgyptianHijriCalendar.instance.lookup(_now)?.hDay, 9);
      expect(
        EgyptianHijriCalendar.instance.dateSourceLabel(_now),
        EgyptianHijriCalendar.sourceName,
      );
      expect(EgyptianHijriCalendar.instance.pendingConfirmation, isNull);
      expect((await _savedState())['survey'].length, 365);
    },
  );

  test(
    'annual successful once per year, new Gregorian year downloads, and wrong-year data preserves old survey',
    () async {
      final source = FakeSources();
      await _seed(_state());
      await _refresh(source);
      await _refresh(source);
      expect(source.annualCalls, 1);
      await _seed(
        _state(
          survey: _fullYear(2026),
          annualYear: '2026',
          annualSuccess: _now.toIso8601String(),
        ),
      );
      final next = FakeSources();
      await _refresh(next, clock: () => DateTime.utc(2027, 1, 1, 12));
      expect(next.annualCalls, 1);
      expect(
        EgyptianHijriCalendar.instance.lookup(DateTime.utc(2026, 10, 19)),
        isNotNull,
      );
      await _seed(
        _state(
          survey: {
            _key(_now): {'day': 8, 'month': 7, 'year': 1448},
          },
          annualYear: '2025',
          annualSuccess: _now.toIso8601String(),
        ),
      );
      await _refresh(WrongYearSources());
      expect(EgyptianHijriCalendar.instance.surveyDates[_key(_now)]?.hDay, 8);
    },
  );

  test(
    'network failure retries after one hour and cached data remains available',
    () async {
      await _seed(_state(extra: {'darAttempt': _now.toIso8601String()}));
      final blocked = FakeSources(failDar: true);
      await _refresh(blocked);
      expect(blocked.darCalls, 0);
      await _seed(
        _state(
          extra: {
            'darAttempt': DateTime.utc(2026, 10, 19, 10).toIso8601String(),
          },
        ),
      );
      final retry = FakeSources(failDar: true);
      await _refresh(retry);
      expect(retry.darCalls, 1);
    },
  );

  test(
    'confirmation survives restart before network and annual state cannot overwrite independent manual key',
    () async {
      final source = FakeSources();
      await _makePending(source);
      final first = EgyptianHijriSync(
        sources: source,
        clock: () => _now.add(EgyptianHijriSync.minConfirmationInterval),
      );
      final c = EgyptianHijriCalendar.instance;
      await first.confirmDate(
        civilDate: _now,
        displayedDate: c.lookup(_now)!,
        adjustment: 0,
      );
      c.resetForTesting();
      await c.initialize();
      expect(c.userConfirmation, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      final state =
          jsonDecode(prefs.getString(EgyptianHijriSync.stateKey)!)
              as Map<String, dynamic>;
      state['annualYear'] = 2025;
      await prefs.setString(EgyptianHijriSync.stateKey, jsonEncode(state));
      await _refresh(FakeSources());
      expect(c.lookup(_now)?.hDay, 8);
    },
  );

  test(
    'manual confirmation expired never extrapolates and defer persists the civil date',
    () async {
      final source = FakeSources();
      await _makePending(source);
      final engine = EgyptianHijriSync(
        sources: source,
        clock: () => _now.add(const Duration(hours: 1)),
      );
      final c = EgyptianHijriCalendar.instance;
      await engine.deferConfirmation();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(egyptianHijriDeferredKey), _key(_now));
      expect(c.shouldPromptConfirmation, isFalse);
      expect(c.userConfirmation, isNull);
    },
  );
  test(
    'same disagreement needs two fresh observations one hour apart',
    () async {
      final source = FakeSources();
      await _seed(_state());
      await _refreshAt(source, _now);
      expect((await _savedState())['disagreement']['checks'], 1);
      await _refreshAt(
        source,
        _now.add(const Duration(minutes: 59)),
        force: true,
      );
      expect((await _savedState())['disagreement']['checks'], 1);
      await _refreshAt(source, _now.add(const Duration(hours: 1)), force: true);
      final state = await _savedState();
      expect(state['disagreement']['checks'], 2);
      expect(
        EgyptianHijriCalendar.instance.pendingConfirmation?.reason,
        'sources_disagree',
      );
    },
  );

  test(
    'cached reload and repeated force under one hour do not count',
    () async {
      final source = FakeSources();
      await _seed(_state());
      await _refreshAt(source, _now);
      final calls = source.darCalls;
      await _refreshAt(
        source,
        _now.add(const Duration(minutes: 30)),
        force: true,
      );
      await _refreshAt(
        source,
        _now.add(const Duration(minutes: 45)),
        force: true,
      );
      expect(source.darCalls, calls + 2);
      expect((await _savedState())['disagreement']['checks'], 1);
      expect(EgyptianHijriCalendar.instance.pendingConfirmation, isNull);
      EgyptianHijriCalendar.instance.resetForTesting();
      await EgyptianHijriCalendar.instance.initialize();
      await _refreshAt(source, _now.add(const Duration(minutes: 50)));
      expect((await _savedState())['disagreement']['checks'], 1);
    },
  );

  test('failed Dar or ESA second observation does not count', () async {
    final source = FakeSources();
    await _seed(_state());
    await _refreshAt(source, _now);
    source.failDar = true;
    source.failAnnual = true;
    source.failMonth = true;
    await _refreshAt(source, _now.add(const Duration(hours: 1)), force: true);
    expect((await _savedState())['disagreement']['checks'], 1);
    expect(EgyptianHijriCalendar.instance.pendingConfirmation, isNull);
  });

  test('changing civil day or date pair resets disagreement period', () async {
    final source = FakeSources();
    await _seed(_state());
    await _refreshAt(source, _now);
    await _refreshAt(source, _now.add(const Duration(days: 1)));
    expect((await _savedState())['disagreement']['checks'], 1);
    final changed = FakeSources(darDay: 6, annualDay: 8, monthDay: 8);
    await _refreshAt(
      changed,
      _now.add(const Duration(days: 1, hours: 1)),
      force: true,
    );
    final record = (await _savedState())['disagreement'];
    expect(record['checks'], 1);
    expect(record['dar']['day'], 6);
  });

  test(
    'Dar catches up from 7 to 8: no dialog and no stored correction',
    () async {
      final source = FakeSources();
      await _seed(_state());
      await _refreshAt(source, _now);
      expect((await _savedState())['disagreement']['checks'], 1);
      source.darDay = 8;
      await _refreshAt(source, _now.add(const Duration(hours: 1)));
      final calendar = EgyptianHijriCalendar.instance;
      expect(calendar.lookup(_now)?.hDay, 8);
      expect(calendar.pendingConfirmation, isNull);
      expect(calendar.userConfirmation, isNull);
      expect((await _savedState())['disagreement'], isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(egyptianHijriConfirmationKey), isNull);
    },
  );

  for (final failedSource in ['dar', 'esa']) {
    test(
      'failure of only $failedSource cannot confirm a disagreement',
      () async {
        final source = FakeSources();
        await _seed(_state());
        await _refreshAt(source, _now);
        source.failDar = failedSource == 'dar';
        source.failMonth = failedSource == 'esa';
        await _refreshAt(source, _now.add(const Duration(hours: 1)));
        expect((await _savedState())['disagreement']['checks'], 1);
        expect(EgyptianHijriCalendar.instance.pendingConfirmation, isNull);
      },
    );
  }

  test(
    'day 29 and expiry do not ask when both official sources agree',
    () async {
      await _seed(_state());
      final engine = await _refresh(
        FakeSources(annualDay: 29, darDay: 29, monthDay: 29),
      );
      final calendar = EgyptianHijriCalendar.instance;
      await engine.confirmDate(
        civilDate: _now,
        displayedDate: calendar.lookup(_now)!,
        adjustment: 0,
      );
      await _refreshAt(
        FakeSources(annualDay: 29, darDay: 29, monthDay: 29),
        _now.add(const Duration(hours: 1)),
      );
      expect(calendar.pendingConfirmation, isNull);
      final tomorrow = _now.add(const Duration(days: 1));
      await _refreshAt(FakeSources(darDay: 20), tomorrow);
      expect(calendar.userConfirmation!.lookup(tomorrow), isNull);
      expect(calendar.pendingConfirmation, isNull);
      expect(
        calendar.dateSourceLabel(tomorrow),
        EgyptianHijriCalendar.sourceName,
      );
    },
  );

  test(
    'restart does not publish old confirmed disagreement before a fresh match',
    () async {
      final source = FakeSources();
      await _makePending(source);
      final calendar = EgyptianHijriCalendar.instance;
      calendar.resetForTesting();
      await calendar.initialize();
      final notifications = <PendingHijriConfirmation?>[];
      void listener() => notifications.add(calendar.pendingConfirmation);
      calendar.addListener(listener);
      source.darDay = 8;
      try {
        await _refreshAt(source, _now.add(const Duration(hours: 2)));
      } finally {
        calendar.removeListener(listener);
      }
      expect(notifications.whereType<PendingHijriConfirmation>(), isEmpty);
      expect((await _savedState())['disagreement'], isNull);
    },
  );

  test(
    'late ESA month match prevents an intermediate pending notification',
    () async {
      await _seed(_state());
      final source = ChangingMonthSources(firstMonthDay: 8, secondMonthDay: 7);
      await _refreshAt(source, _now, force: true);
      expect((await _savedState())['disagreement']['checks'], 1);
      final calendar = EgyptianHijriCalendar.instance;
      final notifications = <PendingHijriConfirmation?>[];
      void listener() => notifications.add(calendar.pendingConfirmation);
      calendar.addListener(listener);
      try {
        await _refreshAt(source, _now.add(const Duration(hours: 1)));
      } finally {
        calendar.removeListener(listener);
      }
      expect(source.monthCalls, 1);
      expect(notifications.whereType<PendingHijriConfirmation>(), isEmpty);
      expect(EgyptianHijriCalendar.instance.pendingConfirmation, isNull);
      expect((await _savedState())['disagreement'], isNull);
    },
  );
}
