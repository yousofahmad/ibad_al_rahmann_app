import 'dart:async';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'egyptian_hijri_sync.dart';
import 'app_logger.dart';

/// Calendar-only task, deliberately separate from prayer alarms and their IDs.
const int egyptianHijriSyncAlarmId = 874321;

@pragma('vm:entry-point')
Future<void> egyptianHijriSyncBackgroundCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await AppLogger.init();
  final startedAt = DateTime.now();
  final stopwatch = Stopwatch()..start();
  AppLogger.logEvent('HijriSyncScheduler', 'background_callback_started', {
    'scheduledInterval': '6h_periodic_best_effort',
    'startedAt': startedAt.toIso8601String(),
  });
  try {
    await EgyptianHijriSync.instance.refresh(trigger: 'android_alarm_manager');
    AppLogger.logEvent('HijriSyncScheduler', 'background_callback_finished', {
      'outcome': 'callback_completed',
      'durationMs': stopwatch.elapsedMilliseconds,
    });
  } catch (error) {
    AppLogger.logEvent('HijriSyncScheduler', 'background_callback_failed', {
      'reason': 'exception_${error.runtimeType}',
      'durationMs': stopwatch.elapsedMilliseconds,
    });
    debugPrint('Egyptian calendar background sync error: ${error.runtimeType}');
  }
}

/// Android delivery is best-effort: this is not an exact prayer alarm.
/// The sync engine gates successful requests by the Egyptian civil day and
/// retries failures with backoff. Extra opportunities help after offline/Doze.
class EgyptianHijriSyncRunner with WidgetsBindingObserver {
  EgyptianHijriSyncRunner._();
  static final instance = EgyptianHijriSyncRunner._();
  bool _started = false;
  Timer? _foregroundTimer;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshSafely('app_start'));
    _foregroundTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refreshSafely('foreground_15m_check'));
      }
    });
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final scheduleStartedAt = DateTime.now();
        AppLogger.logEvent('HijriSyncScheduler', 'schedule_started', {
          'trigger': 'runner_start',
          'intervalHours': 6,
          'expectedFirstRunAt': scheduleStartedAt
              .add(const Duration(hours: 6))
              .toIso8601String(),
        });
        final initialized = await AndroidAlarmManager.initialize();
        if (!initialized) {
          AppLogger.logEvent('HijriSyncScheduler', 'schedule_failed', {
            'reason': 'alarm_manager_initialization_returned_false',
          });
          debugPrint(
            'Egyptian calendar background scheduler did not initialize',
          );
          return;
        }
        final scheduled = await AndroidAlarmManager.periodic(
          const Duration(hours: 6),
          egyptianHijriSyncAlarmId,
          egyptianHijriSyncBackgroundCallback,
          exact: false,
          wakeup: false,
          rescheduleOnReboot: true,
        );
        AppLogger.logEvent(
          'HijriSyncScheduler',
          scheduled ? 'schedule_accepted' : 'schedule_failed',
          {
            'intervalHours': 6,
            'expectedFirstRunAt': scheduleStartedAt
                .add(const Duration(hours: 6))
                .toIso8601String(),
            'exact': false,
            'wakeup': false,
            if (!scheduled) 'reason': 'alarm_manager_returned_false',
          },
        );
        if (!scheduled) {
          debugPrint('Egyptian calendar background schedule was not accepted');
        }
      } catch (error) {
        AppLogger.logEvent('HijriSyncScheduler', 'schedule_failed', {
          'reason': 'exception_${error.runtimeType}',
        });
        debugPrint(
          'Egyptian calendar background scheduling error: ${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _refreshSafely(String trigger) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    AppLogger.logEvent('HijriSyncScheduler', 'refresh_triggered', {
      'trigger': trigger,
      'expectedAt': startedAt.toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
    });
    try {
      await EgyptianHijriSync.instance.refresh(trigger: trigger);
      AppLogger.logEvent('HijriSyncScheduler', 'refresh_callback_finished', {
        'trigger': trigger,
        'outcome': 'callback_completed',
        'durationMs': stopwatch.elapsedMilliseconds,
      });
    } catch (error) {
      AppLogger.logEvent('HijriSyncScheduler', 'refresh_callback_failed', {
        'trigger': trigger,
        'reason': 'exception_${error.runtimeType}',
        'durationMs': stopwatch.elapsedMilliseconds,
      });
      debugPrint('Egyptian calendar sync error: ${error.runtimeType}');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshSafely('app_resumed'));
    }
  }

  void dispose() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    // Never cancel the calendar background task or any prayer alarm here.
  }
}
