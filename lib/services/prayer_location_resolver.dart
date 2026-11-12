import 'dart:async';

enum PrayerLocationFixSource {
  currentPosition,
  lastKnownPosition,
  savedCoordinates,
}

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
    PrayerLocationFix? cachedFix,
  }) async {
    String? currentFailure;
    String? lastKnownFailure;

    try {
      final currentFix = await getCurrentFix();
      if (cachedFix != null && _isOlderThan(currentFix, cachedFix)) {
        return PrayerLocationResolution(
          fix: cachedFix,
          source: PrayerLocationFixSource.savedCoordinates,
          currentFailure: 'older_current_position_ignored',
        );
      }
      return PrayerLocationResolution(
        fix: currentFix,
        source: PrayerLocationFixSource.currentPosition,
      );
    } catch (error) {
      currentFailure = _safeFailureReason(error);
    }

    PrayerLocationFix? lastKnownFix;
    try {
      lastKnownFix = await getLastKnownFix();
    } catch (error) {
      lastKnownFailure = _safeFailureReason(error);
    }

    if (lastKnownFix != null && cachedFix != null) {
      if (_isOlderThan(lastKnownFix, cachedFix)) {
        return PrayerLocationResolution(
          fix: cachedFix,
          source: PrayerLocationFixSource.savedCoordinates,
          currentFailure: currentFailure,
          lastKnownFailure: 'older_than_saved_coordinates',
        );
      }
    }

    if (lastKnownFix != null) {
      return PrayerLocationResolution(
        fix: lastKnownFix,
        source: PrayerLocationFixSource.lastKnownPosition,
        currentFailure: currentFailure,
        lastKnownFailure: lastKnownFailure,
      );
    }

    if (cachedFix != null) {
      return PrayerLocationResolution(
        fix: cachedFix,
        source: PrayerLocationFixSource.savedCoordinates,
        currentFailure: currentFailure,
        lastKnownFailure: lastKnownFailure,
      );
    }

    return PrayerLocationResolution(
      fix: null,
      source: null,
      currentFailure: currentFailure,
      lastKnownFailure: lastKnownFailure,
    );
  }

  static bool _isOlderThan(
    PrayerLocationFix candidate,
    PrayerLocationFix reference,
  ) {
    final candidateTimestamp = candidate.timestamp;
    final referenceTimestamp = reference.timestamp;
    if (referenceTimestamp == null) return false;
    if (candidateTimestamp == null) return true;
    return candidateTimestamp.isBefore(referenceTimestamp);
  }

  static String _safeFailureReason(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is PrayerLocationAcquisitionException) return error.reason;
    return error.runtimeType.toString();
  }
}
