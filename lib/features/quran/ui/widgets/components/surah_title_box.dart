import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/widgets/adaptive_layout.dart';

class SurahTitleBox extends StatelessWidget {
  final int surahIndex;
  final bool selected;

  const SurahTitleBox({super.key, required this.surahIndex, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      mobileLayout: (_) => SurahTitleBoxMobile(surahIndex: surahIndex, selected: selected),
      tabletLayout: (_) => SurahTitleBoxTablet(surahIndex: surahIndex, selected: selected),
    );
  }
}

class SurahTitleBoxMobile extends StatelessWidget {
  final int surahIndex;
  final bool selected;

  const SurahTitleBoxMobile({
    super.key,
    required this.surahIndex,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(context.primaryColor) == Brightness.dark;
    final Color selectedTextColor = isPrimaryDark ? Colors.white : Colors.black87;

    final bgColor = selected ? context.primaryColor : context.secondary;
    final textColor = selected 
        ? selectedTextColor 
        : (bgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 140.w,
      height: 45.h,
      child: CustomPaint(
        painter: FramePainter(
          selected: selected,
          backgroundColor: bgColor,
          borderColor: selected ? context.outline : context.secondary,
          borderWidth: 3, 
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'surah${(surahIndex + 1).toString().padLeft(3, '0')}',
                style: TextStyle(
                  fontFamily: 'SurahNames',
                  fontSize: 32,
                  color: textColor,
                  height: 0.7,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SurahTitleBoxTablet extends StatelessWidget {
  final int surahIndex;
  final bool selected;

  const SurahTitleBoxTablet({
    super.key,
    required this.surahIndex,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(context.primaryColor) == Brightness.dark;
    final Color selectedTextColor = isPrimaryDark ? Colors.white : Colors.black87;

    final bgColor = selected ? context.primaryColor : context.secondary;
    final textColor = selected 
        ? selectedTextColor 
        : (bgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      width: 240,
      height: 75,
      child: CustomPaint(
        painter: FramePainter(
          selected: selected,
          backgroundColor: bgColor,
          borderColor: selected ? context.outline : context.secondary,
          borderWidth: 6,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'surah${(surahIndex + 1).toString().padLeft(3, '0')}',
                style: TextStyle(
                  fontFamily: 'SurahNames',
                  fontSize: 54,
                  color: textColor,
                  height: 0.7,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FramePainter extends CustomPainter {
  final bool selected;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  FramePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();

    final double width = size.width;
    final double height = size.height;
    const double cornerSize = 15.0;
    const double pointSize = 15.0;

    // Start top-left corner
    path.moveTo(0, cornerSize);

    // Left side with point
    path.lineTo(-pointSize, height * 0.5); // outward point
    path.lineTo(0, height - cornerSize);

    // Bottom-left corner
    path.lineTo(0, height);

    // Bottom side with inward point
    path.lineTo(width * 0.4, height);
    path.lineTo(width * 0.5, height + pointSize);
    path.lineTo(width * 0.6, height);
    path.lineTo(width, height);

    // Bottom-right corner
    path.lineTo(width, height - cornerSize);

    // Right side with point
    path.lineTo(width + pointSize, height * 0.5);
    path.lineTo(width, cornerSize);

    // Top-right corner
    path.lineTo(width, 0);

    // Top side with inward point
    path.lineTo(width * 0.6, 0);
    path.lineTo(width * 0.5, -pointSize);
    path.lineTo(width * 0.4, 0);
    path.lineTo(0, 0);

    // Close the path
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant FramePainter oldDelegate) {
    return oldDelegate.selected != selected;
  }
}
