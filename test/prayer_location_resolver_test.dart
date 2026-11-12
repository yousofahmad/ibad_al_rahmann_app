import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/prayer_location_resolver.dart';

void main() {
  final newerTime = DateTime(2026, 11, 12, 12);
  const current = PrayerLocationFix(
    latitude: 30.1,
    longitude: 31.2,
    accuracy: 120,
  );

  group('PrayerLocationResolver', () {
    test('returns the current position when acquisition succeeds', () async {
      final result = await PrayerLocationResolver.resolve(
        getCurrentFix: () async => current,
        getLastKnownFix: () async => null,
      );

      expect(result.fix, same(current));
      expect(result.source, PrayerLocationFixSource.currentPosition);
      expect(result.currentFailure, isNull);
    });

    test(
      'uses the last known position after the current request times out',
      () async {
        const lastKnown = PrayerLocationFix(latitude: 29.9, longitude: 31.1);
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () => Future.error(TimeoutException('timed out')),
          getLastKnownFix: () async => lastKnown,
        );

        expect(result.fix, same(lastKnown));
        expect(result.source, PrayerLocationFixSource.lastKnownPosition);
        expect(result.currentFailure, 'timeout');
        expect(result.lastKnownFailure, isNull);
      },
    );

    test('uses saved coordinates when both location providers fail', () async {
      final saved = PrayerLocationFix(
        latitude: 30.2,
        longitude: 31.3,
        timestamp: newerTime,
      );
      final result = await PrayerLocationResolver.resolve(
        getCurrentFix: () => Future.error(
          const PrayerLocationAcquisitionException(
            'location_permission_unavailable',
          ),
        ),
        getLastKnownFix: () => Future.error(TimeoutException('timed out')),
        cachedFix: saved,
      );

      expect(result.fix, same(saved));
      expect(result.source, PrayerLocationFixSource.savedCoordinates);
      expect(result.currentFailure, 'location_permission_unavailable');
      expect(result.lastKnownFailure, 'timeout');
    });

    test(
      'does not replace newer saved coordinates with an older last-known fix',
      () async {
        final saved = PrayerLocationFix(
          latitude: 30.2,
          longitude: 31.3,
          timestamp: newerTime,
        );
        final olderLastKnown = PrayerLocationFix(
          latitude: 29.9,
          longitude: 31.1,
          timestamp: newerTime.subtract(const Duration(hours: 1)),
        );
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () => Future.error(TimeoutException('timed out')),
          getLastKnownFix: () async => olderLastKnown,
          cachedFix: saved,
        );

        expect(result.fix, same(saved));
        expect(result.source, PrayerLocationFixSource.savedCoordinates);
        expect(result.lastKnownFailure, 'older_than_saved_coordinates');
      },
    );

    test(
      'does not replace newer saved coordinates with an older current fix',
      () async {
        final saved = PrayerLocationFix(
          latitude: 30.2,
          longitude: 31.3,
          timestamp: newerTime,
        );
        final olderCurrent = PrayerLocationFix(
          latitude: 29.9,
          longitude: 31.1,
          timestamp: newerTime.subtract(const Duration(minutes: 5)),
        );
        final result = await PrayerLocationResolver.resolve(
          getCurrentFix: () async => olderCurrent,
          getLastKnownFix: () async => null,
          cachedFix: saved,
        );

        expect(result.fix, same(saved));
        expect(result.source, PrayerLocationFixSource.savedCoordinates);
        expect(result.currentFailure, 'older_current_position_ignored');
      },
    );
  });
}
