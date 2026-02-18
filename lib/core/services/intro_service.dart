import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';

class IntroService {
  static const String _doubleTapIntroKey = 'double_tap_intro_shown';

  /// Check if the double tap intro has been shown before
  static bool hasShownDoubleTapIntro() {
    return getIt<CacheService>().getBool(_doubleTapIntroKey) ?? false;
  }

  /// Mark the double tap intro as shown
  static Future<void> markDoubleTapIntroAsShown() async {
    await getIt<CacheService>().setBool(_doubleTapIntroKey, true);
  }

  /// Reset the double tap intro (for testing or user preference)
  static Future<void> resetDoubleTapIntro() async {
    await getIt<CacheService>().setBool(_doubleTapIntroKey, false);
  }
}
