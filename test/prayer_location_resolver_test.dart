import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/prayer_location_resolver.dart';

void main() {
  final savedAt = DateTime(2026, 11, 13, 10);
  final current = PrayerLocationFix(
    latitude: 30.1,
    longitude: 31.2,
    timestamp: savedAt.add(const Duration(minutes: 1)),
    accuracy: 35,
  );
  final lastKnown = PrayerLocationFix(
    latitude: 30.0,
    longitude: 31.0,
    timestamp: savedAt.subtract(const Duration(hours: 3)),
    accuracy: 140,
  );

  group('PrayerLocationResolver', () {
    test('prefers a fresh current fix and never requests last-known', () async {
      var lastKnownRequests = 0;
      final result = await PrayerLocationResolver.resolve(
        newerThan: savedAt,
        getCurrentFix: () async => current,
        getLastKnownFix: () async {
          lastKnownRequests++;
          return lastKnown;
        },
      );

      expect(result.fix, same(current));
      expect(result.source, PrayerLocationFixSource.currentPosition);
      expect(result.currentFailure, isNull);
      expect(result.lastKnownFailure, isNull);
      expect(lastKnownRequests, 0);
    });

    test(
      'uses last-known after current GPS times out and keeps it marked old',
      () async {
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () => Future.error(TimeoutException('timed out')),
          getLastKnownFix: () async => lastKnown,
        );

        expect(result.fix, same(lastKnown));
        expect(result.source, PrayerLocationFixSource.lastKnownPosition);
        expect(result.currentFailure, 'timeout');
        expect(result.lastKnownFailure, isNull);
        expect(
          result.fix!.timestamp,
          savedAt.subtract(const Duration(hours: 3)),
        );
      },
    );

    test('uses last-known after current permission is unavailable', () async {
      final result = await PrayerLocationResolver.resolve(
        getCurrentFix: () => Future.error(
          const PrayerLocationAcquisitionException(
            'location_permission_unavailable',
          ),
        ),
        getLastKnownFix: () async => lastKnown,
      );

      expect(result.fix, same(lastKnown));
      expect(result.source, PrayerLocationFixSource.lastKnownPosition);
      expect(result.currentFailure, 'location_permission_unavailable');
    });

    test(
      'treats a non-newer current result as failed and falls back',
      () async {
        final result = await PrayerLocationResolver.resolve(
          newerThan: savedAt,
          getCurrentFix: () async => PrayerLocationFix(
            latitude: current.latitude,
            longitude: current.longitude,
            timestamp: savedAt,
            accuracy: current.accuracy,
          ),
          getLastKnownFix: () async => lastKnown,
        );

        expect(result.fix, same(lastKnown));
        expect(result.source, PrayerLocationFixSource.lastKnownPosition);
        expect(result.currentFailure, 'current_fix_not_newer_than_saved');
      },
    );

    test(
      'returns failure details when both current and last-known fail',
      () async {
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () =>
              Future.error(TimeoutException('current timeout')),
          getLastKnownFix: () =>
              Future.error(TimeoutException('cached timeout')),
        );

        expect(result.fix, isNull);
        expect(result.source, isNull);
        expect(result.currentFailure, 'timeout');
        expect(result.lastKnownFailure, 'timeout');
      },
    );

    test('returns no fix when the last-known provider is empty', () async {
      final result = await PrayerLocationResolver.resolve(
        getCurrentFix: () => Future.error(TimeoutException('current timeout')),
        getLastKnownFix: () async => null,
      );

      expect(result.fix, isNull);
      expect(result.source, isNull);
      expect(result.currentFailure, 'timeout');
      expect(result.lastKnownFailure, isNull);
    });
  });
}
