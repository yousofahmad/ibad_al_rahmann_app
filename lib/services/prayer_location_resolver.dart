import 'dart:async';

enum PrayerLocationFixSource { currentPosition }

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
  });

  final PrayerLocationFix? fix;
  final PrayerLocationFixSource? source;
  final String? currentFailure;
}

class PrayerLocationAcquisitionException implements Exception {
  const PrayerLocationAcquisitionException(this.reason);

  final String reason;
}

class PrayerLocationResolver {
  const PrayerLocationResolver._();

  static Future<PrayerLocationResolution> resolve({
    required Future<PrayerLocationFix> Function() getCurrentFix,
    DateTime? newerThan,
  }) async {
    try {
      final currentFix = await getCurrentFix();
      if (newerThan != null && currentFix.timestamp == null) {
        return const PrayerLocationResolution(
          fix: null,
          source: null,
          currentFailure: 'current_fix_timestamp_unavailable',
        );
      }
      if (newerThan != null && !currentFix.timestamp!.isAfter(newerThan)) {
        return const PrayerLocationResolution(
          fix: null,
          source: null,
          currentFailure: 'current_fix_not_newer_than_saved',
        );
      }
      return PrayerLocationResolution(
        fix: currentFix,
        source: PrayerLocationFixSource.currentPosition,
      );
    } catch (error) {
      return PrayerLocationResolution(
        fix: null,
        source: null,
        currentFailure: _safeFailureReason(error),
      );
    }
  }

  static String _safeFailureReason(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is PrayerLocationAcquisitionException) return error.reason;
    return error.runtimeType.toString();
  }
}
