import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart';
import 'package:ibad_al_rahmann/features/quran/providers/share_provider.dart';

/// A list of all verses in the surah.
/// Each verse is shown in a distinct card with a golden 8-pointed star
/// carrying the verse number. Verses within the active [from, to] range
/// are highlighted with the app's primary color.
class VerseSelectionList extends StatelessWidget {
  const VerseSelectionList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShareProvider>();
    final primary = Theme.of(context).primaryColor;
    final verses = provider.allVerseNumbers;

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: verses.length,
      itemBuilder: (context, index) {
        final verseNum = verses[index];
        final selected = provider.isInRange(verseNum);
        final verseText = getVerse(provider.surahNumber, verseNum);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: _VerseCard(
            verseNumber: verseNum,
            verseText: verseText,
            isSelected: selected,
            primaryColor: primary,
            onTap: () => _onVerseTap(provider, verseNum),
          ),
        );
      },
    );
  }

  void _onVerseTap(ShareProvider provider, int verseNum) {
    // First tap sets fromVerse, second tap (on different verse) sets toVerse
    if (verseNum < provider.fromVerse) {
      provider.setFromVerse(verseNum);
    } else if (verseNum == provider.fromVerse && verseNum == provider.toVerse) {
      // already single selection — do nothing special
    } else if (verseNum > provider.toVerse) {
      provider.setToVerse(verseNum);
    } else {
      // Tapping inside range: collapse to just this verse
      provider.setFromVerse(verseNum);
      provider.setToVerse(verseNum);
    }
  }
}

class _VerseCard extends StatelessWidget {
  final int verseNumber;
  final String verseText;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _VerseCard({
    required this.verseNumber,
    required this.verseText,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isSelected
        ? primaryColor.withValues(alpha: isDark ? 0.35 : 0.15)
        : (isDark ? Colors.grey.shade900 : Colors.white);
    final borderColor = isSelected ? primaryColor : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: borderColor, width: 1.5.w),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8.r,
                    offset: Offset(0, 2.h),
                  ),
                ]
              : null,
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Golden 8-pointed star with verse number
            _EightPointedStar(number: verseNumber, isSelected: isSelected),
            SizedBox(width: 10.w),
            // Verse text
            Expanded(
              child: Text(
                verseText,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: 'uthmanic',
                  fontSize: 18.sp,
                  height: 1.8,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EightPointedStar extends StatelessWidget {
  final int number;
  final bool isSelected;

  const _EightPointedStar({required this.number, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    // Golden color regardless of selection state - Strictly 0xFFD0A871
    const starColor = Color(0xFFD0A871);
    const textColor = Colors.white;

    return SizedBox(
      width: 38.w,
      height: 38.w,
      child: CustomPaint(
        painter: _StarPainter(color: starColor),
        child: Center(
          child: Text(
            _toArabicNumerals(number),
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  static String _toArabicNumerals(int n) {
    const w = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const a = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = n.toString();
    for (int i = 0; i < w.length; i++) {
      s = s.replaceAll(w[i], a[i]);
    }
    return s;
  }
}

/// Draws an 8-pointed star (two overlapping squares, rotated 45°).
class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    void drawRotatedSquare(double angle) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: r * 1.2,
        height: r * 1.2,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(3.r));
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }

    drawRotatedSquare(0);
    drawRotatedSquare(3.14159265358979 / 4); // 45 degrees
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}
