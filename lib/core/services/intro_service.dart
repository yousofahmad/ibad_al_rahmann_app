import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/double_tap_dialog.dart';

class IntroService {
  static const String _doubleTapIntroKey = 'double_tap_intro_shown';
  static const String _wirdDoubleTapIntroKey = 'wird_double_tap_intro_shown';

  /// Check if the double tap intro has been shown before
  static bool hasShownDoubleTapIntro() {
    return CacheHelper.prefs.getBool(_doubleTapIntroKey) ?? false;
  }

  /// Mark the double tap intro as shown
  static Future<void> markDoubleTapIntroAsShown() async {
    await CacheHelper.prefs.setBool(_doubleTapIntroKey, true);
  }

  /// Check if the wird double tap intro has been shown
  static bool hasShownWirdDoubleTapIntro() {
    return CacheHelper.prefs.getBool(_wirdDoubleTapIntroKey) ?? false;
  }

  /// Mark the wird double tap intro as shown
  static Future<void> markWirdDoubleTapIntroAsShown() async {
    await CacheHelper.prefs.setBool(_wirdDoubleTapIntroKey, true);
  }

  /// Reset the double tap intro (for testing or user preference)
  static Future<void> resetDoubleTapIntro() async {
    await CacheHelper.prefs.setBool(_doubleTapIntroKey, false);
    await CacheHelper.prefs.setBool(_wirdDoubleTapIntroKey, false);
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
