import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'egyptian_hijri_calendar.dart';
import 'egyptian_hijri_sources.dart';

/// Compares observations; a disagreement is NOT proof that ESA is wrong.
/// Only an explicit user confirmation can override the displayed ESA date.
class EgyptianHijriSync {
  static const stateKey = egyptianHijriStateKey;
  // An observation gap, not a claim about either site's update schedule.
  static const minConfirmationInterval = Duration(hours: 1);
  static final instance = EgyptianHijriSync();
  final EgyptianHijriSources sources;
  final Future<SharedPreferences> Function() _prefsFactory;
  final DateTime Function() _clock;
  bool _busy = false;
  static bool _zonesReady = false;
  EgyptianHijriSync({
    EgyptianHijriSources? sources,
    Future<SharedPreferences> Function()? prefsFactory,
    DateTime Function()? clock,
  }) : sources = sources ?? EgyptianHijriSources(),
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now;

  static DateTime cairoToday([DateTime? instant]) {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
    final d = tz.TZDateTime.from(
      instant ?? DateTime.now(),
      tz.getLocation('Africa/Cairo'),
    );
    return DateTime(d.year, d.month, d.day);
  }

  static Map<String, dynamic> _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(stateKey);
      if (raw != null) {
        final state = jsonDecode(raw);
        if (state is Map<String, dynamic> && state['schemaVersion'] == 2) {
          EgyptianHijriCalendar.parseDates(state['survey']);
          return state;
        }
      }
    } catch (_) {
      /* Retain the bundle when persisted data is malformed. */
    }
    return {'schemaVersion': 2, 'survey': <String, dynamic>{}};
  }

  static bool _due(dynamic stamp, DateTime now, Duration backoff) {
    final previous = DateTime.tryParse(stamp?.toString() ?? '');
    return previous == null ||
        now.toUtc().difference(previous.toUtc()) >= backoff;
  }

  static void _validateSpan(
    Map<String, EgyptianHijriDate> data,
    DateTime start,
    DateTime end,
  ) {
    final expected = <String>{};
    for (
      var d = start;
      d.isBefore(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      expected.add(EgyptianHijriCalendar.civilKey(d));
    }
    if (data.length != expected.length ||
        !data.keys.toSet().containsAll(expected)) {
      throw const FormatException('Incomplete or wrong-year ESA calendar');
    }
  }

  static EgyptianHijriDate? _cachedDar(Map<String, dynamic> state, String day) {
    try {
      if (state['darSuccessDay'] != day) return null;
      final uri = Uri.parse(state['lastDarSourceUrl'] as String);
      if (!['http', 'https'].contains(uri.scheme) ||
          !(uri.host == 'dar-alifta.org' ||
              uri.host.endsWith('.dar-alifta.org')) ||
          DateTime.tryParse(state['lastDarVerifiedAt'] as String) == null) {
        return null;
      }
      return EgyptianHijriCalendar.parseDates({
        day: state['lastDarValue'],
      })[day];
    } catch (_) {
      return null;
    }
  }

  static bool _sameDisagreement(
    dynamic record,
    String day,
    EgyptianHijriDate? survey,
    EgyptianHijriDate? dar,
  ) {
    if (record is! Map ||
        survey == null ||
        dar == null ||
        survey == dar ||
        record['civilDate'] != day) {
      return false;
    }
    try {
      return EgyptianHijriCalendar.parseDates({day: record['survey']})[day] ==
              survey &&
          EgyptianHijriCalendar.parseDates({day: record['dar']})[day] == dar;
    } catch (_) {
      return false;
    }
  }

  static bool _confirmedDisagreement(
    dynamic record,
    String day,
    EgyptianHijriDate? survey,
    EgyptianHijriDate? dar,
    DateTime now,
  ) {
    if (!_sameDisagreement(record, day, survey, dar) || record['checks'] != 2) {
      return false;
    }
    final first = DateTime.tryParse(record['firstSeenAt']?.toString() ?? '');
    final last = DateTime.tryParse(record['lastSeenAt']?.toString() ?? '');
    return first != null &&
        last != null &&
        !last.isAfter(now) &&
        last.difference(first) >= minConfirmationInterval &&
        EgyptianHijriCalendar.civilKey(cairoToday(first)) == day &&
        EgyptianHijriCalendar.civilKey(cairoToday(last)) == day;
  }

  static void _observeDisagreement(
    Map<String, dynamic> state,
    String day,
    EgyptianHijriDate? survey,
    EgyptianHijriDate? dar,
    DateTime now, {
    required bool freshPair,
  }) {
    final previous = state['disagreement'];
    final same = _sameDisagreement(previous, day, survey, dar);
    if (!same) state.remove('disagreement');
    if (!freshPair || survey == null || dar == null || survey == dar) return;
    final first = same
        ? DateTime.tryParse(previous['firstSeenAt']?.toString() ?? '')
        : null;
    final last = same
        ? DateTime.tryParse(previous['lastSeenAt']?.toString() ?? '')
        : null;
    if (first == null ||
        last == null ||
        first.isAfter(now) ||
        last.isAfter(now) ||
        EgyptianHijriCalendar.civilKey(cairoToday(first)) != day) {
      state['disagreement'] = {
        'civilDate': day,
        'survey': survey.toJson(),
        'dar': dar.toJson(),
        'firstSeenAt': now.toIso8601String(),
        'lastSeenAt': now.toIso8601String(),
        'checks': 1,
      };
    } else if (now.difference(first) >= minConfirmationInterval &&
        now.difference(last) >= minConfirmationInterval) {
      state['disagreement'] = {
        ...Map<String, dynamic>.from(previous as Map),
        'lastSeenAt': now.toIso8601String(),
        'checks': 2,
      };
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    final calendar = EgyptianHijriCalendar.instance;
    try {
      final now = _clock().toUtc(), today = cairoToday(_clock());
      final key = EgyptianHijriCalendar.civilKey(today),
          stamp = now.toIso8601String();
      final prefs = await _prefsFactory();
      await prefs.reload();
      if (!calendar.isInitialized) {
        try {
          await calendar.initialize();
        } catch (_) {
          /* A live source may still work. */
        }
      }
      final state = _load(prefs);
      final survey = <String, EgyptianHijriDate>{
        ...calendar.surveyDates,
        ...EgyptianHijriCalendar.parseDates(state['survey']),
      };
      calendar.restoreUserConfirmation(prefs);
      var dar = _cachedDar(state, key);
      var conflict = dar != null && survey[key] != null
          ? survey[key] != dar
          : state['conflictActive'] == true;
      var attempted = false;
      var freshDar = false, freshSurvey = false;
      var canPrompt = false;
      final errors = <String>[];

      PendingHijriConfirmation? pending() {
        if (!canPrompt) return null;
        final user = calendar.userConfirmation;
        final manual = user?.lookup(today);
        final baseline = manual ?? survey[key] ?? dar;
        if (baseline == null) return null;
        final recheck = user?.recheckDue(today) ?? false;
        if (manual != null && !recheck) return null;
        if (!_confirmedDisagreement(
          state['disagreement'],
          key,
          survey[key],
          dar,
          now,
        )) {
          return null;
        }
        return PendingHijriConfirmation(
          civilDate: today,
          displayedDate: baseline,
          surveyDate: survey[key],
          darDate: dar,
          reason: recheck ? 'manual_recheck' : 'sources_disagree',
        );
      }

      String status() {
        final manual = calendar.userConfirmation?.lookup(today);
        if (pending() != null) {
          return 'استمر اختلاف المصدرين بعد إعادة التحقق؛ نحتاج تأكيدك للتاريخ.';
        }
        if (manual != null) {
          return calendar.userConfirmation!.recheckDue(today)
              ? 'بلغ تأكيدك يوم ٢٩؛ نراجع المصدرين مجددًا دون طلب تعديل بسبب قراءة واحدة.'
              : 'نعمل بتأكيدك للتاريخ حتى يوم ٢٩؛ اختلاف المصدرين لا يغيّره تلقائيًا.';
        }
        if (dar != null && survey[key] == dar) {
          return 'تاريخ المساحة مطابق لآخر قراءة اليوم من دار الإفتاء.';
        }
        if (dar != null && survey[key] != null && survey[key] != dar) {
          return 'قد يكون أحد المصدرين متأخرًا؛ نحتفظ بجدول المساحة ونعيد التحقق في مزامنة لاحقة.';
        }
        return 'جدول المساحة محفوظ؛ لم تكتمل مراجعة المصدر الآخر لهذا اليوم.';
      }

      void publish() => calendar.replaceSnapshot(
        survey,
        pending: pending(),
        status: status(),
        error: errors.isNotEmpty
            ? errors.join('; ')
            : (attempted
                  ? null
                  : (state['lastError'] is String
                        ? state['lastError'] as String
                        : null)),
      );
      Future<void> save() async {
        state['survey'] = {
          for (final e in survey.entries) e.key: e.value.toJson(),
        };
        state['conflictActive'] = conflict;
        if (attempted) {
          state['lastError'] = errors.isEmpty ? null : errors.join('; ');
        }
        if (!await prefs.setString(stateKey, jsonEncode(state))) {
          throw StateError('Could not save calendar observation state');
        }
      }

      publish(); // Restore the user's decision / due review before any network wait.
      if (force ||
          (dar == null || conflict) &&
              _due(state['darAttempt'], now, const Duration(hours: 1))) {
        attempted = true;
        state['darAttempt'] = stamp;
        try {
          final snap = await sources.fetchDarIfta(today);
          if (EgyptianHijriCalendar.civilKey(snap.civilDate) != key) {
            throw const FormatException('Stale Dar Ifta snapshot');
          }
          final candidate = EgyptianHijriCalendar.parseDates({
            key: snap.hijri.toJson(),
          })[key]!;
          state['darSuccessDay'] = key;
          state['lastDarValue'] = candidate.toJson();
          state['lastDarSourceUrl'] = snap.sourceUrl;
          state['lastDarVerifiedAt'] = stamp;
          dar = _cachedDar(state, key);
          if (dar == null) {
            throw const FormatException(
              'Invalid Dar Ifta observation provenance',
            );
          }
          freshDar = true;
          conflict = survey[key] != null && survey[key] != dar;
        } catch (error) {
          errors.add('Dar Ifta: $error');
        }
        // Do not open a new dialog before ESA has also had a chance to catch up.
        await save();
      }

      final annualDue =
          state['annualYear'] != today.year || state['annualSuccess'] == null;
      var downloadedToday = false;
      if (annualDue &&
          (force ||
              _due(state['annualAttempt'], now, const Duration(days: 1)))) {
        attempted = true;
        state['annualAttempt'] = stamp;
        try {
          final data = EgyptianHijriCalendar.parseDates(
            await sources.fetchSurveyYear(today.year),
          );
          _validateSpan(data, DateTime(today.year), DateTime(today.year + 1));
          survey.addAll(data);
          state['annualYear'] = today.year;
          state['annualSuccess'] = stamp;
          state['surveySuccessDay'] = key;
          downloadedToday = true;
          freshSurvey = true;
          if (dar != null) conflict = survey[key] != dar;
        } catch (error) {
          errors.add('ESA year: $error');
        }
      }
      final effective =
          calendar.userConfirmation?.lookup(today) ?? survey[key] ?? dar;
      final boundary =
          effective == null ||
          effective.hDay >= 29 ||
          effective.hDay <= 3 ||
          (survey[key]?.hDay ?? 0) >= 29 ||
          (survey[key]?.hDay ?? 0) <= 3 ||
          (calendar.userConfirmation?.recheckDue(today) ?? false);
      if (!downloadedToday &&
          (force || conflict || boundary) &&
          (force ||
              (conflict || state['surveySuccessDay'] != key) &&
                  _due(
                    state['surveyAttempt'],
                    now,
                    const Duration(hours: 1),
                  ))) {
        attempted = true;
        state['surveyAttempt'] = stamp;
        try {
          final data = EgyptianHijriCalendar.parseDates(
            await sources.fetchSurveyMonth(today.month, today.year),
          );
          _validateSpan(
            data,
            DateTime(today.year, today.month),
            DateTime(today.year, today.month + 1),
          );
          survey.addAll(data);
          state['surveySuccessDay'] = key;
          freshSurvey = true;
          if (dar != null) conflict = survey[key] != dar;
        } catch (error) {
          errors.add('ESA month: $error');
        }
      }
      _observeDisagreement(
        state,
        key,
        survey[key],
        dar,
        now,
        freshPair: freshDar && freshSurvey,
      );
      canPrompt =
          freshDar && freshSurvey ||
          !attempted &&
              _confirmedDisagreement(
                state['disagreement'],
                key,
                survey[key],
                dar,
                now,
              ) &&
              !_due(
                (state['disagreement'] as Map)['lastSeenAt'],
                now,
                minConfirmationInterval,
              );
      state['lastAttempt'] = attempted ? stamp : state['lastAttempt'];
      publish();
      await save();
    } catch (error) {
      calendar.replaceSnapshot(
        calendar.surveyDates,
        pending: calendar.pendingConfirmation,
        status: 'تعذر إكمال المراجعة؛ يبقى تأكيدك أو آخر جدول مساحة متاح.',
        error: error.toString(),
      );
    } finally {
      _busy = false;
    }
  }

  /// Independent storage avoids a background observation overwriting a choice
  /// while the annual download is still running. Never requires the network.
  Future<void> confirmDate({
    required DateTime civilDate,
    required EgyptianHijriDate displayedDate,
    required int adjustment,
  }) async {
    final calendar = EgyptianHijriCalendar.instance;
    if (EgyptianHijriCalendar.civilKey(civilDate) !=
        EgyptianHijriCalendar.civilKey(cairoToday(_clock()))) {
      throw StateError('تغير اليوم؛ أعد فتح تأكيد التاريخ.');
    }
    final current =
        calendar.pendingConfirmation?.displayedDate ??
        calendar.lookup(civilDate);
    if (current != displayedDate) {
      throw StateError('تغيرت بيانات التاريخ؛ أعد فتح التأكيد.');
    }
    final chosen = calendar.choiceForAdjustment(
      civilDate,
      displayedDate,
      adjustment,
    );
    if (chosen == null) {
      throw StateError(
        'لا تتوفر بيانات موثقة لحد الشهر المطلوب؛ لا نحسبه افتراضيًا.',
      );
    }
    final confirmation = EgyptianHijriUserConfirmation(
      anchorDate: DateTime(civilDate.year, civilDate.month, civilDate.day),
      hijri: chosen,
      confirmedAt: _clock().toUtc().toIso8601String(),
    );
    final prefs = await _prefsFactory();
    if (!await prefs.setString(
      egyptianHijriConfirmationKey,
      jsonEncode(confirmation.toJson()),
    )) {
      throw StateError('تعذر حفظ تأكيد التاريخ.');
    }
    await prefs.remove(egyptianHijriDeferredKey);
    calendar.applyUserConfirmation(confirmation);
  }

  Future<void> deferConfirmation() async {
    final calendar = EgyptianHijriCalendar.instance,
        pending = EgyptianHijriCalendar.instance.pendingConfirmation;
    if (pending == null) return;
    final day = EgyptianHijriCalendar.civilKey(pending.civilDate),
        prefs = await _prefsFactory();
    if (!await prefs.setString(egyptianHijriDeferredKey, day)) {
      throw StateError('تعذر حفظ التأجيل.');
    }
    calendar.deferConfirmation(day);
  }

  void close() => sources.close();
}
