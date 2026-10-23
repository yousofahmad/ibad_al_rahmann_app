import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/notification_schedule_runner.dart';

void main() {
  test(
    'a queued request uses the newest callback and its input data',
    () async {
      final runner = NotificationScheduleRunner();
      final gate = Completer<void>();
      final versions = <int>[];
      final first = runner.run((_) async {
        versions.add(1);
        await gate.future;
      }, isUserAction: false);
      final second = runner.run((_) async {
        versions.add(2);
      }, isUserAction: false);
      final third = runner.run((_) async {
        versions.add(3);
      }, isUserAction: true);
      gate.complete();
      await Future.wait([first, second, third]);
      expect(versions, [1, 3]);
    },
  );

  test(
    'a settings change during rebuild triggers another serialized pass',
    () async {
      final runner = NotificationScheduleRunner();
      final gate = Completer<void>();
      var passes = 0;
      var active = 0;
      Future<void> rebuild(bool userAction) async {
        active++;
        expect(active, 1);
        passes++;
        if (passes == 1) await gate.future;
        active--;
      }

      final first = runner.run(rebuild, isUserAction: false);
      final second = runner.run(rebuild, isUserAction: true);
      expect(passes, 1);
      gate.complete();
      await Future.wait([first, second]);
      expect(passes, 2);
    },
  );

  test('rapid changes coalesce but do not lose user-action priority', () async {
    final runner = NotificationScheduleRunner();
    final gate = Completer<void>();
    final actions = <bool>[];
    Future<void> rebuild(bool action) async {
      actions.add(action);
      if (actions.length == 1) await gate.future;
    }

    final first = runner.run(rebuild, isUserAction: false);
    final next = runner.run(rebuild, isUserAction: true);
    final last = runner.run(rebuild, isUserAction: false);
    gate.complete();
    await Future.wait([first, next, last]);
    expect(actions, [false, true]);
  });

  test('a fresh request can rebuild after an earlier failure', () async {
    final runner = NotificationScheduleRunner();
    await expectLater(
      runner.run(
        (_) async => throw StateError('test failure'),
        isUserAction: true,
      ),
      throwsStateError,
    );
    var rebuilt = false;
    await runner.run((_) async {
      rebuilt = true;
    }, isUserAction: false);
    expect(rebuilt, isTrue);
  });

  test(
    'a later independent request does not inherit user-action state',
    () async {
      final runner = NotificationScheduleRunner();
      final actions = <bool>[];
      Future<void> rebuild(bool action) async {
        actions.add(action);
      }

      await runner.run(rebuild, isUserAction: true);
      await runner.run(rebuild, isUserAction: false);
      expect(actions, [true, false]);
    },
  );

  test(
    'a synchronous rebuild exception does not leave the runner stuck',
    () async {
      final runner = NotificationScheduleRunner();
      await expectLater(
        runner.run((_) => throw StateError('sync failure'), isUserAction: true),
        throwsStateError,
      );
      var rebuilt = false;
      await runner.run((_) async {
        rebuilt = true;
      }, isUserAction: false);
      expect(rebuilt, isTrue);
    },
  );
}
