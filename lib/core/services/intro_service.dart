import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/services/cache_service.dart';

import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/double_tap_dialog.dart';

class IntroService {
  static const String _doubleTapIntroKey = 'double_tap_intro_shown';
  static const String _wirdDoubleTapIntroKey = 'wird_double_tap_intro_shown';

  /// Check if the double tap intro has been shown before
  static bool hasShownDoubleTapIntro() {
    return getIt<CacheService>().getBool(_doubleTapIntroKey) ?? false;
  }

  /// Mark the double tap intro as shown
  static Future<void> markDoubleTapIntroAsShown() async {
    await getIt<CacheService>().setBool(_doubleTapIntroKey, true);
  }

  /// Check if the wird double tap intro has been shown
  static bool hasShownWirdDoubleTapIntro() {
    return getIt<CacheService>().getBool(_wirdDoubleTapIntroKey) ?? false;
  }

  /// Mark the wird double tap intro as shown
  static Future<void> markWirdDoubleTapIntroAsShown() async {
    await getIt<CacheService>().setBool(_wirdDoubleTapIntroKey, true);
  }

  /// Reset the double tap intro (for testing or user preference)
  static Future<void> resetDoubleTapIntro() async {
    await getIt<CacheService>().setBool(_doubleTapIntroKey, false);
    await getIt<CacheService>().setBool(_wirdDoubleTapIntroKey, false);
  }

  /// Show the detailed Quran navigation hints dialog
  static void showQuranIntro(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return const DoubleTapDialog();
      },
    ).then((_) async {
      await markDoubleTapIntroAsShown();
    });
  }
}
