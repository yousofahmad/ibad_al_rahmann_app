import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
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

  /// Show the detailed Quran navigation hints dialog
  static void showQuranIntro(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تلميحات التصفح',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFFD0A871),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHintRow(Icons.touch_app, 'ضغطتين', 'تكبير / تصغير الصفحة'),
              const SizedBox(height: 12),
              _buildHintRow(
                Icons.touch_app_outlined,
                'ضغطة مطولة',
                'التفسير والمشاركة ومشغل الآيات',
              ),
              const SizedBox(height: 12),
              _buildHintRow(
                Icons.bookmark_outline,
                'ضغطة واحدة',
                ' قائمة المحفوظات و تغيير الثيم والمشاركة او الحفظ وضغطة اخري تختفي',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'حسنًا',
                style: TextStyle(
                  color: Color(0xFFD0A871),
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildHintRow(IconData icon, String title, String desc) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD0A871), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
