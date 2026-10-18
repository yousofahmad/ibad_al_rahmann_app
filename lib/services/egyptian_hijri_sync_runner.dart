import 'dart:async';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'egyptian_hijri_sync.dart';

/// Calendar-only task, deliberately separate from prayer alarms and their IDs.
const int egyptianHijriSyncAlarmId = 874321;

@pragma('vm:entry-point')
Future<void> egyptianHijriSyncBackgroundCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await EgyptianHijriSync.instance.refresh();
  } catch (error) {
    debugPrint('Egyptian calendar background sync unavailable: $error');
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
    unawaited(_refreshSafely());
    _foregroundTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refreshSafely());
      }
    });
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final initialized = await AndroidAlarmManager.initialize();
        if (!initialized) {
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
        if (!scheduled) {
          debugPrint('Egyptian calendar background schedule was not accepted');
        }
      } catch (error) {
        debugPrint(
          'Egyptian calendar background scheduling unavailable: $error',
        );
      }
    }
  }

  Future<void> _refreshSafely() async {
    try {
      await EgyptianHijriSync.instance.refresh();
    } catch (error) {
      debugPrint('Egyptian calendar sync unavailable: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshSafely());
  }

  void dispose() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    // Never cancel the calendar background task or any prayer alarm here.
  }
}
