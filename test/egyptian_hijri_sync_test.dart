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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    EgyptianHijriCalendar.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'ESA=8 and Dar=7 creates pending confirmation while lookup stays 8',
    () async {
      final source = FakeSources();
      await _seed(_state());
      await _refresh(source);
      final calendar = EgyptianHijriCalendar.instance;
      expect(calendar.lookup(_now)?.hDay, 8);
      expect(calendar.pendingConfirmation?.displayedDate.hDay, 8);
      expect(calendar.pendingConfirmation?.reason, 'sources_disagree');
      expect(calendar.shouldPromptConfirmation, isTrue);
    },
  );

  test(
    'confirm displayed 8 with adjustment 0 stores 8 and manual lookup wins',
    () async {
      final source = FakeSources();
      await _seed(_state());
      final engine = await _refresh(source);
      final calendar = EgyptianHijriCalendar.instance;
      await engine.confirmDate(
        civilDate: _now,
        displayedDate: calendar.pendingConfirmation!.displayedDate,
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
      await _seed(_state());
      final engine = await _refresh(FakeSources());
      final c = EgyptianHijriCalendar.instance;
      expect(
        c
            .choiceForAdjustment(
              _now,
              c.pendingConfirmation!.displayedDate,
              -1,
            )!
            .hDay,
        7,
      );
      expect(
        c
            .choiceForAdjustment(_now, c.pendingConfirmation!.displayedDate, 1)!
            .hDay,
        9,
      );
      await engine.confirmDate(
        civilDate: _now,
        displayedDate: c.pendingConfirmation!.displayedDate,
        adjustment: 0,
      );
      expect(c.userConfirmation!.lookup(DateTime.utc(2026, 11, 9))!.hDay, 29);
      expect(c.userConfirmation!.lookup(DateTime.utc(2026, 11, 10)), isNull);
    },
  );

  test(
    'day 29 always has manual_recheck, confirming 29 does not repeat today, and day 30 prompts again',
    () async {
      final source = FakeSources(annualDay: 29, darDay: 28, monthDay: 29);
      await _seed(_state());
      final engine = await _refresh(source);
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
      await _refresh(
        FakeSources(annualDay: 30, darDay: 30, monthDay: 30),
        clock: () => DateTime.utc(2026, 10, 20, 12),
      );
      expect(c.lookup(tomorrow), isNotNull);
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
      await _seed(_state());
      final first = await _refresh(FakeSources());
      final c = EgyptianHijriCalendar.instance;
      await first.confirmDate(
        civilDate: _now,
        displayedDate: c.pendingConfirmation!.displayedDate,
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
      await _seed(_state());
      final engine = await _refresh(FakeSources());
      final c = EgyptianHijriCalendar.instance;
      await engine.deferConfirmation();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(egyptianHijriDeferredKey), _key(_now));
      expect(c.shouldPromptConfirmation, isFalse);
      expect(c.userConfirmation, isNull);
    },
  );
}
