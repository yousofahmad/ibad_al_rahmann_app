import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/prayer_location_resolver.dart';

void main() {
  const current = PrayerLocationFix(
    latitude: 30.1,
    longitude: 31.2,
    accuracy: 120,
  );

  group('PrayerLocationResolver', () {
    test('returns only a successfully acquired current position', () async {
      var currentRequests = 0;
      final result = await PrayerLocationResolver.resolve(
        getCurrentFix: () async {
          currentRequests++;
          return current;
        },
      );

      expect(currentRequests, 1);
      expect(result.fix, same(current));
      expect(result.source, PrayerLocationFixSource.currentPosition);
      expect(result.currentFailure, isNull);
    });

    test(
      'returns no fix when the current-position request times out',
      () async {
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () => Future.error(TimeoutException('timed out')),
        );

        expect(result.fix, isNull);
        expect(result.source, isNull);
        expect(result.currentFailure, 'timeout');
      },
    );

    test(
      'returns no fix when current location permission is unavailable',
      () async {
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () => Future.error(
            const PrayerLocationAcquisitionException(
              'location_permission_unavailable',
            ),
          ),
        );

        expect(result.fix, isNull);
        expect(result.source, isNull);
        expect(result.currentFailure, 'location_permission_unavailable');
      },
    );

    test(
      'rejects a current API result that is not newer than the saved fix',
      () async {
        final savedAt = DateTime(2026, 11, 12, 12);
        final result = await PrayerLocationResolver.resolve(
          newerThan: savedAt,
          getCurrentFix: () async => PrayerLocationFix(
            latitude: current.latitude,
            longitude: current.longitude,
            timestamp: savedAt,
            accuracy: current.accuracy,
          ),
        );

        expect(result.fix, isNull);
        expect(result.source, isNull);
        expect(result.currentFailure, 'current_fix_not_newer_than_saved');
      },
    );
  });
}
