import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';
import 'package:ibad_al_rahmann/services/prayer_notification_platform_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('app.ibad_al_rahmann/native_notifications');
  const widgets = MethodChannel('home_widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final widgetFlags = <bool>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
    calls.clear();
    widgetFlags.clear();
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call);
      // Native and widget readers must already agree before the command.
      final enabled = call.method == 'updatePrayerNotification';
      expect(
        CacheHelper.prefs.getBool('persistent_notification_enabled'),
        enabled,
      );
      expect(widgetFlags.last, enabled);
      return null;
    });
    messenger.setMockMethodCallHandler(widgets, (call) async {
      expect(call.method, 'saveWidgetData');
      expect(call.arguments['id'], 'persistent_notification_enabled');
      widgetFlags.add(call.arguments['data'] as bool);
      return true;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(widgets, null);
  });

  test(
    'disable only stops the bar without cancelling or rebuilding alarms',
    () async {
      await PrayerNotificationServiceHelper.setEnabled(false);
      expect(calls.map((call) => call.method), ['stopPrayerNotification']);
      expect(widgetFlags, [false]);
      // shared_preferences already applies the native flutter. prefix itself.
      expect(
        CacheHelper.prefs.containsKey(
          'flutter.persistent_notification_enabled',
        ),
        isFalse,
      );
    },
  );

  test(
    'enable requests one native sync without prayer cache or alarm work',
    () async {
      await PrayerNotificationServiceHelper.setEnabled(true);
      expect(calls.map((call) => call.method), ['updatePrayerNotification']);
      expect(calls.single.arguments, isNull);
      expect(widgetFlags, [true]);
    },
  );

  test('repeated off/on/off leaves both preference stores disabled', () async {
    for (final enabled in [false, true, false]) {
      await PrayerNotificationServiceHelper.setEnabled(enabled);
    }
    expect(calls.map((call) => call.method), [
      'stopPrayerNotification',
      'updatePrayerNotification',
      'stopPrayerNotification',
    ]);
    expect(widgetFlags, [false, true, false]);
    expect(
      CacheHelper.prefs.getBool('persistent_notification_enabled'),
      isFalse,
    );
  });

  test(
    'platform failure reaches settings rather than being swallowed',
    () async {
      messenger.setMockMethodCallHandler(native, (_) async {
        throw PlatformException(code: 'NOTIFICATION_ERROR');
      });
      await expectLater(
        PrayerNotificationServiceHelper.setEnabled(false),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  testWidgets('unresponsive platform command has a bounded wait', (
    tester,
  ) async {
    final response = Completer<void>();
    // No guarded test assertions inside platform callbacks during pump().
    messenger.setMockMethodCallHandler(widgets, (_) async => true);
    messenger.setMockMethodCallHandler(native, (_) => response.future);
    final result = PrayerNotificationServiceHelper.setEnabled(true);
    final assertion = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await assertion;
    response.complete();
    await tester.pump();
  });
}
