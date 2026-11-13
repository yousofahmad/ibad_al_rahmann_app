import 'dart:async';

enum PrayerLocationFixSource { currentPosition, lastKnownPosition }

class PrayerLocationFix {
  const PrayerLocationFix({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double? accuracy;
}

class PrayerLocationResolution {
  const PrayerLocationResolution({
    required this.fix,
    required this.source,
    this.currentFailure,
    this.lastKnownFailure,
  });

  final PrayerLocationFix? fix;
  final PrayerLocationFixSource? source;
  final String? currentFailure;
  final String? lastKnownFailure;
}

class PrayerLocationAcquisitionException implements Exception {
  const PrayerLocationAcquisitionException(this.reason);

  final String reason;
}

class PrayerLocationResolver {
  const PrayerLocationResolver._();

  static Future<PrayerLocationResolution> resolve({
    required Future<PrayerLocationFix> Function() getCurrentFix,
    required Future<PrayerLocationFix?> Function() getLastKnownFix,
    DateTime? newerThan,
  }) async {
    String? currentFailure;
    try {
      final currentFix = await getCurrentFix();
      if (newerThan != null) {
        final timestamp = currentFix.timestamp;
        if (timestamp == null) {
          throw const PrayerLocationAcquisitionException(
            'current_fix_timestamp_unavailable',
          );
        }
        if (!timestamp.isAfter(newerThan)) {
          throw const PrayerLocationAcquisitionException(
            'current_fix_not_newer_than_saved',
          );
        }
      }
      return PrayerLocationResolution(
        fix: currentFix,
        source: PrayerLocationFixSource.currentPosition,
      );
    } catch (error) {
      currentFailure = _safeFailureReason(error);
    }

    String? lastKnownFailure;
    try {
      final lastKnownFix = await getLastKnownFix();
      if (lastKnownFix != null) {
        return PrayerLocationResolution(
          fix: lastKnownFix,
          source: PrayerLocationFixSource.lastKnownPosition,
          currentFailure: currentFailure,
        );
      }
    } catch (error) {
      lastKnownFailure = _safeFailureReason(error);
    }

    return PrayerLocationResolution(
      fix: null,
      source: null,
      currentFailure: currentFailure,
      lastKnownFailure: lastKnownFailure,
    );
  }

  static String _safeFailureReason(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is PrayerLocationAcquisitionException) return error.reason;
    return error.runtimeType.toString();
  }
}
